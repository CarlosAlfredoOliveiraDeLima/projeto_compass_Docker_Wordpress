#!/bin/bash

yum update -yq
yum install -yq docker

systemctl start docker.service
systemctl enable docker.service

sh -c "curl -L https://github.com/docker/compose/releases/download/v2.17.3/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose"
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

export EFS_URL=$(aws ssm get-parameter --name /wordpress/efs-url --with-decryption --region=us-east-1 --query "Parameter.Value" --output=text)
export WORDPRESS_DB_HOST=$(aws ssm get-parameter --name /wordpress/db-host --with-decryption --region=us-east-1 --query "Parameter.Value" --output=text)
export WORDPRESS_DB_NAME=$(aws ssm get-parameter --name /wordpress/db-name --with-decryption --region=us-east-1 --query "Parameter.Value" --output=text)
export WORDPRESS_DB_USER=$(aws ssm get-parameter --name /wordpress/db-user --with-decryption --region=us-east-1 --query "Parameter.Value" --output=text)
export WORDPRESS_DB_PASSWORD=$(aws ssm get-parameter --name /wordpress/db-password --with-decryption --region=us-east-1 --query "Parameter.Value" --output=text)

mkdir -p /media/efs/
printf "\n${EFS_URL}:/\t/media/efs/\tnfs4\tnfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport\t0\t0" >> /etc/fstab
mount -a
mkdir -p /media/efs/wordpress

sudo mkdir /opt/wordpress
chown ec2-user. /opt/wordpress/
cd /opt/wordpress/

envsubst > docker-compose.yml <<EOF
version: '3.1'

services:

  wordpress:
    image: wordpress:6.2.0-apache
    restart: always
    ports:
      - 8080:80
    environment:
      WORDPRESS_DB_HOST: "\$WORDPRESS_DB_HOST"
      WORDPRESS_DB_USER: "\$WORDPRESS_DB_USER"
      WORDPRESS_DB_PASSWORD: "\$WORDPRESS_DB_PASSWORD"
      WORDPRESS_DB_NAME: "\$WORDPRESS_DB_NAME"
    volumes:
      - /media/efs/wordpress:/var/www/html
EOF

chmod 550 docker-compose.yml

docker-compose up -d