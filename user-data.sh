#!/bin/bash
sudo yum update -y

sudo yum install docker -y

# Giving permissions to docker
sudo usermod -aG docker ec2-user
newgrp docker

# Installing Docker Compose
wget https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) 
sudo mv docker-compose-$(uname -s)-$(uname -m) /usr/local/bin/docker-compose
sudo chmod -v +x /usr/local/bin/docker-compose

sudo systemctl enable docker.service
sudo systemctl start docker.service

sudo yum install mysql -y

sudo mkdir /mnt/efs