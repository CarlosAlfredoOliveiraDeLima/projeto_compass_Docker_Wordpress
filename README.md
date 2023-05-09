# Projeto Docker + AWS + Wordpress - Compass.UOL
**Objetivo** <br>
Esse projeto tem como objetivo realizar o estudo do provisionamento de instâncias EC2 através de user_data.sh, provisionamento do serviço Wordpress através de um container Docker, configurar um Application Load Balancer (ALB) para realizar o balanço de requisições em multiplas Regiões de Disponibilidade num Auto Scaling Group (ASG). E, também, configurar um Amazon Relational Database Service (AWS RDS) para gerenciar  os arquivos privados do Wordpress num volume EFS.


## Arquitetura AWS

**VPC**

Primeiramente iremos configurar nossa VPC, Subnets, Internet Gateway e NAT Gates

1. Instale e Configure a AWS CLI em sua máquina local.
2. Abra seu terminal e execute o seguinte comando para criar a VPC:
`aws ec2 create-vpc --cidr-block <CIDR block> --region <region>`

> Substitua o`<CIDR block>` com o block de endereços de IP que você deseja atrelar à sua VPC. Como por exemplo: `10.0.0.0/16`. substitua `<region>` com o código da região que você deseja criar sua VPC. Por exemplo, `ap-southeast-2`

3. O comando acima irá retornar um arquivo JSON contendo os detalhes da VPC recém criada, incluindo seu ID. Copie o ID da VPC, pois você precisará dele para os próximos passos.
4. Para criar uma Subnet dentro da VPC, execute o seguinte comando:
`aws ec2 create-subnet --vpc-id <VPC ID> --cidr-block <CIDR block> --region <region>`

> Substitua o `<VPC ID>` com o ID da VPC que você acabou de criar, e o `<CIDR block>` com o bloco de endereços IP que você deseja atrelar à subnet, por exemplo `10.0.1.0/24`

5. 

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
