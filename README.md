# **Projeto Docker + AWS + Wordpress - Compass.UOL**
**Objetivo** <br>
Esse projeto tem como objetivo realizar o estudo do provisionamento de instâncias EC2 através de user_data.sh, provisionamento do serviço Wordpress através de um container Docker, configurar um Application Load Balancer (ALB) para realizar o balanço de requisições em multiplas Regiões de Disponibilidade num Auto Scaling Group (ASG). E, também, configurar um Amazon Relational Database Service (AWS RDS) para gerenciar  os arquivos privados do Wordpress num volume EFS.

## **Requisitos**

1. AWS CLI Instalado e Configurado.
2. Conhecimento em Redes.
3. Conhecimento em Docker e Docker-compose.
4. Conhecimento do Sistema Operacional Linux.
5. Conhecimento de AWS CLI e GUI.

## **Arquitetura AWS**

![Diagrama da arquitetura](static/diagram.png)

### **VPC**

Uma Virtual Private Network (VPC) é um ambiente de redes dentro da AWS que nos permite criar uma seções isoladas da Cloud AWS. Nesse ambiente, podemos provisionar alguns recursos, como instâncias EC2, Banco de Dados RDS, Load balancers Elásticos na rede virtual que nós definirmos.

Nesse projeto iremos configurar toda nossa arquitetura dentro  da AWS iniciando pela VPC, já que os demais elementos irão ser disponibilizados dentro da VPC. Isso irá incluir as subnets que iremos utilizar, tabelas de rota, Internet Gateway e NAT Gate.

Dessa forma, iremos criar ambientes seguros e isolados, podendo nos dar escalabilidade e flexibilidade dentro da cloud.

Para configurar nossa VPC, siga os passos à seguir:

<br>

1. Instale e Configure a AWS CLI em sua máquina local.
2. Abra seu terminal e execute o seguinte comando para criar a VPC:
```
aws ec2 create-vpc --cidr-block <CIDR block> --region <region>
```
> Substitua o `<CIDR block>` com o block de endereços de IP que você deseja atrelar à sua VPC. Como por exemplo: `10.0.0.0/16`. substitua `<region>` com o código da região que você deseja criar sua VPC. Por exemplo, `ap-southeast-2`.

<br>

3. O comando acima irá retornar um arquivo JSON contendo os detalhes da VPC recém criada, incluindo seu ID. Copie o ID da VPC, pois você precisará dele para os próximos passos. <br>
4. Agora iremos criar as subnets públicas e privadas que irão compor nossa VPC. Para criar uma subnet dentro da VPC, execute o seguinte comando: <br>
```
aws ec2 creatsubnet --vpc-id <VPC ID> --cidr-block <CIDR block> --region <region>
```
> Substitua o `<VPC ID>` com o ID da VPC que você acabou de criar, e o `<CIDR block>` com o bloco de endereços IP que você deseja atrelar subnet, por exemplo `10.0.1.0/24`.

Basta repetir o procedimento agora para quantas subredes você desejar criar. 

> Algumas boas práticas para se manter em mente são: <br>
> 1. Planeje cuidadosamente os intervalos de endereços IP da sua sub-rede <br>
> 2. Use várias Zonas de Disponibilidade <br>
> 3. Use diferentes tipos de sub-redes (Públicas e Privadas) <br>
> 4. Use grupos de segurança e NACLs apropriados <br>
> 5. Considere o uso de diferentes sub-redes para diferentes camadas  <br>
> 6. Use nomes e tags descritivos <br>

<br>

 5. Para criar um Internet Gateway e atrelá-lo à sua VPC, execute os seguintes comandos: 

```
aws ec2 create-internet-gateway --region <region>
aws ec2 attach-internet-gateway --internet-gateway-id <internet gateway ID> --vpc-id <VPC ID> --region <region>
```

> Substitua `<internet gateway ID>` com o ID do internet gateway que foi criado.

<br>

 6. Finalmente, crie uma tabela de rotas pública para a VPC e associe ela com subnet criada anteriormente com os seguintes comandos: 

```
aws ec2 create-route-table --vpc-id <VPC ID> --region <region>
aws ec2 associate-route-table --route-table-id <route table ID> subnet-subnet ID> --region <region>
```
> Substitua `<route table ID>` com o Id da tabela de rota que acabou de ser criada e subnet ID>` com o ID da subnet criada anteriormente.

<br>

 7. Crie um IP Elástico que você possa associar com o seu Portão NAT com o comando: 
```
aws ec2 allocate-address --region <region>
```
> Guarde o AllocationID que é retornado pelo comando para ser usado nas próximas etapas.

 <br>
 
 8. Crie um Portão NAT usando o Endereço de IP Elástico 
```
aws ec2 create-nat-gateway --subnet-id <public subnet ID> --allocation-id <allocation ID> --region <region>`
```

> Substitua `public subnet ID` pelo ID de uma de suas subnets públicas, e `allocation ID` com o ID retornado pelo comando `allocate-address` na etapa anterior. Anote o ID do Portão NAT retornado pelo comando para as próximas etapas.

 <br>
 
 9. Crie uma tabela de rotas privada que aponte para o Portão NAT: 
```
aws ec2 create-route --route-table-id <private route table ID> --destination-cidr-block 0.0.0.0/0 --nat-gateway-id <NAT gateway ID> --region <region>`
```

> Substituaa `<private route table ID>` com o ID da tabela de rotas privada que você criou anteriormente, e o `<NAT gateway ID>` com o ID retornado pelo comando `create-nat-gateway` no passo anterior

<br>

10. Associe as subnets privadas à tabela de rotas: 

```
aws ec2 associate-route-table --route-table-id <private route table ID> --subnet-id <private subnet ID> --region <region>`
```
> Substitua `<private route table ID>` com o ID da tabela de rotas privada que você criou anteriormente, e `<private subnet ID>` pelo ID da subnet privada.

<br>

### **EFS**

Agora, iremos configurar nosso Amazon Elastic File system (EFS) em uma instância EC2 e torná-lo persistente para armazenar arquivos privados dos serviços que utilizaremos à seguir.

Para montar nosso EFS, você pode seguir o seguinte passo a passo<br>
1. Crie um Sistema de Arquivos EFS em sua conta AWS. Anote o `File System ID` para o sistema de arquivos que você criou. <br>
2. Configure um novo grupo de segurança e permitir tráfego de entrada do NFS que está atrelado ao Sistema de Arquivos EFS.
3. Instale o NFS-utils na sua instância EC2 usando o comando:
```
sudo yum install -y nfs-utils
```
<br>

4. Crie um diretório em sua instância EC2 que servirá como ponto de montagem para o sistema de arquivos EFS com o comando:
```
sudo mkdir /mnt/my-efs
```
<br>

5. Monte o sistema de arquivos EFS no diretório do ponto de montagem que você criou usando o comando :
```
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard, timeo=600,retrans=2 \
fs-12345678.efs.us-west-2.amazonaws.com:/ /mnt/my-efs
``` 
> Substitua `fs-12345678` com o File System ID do seu sistema de arquivos EFS.

<br>

6. Para  tornar a montagem persistente em caso de reinicializações é necessário adicionar uma entrada ao arquivo `/etc/fstab`. Por exemplo:
```
fs-12345678.efs.us-west-2.amazonaws.com:/ /mnt/my-efs nfs4 \    nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 0 0
```
> Isso adiciona uma entrada ao arquivo `/etc/fstab` que informa ao sistema para montar o sistema de arquivos EFS em `/mnt/my-efs` usando as mesmas opções do comando mount acima. Isso garante que o sistema de arquivos EFS seja montado automaticamente sempre que a instância do EC2 for iniciada.

### **RDS**

Agora iremos configurar nossa instância Amazon RDS que será usado para armazenar nosso banco de dados MySQL, que o WordPress irá usar para armazenar posts, páginas, comentários e outros dados do site.

Para isso, será necessário realizar as etapas listadas à seguir:

1. Crie um security group que irá permitir tráfego de entrada na sua instância RDS. Por exemplo:
```
aws ec2 create-security-group --group-name my-db-sg --description "Security Group do meu DB"
```

2. Configure o security group para permitir o tráfego de entrada para sua instância RDS executando o comando:
```
aws ec2 authorize-security-group-ingress --group-name my-db-sg --protocol tcp --port 3306 --cidr 0.0.0.0/0
```

3. Crie sua instância RDS com o MySQL Engine com o seguinte provisionamento:

```
aws rds create-db-instance \
    --db-instance-identifier mydbinstance \
    --allocated-storage 20 \
    --db-instance-class db.t2.micro \
    --engine mysql \
    --master-username mymasteruser \
    --master-user-password mymasterpassword \
    --vpc-security-group-ids my-db-sg \
    --availability-zone us-east-1a \
    --db-subnet-group-name mydbsubnetgroup \
    --preferred-maintenance-window "Mon:03:00-Mon:04:00"
```
4. Aguarde que sua instância RDS seja criada. Você pode usar o comando `describe-db-instances` para checar o status da sua instância.

5. Conecte-se à instância RDS usando o cliente MySQL, como o MySQL command-line client ou MySQL Workbench. Você pode encontrar o endpoint da instância RDS através do comando `describe-db-instances` com a opção `--query` para retornar a URL do endpoint.
   
### **ALB**

### **ASG**

### **Bastion**

### **SSL**

### **user_data.sh**

### **secrets/parameter store**

## **Docker-compose**

### **Container Wordpress**
