
///////////////////////////////////////////
//           EC2 Settings                //
///////////////////////////////////////////
variable ec2_deploy_key {
  default = "justin-primary"
}

// Amazon Linux 2 
variable bastion_ami {
  default = "ami-04681a1dbd79675a5"
}

// Custom AMI. You must update this with your own AMI.  
variable app_ami {
  default = "ami-0e0a2ad8201220f1b"
}

// These IP addresses will be allowed to SSH into the bastion host. All other SSH access must originate from bastion host.  
variable ssh_allowed_ips {
  type    = "list"
  default = ["0.0.0.0/0"]
}

///////////////////////////////////////////
//        SSL and DNS Settings           //
///////////////////////////////////////////
variable domain_name {
  default = "thecommandline.org"
}

// This certificate must already exist and will not be automatically created. 
variable cert_cn {
  default = "*.thecommandline.org"
}

///////////////////////////////////////////
//           VPC Settings                //
///////////////////////////////////////////
variable vpc_cidr {
  default = "10.0.0.0/16"
}

variable public_subnets {
  type    = "list"
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable private_subnets {
  type    = "list"
  default = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

///////////////////////////////////////////
//          Database Settings            //
///////////////////////////////////////////
variable database_subnets {
  type    = "list"
  default = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
}

variable database_size {
  default = "db.t2.micro"
}

variable database_name {
  default = "db"
}

variable database_username {
  default = "user"
}

variable database_password {
  default = "password123"
}

variable database_multi_az {
  default = "true"
}

