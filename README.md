# Projeto Docker + AWS + Wordpress - Compass.UOL
**Objetivo** <br>
Esse projeto tem como objetivo realizar o estudo do provisionamento de instâncias EC2 através de user_data.sh, provisionamento do serviço Wordpress através de um container Docker, configurar um Application Load Balancer (ALB) para realizar o balanço de requisições em multiplas Regiões de Disponibilidade num Auto Scaling Group (ASG). E, também, configurar um Amazon Relational Database Service (AWS RDS) para gerenciar  os arquivos privados do Wordpress num volume EFS.


## Arquitetura AWS

**VPC**

**EFS**

**RDS**

**ALB**

**ASG**

**Bastion**

**SSL**

**user_data.sh**

**secrets/parameter store**

## Docker-compose

**Container Wordpress**
