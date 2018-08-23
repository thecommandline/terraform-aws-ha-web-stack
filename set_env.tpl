#!/usr/bin/env bash

sudo apt update
sudo apt upgrade --yes

echo env[DB_HOST] = ${DB_HOST} >> /etc/php/7.0/fpm/pool.d/www.conf
echo env[DB_USER] = ${DB_USER} >> /etc/php/7.0/fpm/pool.d/www.conf
echo env[DB_PASS] = ${DB_PASS} >> /etc/php/7.0/fpm/pool.d/www.conf
echo env[DB_NAME] = ${DB_NAME} >> /etc/php/7.0/fpm/pool.d/www.conf

sudo systemctl restart php7.0-fpm.service