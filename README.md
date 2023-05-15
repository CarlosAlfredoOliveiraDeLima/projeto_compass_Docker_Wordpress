# **Projeto Docker + AWS + Wordpress - Compass.UOL**
**Objetivo** <br>
Esse projeto tem como objetivo realizar o estudo do provisionamento de instâncias EC2 através de user_data.sh, provisionamento do serviço Wordpress através de um container Docker, configurar um Application Load Balancer (ALB) para realizar o balanço de requisições em multiplas Regiões de Disponibilidade num Auto Scaling Group (ASG). E, também, configurar um Amazon Relational Database Service (AWS RDS) para gerenciar  os arquivos privados do Wordpress num volume EFS.

## **Requisitos**

1. AWS CLI Instalado e Configurado.
2. Conhecimento em Redes.
3. Conhecimento em Docker e Docker-compose.
4. Conhecimento do Sistema Operacional Linux.
5. Conhecimento de AWS CLI e GUI.

<br>

## **Arquitetura AWS**


![Diagrama da arquitetura](static/diagram.png)