#!/bin/bash

yum update -yq
yum install -yq docker

systemctl start docker.service
systemctl enable docker.service

COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
sh -c "curl -L https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose"
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

mkdir -p /media/efs/
printf "\nfs-0c135f50dbf9f85a3.efs.us-east-1.amazonaws.com:/\t/media/efs/\tnfs4\tnfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport\t0\t0" >> /etc/fstab
mount -a
mkdir -p /media/efs/wordpress

sudo mkdir /opt/wordpress
chown ec2-user. /opt/wordpress/
cd /opt/wordpress/

export WORDPRESS_DB_HOST=$(aws ssm get-parameter --name /wordpress/db-host --region=us-east-1 --query "Parameter.Value" --output=text)
export WORDPRESS_DB_NAME=$(aws ssm get-parameter --name /wordpress/db-name --region=us-east-1 --query "Parameter.Value" --output=text)
export WORDPRESS_DB_USER=$(aws ssm get-parameter --name /wordpress/db-user --region=us-east-1 --query "Parameter.Value" --output=text)
export WORDPRESS_DB_PASSWORD=$(aws ssm get-parameter --name /wordpress/db-password --region=us-east-1 --query "Parameter.Value" --output=text)

envsubst > docker-compose.yml <<EOF
version: '3.1'

services:

  wordpress:
    image: wordpress
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

docker-compose up -d