data "aws_availability_zones" "available" {}

data "aws_acm_certificate" "www-cert" {
  domain      = "${var.cert_cn}"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "1.40.0"

  name               = "my-vpc"
  cidr               = "${var.vpc_cidr}"
  azs                = ["${data.aws_availability_zones.available.names[0]}", "${data.aws_availability_zones.available.names[1]}", "${data.aws_availability_zones.available.names[2]}"]
  private_subnets    = "${var.private_subnets}"
  public_subnets     = "${var.public_subnets}"
  database_subnets   = "${var.database_subnets}"
  enable_nat_gateway = true
  single_nat_gateway = false
  one_nat_gateway_per_az = true
  enable_vpn_gateway = false
}

module "ssh_from_internet_sg" {
  source = "terraform-aws-modules/security-group/aws//modules/ssh"

  name                = "ssh_from_internet"
  vpc_id              = "${module.vpc.vpc_id}"
  ingress_cidr_blocks = "${var.ssh_allowed_ips}"
}

module "ssh_from_bastion_sg" {
  source = "terraform-aws-modules/security-group/aws//modules/ssh"

  name                = "ssh_from_public"
  vpc_id              = "${module.vpc.vpc_id}"
  ingress_cidr_blocks = "${var.public_subnets}"
}

module "db_sg" {
  source = "terraform-aws-modules/security-group/aws//modules/mysql"

  name                = "mysql-rds"
  vpc_id              = "${module.vpc.vpc_id}"
  ingress_cidr_blocks = "${var.private_subnets}"
}

module "app_server_sg" {
  source = "terraform-aws-modules/security-group/aws//modules/http-80"

  name                = "web-server"
  vpc_id              = "${module.vpc.vpc_id}"
  ingress_cidr_blocks = "${var.public_subnets}"
}

module "load_balancer_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name                = "load-balancer"
  vpc_id              = "${module.vpc.vpc_id}"
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules        = ["http-80-tcp"]
  egress_cidr_blocks  = "${var.private_subnets}"
}

data "template_file" "user_data" {
  template = "${file("${path.module}/set_env.tpl")}"

  vars {
    DB_HOST = "${aws_db_instance.db.address}"
    DB_PASS = "${var.database_password}"
    DB_USER = "${var.database_username}"
    DB_NAME = "${var.database_name}"
  }
}

module "app-asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "2.7.0"

  name              = "app-asg"
  lc_name           = "app-lc"
  image_id          = "${var.app_ami}"
  instance_type     = "t2.micro"
  security_groups   = ["${module.app_server_sg.this_security_group_id}", "${module.ssh_from_bastion_sg.this_security_group_id}"]
  key_name          = "${var.ec2_deploy_key}"
  target_group_arns = ["${module.alb.target_group_arns}"]
  user_data         = "${data.template_file.user_data.rendered}"

  # Auto scaling group
  asg_name                  = "app-asg"
  vpc_zone_identifier       = ["${module.vpc.private_subnets}"]
  health_check_type         = "EC2"
  min_size                  = 0
  max_size                  = 2
  desired_capacity          = 1
  wait_for_capacity_timeout = 0
}

module "bastion-asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "2.7.0"

  name            = "bastion-asg"
  lc_name         = "bastion-lc"
  image_id        = "${var.bastion_ami}"
  instance_type   = "t2.micro"
  security_groups = ["${module.ssh_from_internet_sg.this_security_group_id}"]
  key_name        = "${var.ec2_deploy_key}"

  # Auto scaling group
  asg_name                  = "bastion-asg"
  vpc_zone_identifier       = ["${module.vpc.public_subnets}"]
  health_check_type         = "EC2"
  min_size                  = 0
  max_size                  = 1
  desired_capacity          = 1
  wait_for_capacity_timeout = 0
}

module "alb" {
  source = "terraform-aws-modules/alb/aws"

  load_balancer_name       = "my-alb"
  security_groups          = ["${module.load_balancer_sg.this_security_group_id}"]
  subnets                  = "${module.vpc.public_subnets}"
  vpc_id                   = "${module.vpc.vpc_id}"
  logging_enabled          = "false"
  https_listeners          = "${list(map("certificate_arn", "${data.aws_acm_certificate.www-cert.arn}", "port", 443))}"
  https_listeners_count    = "1"
  http_tcp_listeners       = "${list(map("port", "80", "protocol", "HTTP"))}"
  http_tcp_listeners_count = "1"
  target_groups            = "${list(map("name", "app-servers", "backend_protocol", "HTTP", "backend_port", "80"))}"
  target_groups_count      = "1"
}

resource "aws_db_instance" "db" {
  allocated_storage         = 10
  storage_type              = "gp2"
  engine                    = "mariadb"
  engine_version            = "10.1.31"
  instance_class            = "${var.database_size}"
  name                      = "${var.database_name}"
  username                  = "${var.database_username}"
  password                  = "${var.database_password}"
  multi_az                  = "${var.database_multi_az}"
  skip_final_snapshot       = "true"
  final_snapshot_identifier = "db-final-snapshot"
  db_subnet_group_name      = "${module.vpc.database_subnet_group}"
  vpc_security_group_ids    = ["${module.db_sg.this_security_group_id}"]
}

provider "cloudflare" {
  email = "digitaladdictions@gmail.com"
  token = "6c7c12c72c01a9414b6cf8886c63b2c028d8b"
}

resource "cloudflare_record" "blog-thecommandline" {
  domain = "${var.domain_name}"
  name   = "blog"
  value  = "${module.alb.dns_name}"
  type   = "CNAME"
  ttl    = "1"
}
