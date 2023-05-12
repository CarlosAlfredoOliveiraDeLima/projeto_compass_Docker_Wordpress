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


### **Virtual Private Network (VPC)**

Uma VPC é um ambiente de redes dentro da AWS que nos permite criar uma seções isoladas da Cloud AWS. Nesse ambiente, podemos provisionar alguns recursos, como instâncias EC2, Banco de Dados RDS, Load balancers Elásticos na rede virtual que nós definirmos.

Nesse projeto iremos configurar toda nossa arquitetura dentro  da AWS iniciando pela VPC, já que os demais elementos irão ser disponibilizados dentro da VPC. Isso irá incluir as subnets que iremos utilizar, tabelas de rota, Internet Gateway e NAT Gate.

Dessa forma, iremos criar ambientes seguros e isolados, podendo nos dar escalabilidade e flexibilidade dentro da cloud.

Para configurar nossa VPC, siga os passos à seguir:

<br>

1. Instale e Configure a AWS CLI em sua máquina local.
2. Você pode criar sua VPC usando o comando `create-vpc`, como no exemplo abaixo:
```
aws ec2 create-vpc --cidr-block <CIDR block> --region <region>
```
> Substitua o `<CIDR block>` com o block de endereços de IP que você deseja atrelar à sua VPC. Como por exemplo: `10.0.0.0/16`. substitua `<region>` com o código da região que você deseja criar sua VPC. Por exemplo, `ap-southeast-2`.

<br>

3. O comando acima irá retornar um arquivo JSON contendo os detalhes da VPC recém criada, incluindo seu ID. Copie o ID da VPC, pois você precisará dele para os próximos passos. <br>
4. Agora iremos criar as subnets públicas e privadas que irão compor nossa VPC. Você pode criar uma subnet dentro da sua VPC com o comando `createsubnet` e passando alguns parâmetros como o `vpc-id`, `cidr-block` e `region`. Como no exemplo abaixo: <br>
```
aws ec2 createsubnet --vpc-id <VPC ID> --cidr-block <CIDR block> --region <region>
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

 5. Você pode criar um Internet gateway com o comando `create-internet-gateway`, especificando `region` e atrelá-lo ao seu VPC com o comando `attach-internet-gateway`, como no exemplo abaixo: 

```
aws ec2 create-internet-gateway --region <region>
aws ec2 attach-internet-gateway --internet-gateway-id <internet gateway ID> --vpc-id <VPC ID> --region <region>
```

> Substitua `<internet gateway ID>` com o ID do internet gateway que foi criado.

<br>

 6. Finalmente, crie uma tabela de rotas pública para a VPC com o comando `create-route-table` e associe ela com subnet criada anteriormente com o comando `associate-route-table`, como no exemplo abaixo: 

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

### **Elastic File System (EFS)**

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

<br>

### **Amazon Web Services Relational Database Service (RDS)**

Agora iremos configurar nossa instância Amazon RDS que será usado para armazenar nosso banco de dados MySQL, que o WordPress irá usar para armazenar posts, páginas, comentários e outros dados do site.

Para isso, será necessário realizar as etapas listadas à seguir:

1. Crie um security group que irá permitir tráfego de entrada na sua instância RDS. Por exemplo:
```
aws ec2 create-security-group --group-name my-db-sg --description "Security Group do meu DB"
```

2. Configure o security group para permitir o tráfego de entrada para sua instância RDS. Por exemplo:
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

<br>

### **Application Load Balancer (ALB)**


O ALB servirá para distribuir o tráfego recebido pela aplicação para diferentes alvos, como Instâncias EC2, containers e endereços de IP. Ele opera na camada 7 do modelo OSI, tornando possível a tomada inteligente de decisões baseada no conteúdo das chamadas HTTP/HTTPS.

 Para configurar o ALB usando AWS CLI você pode seguir os seguintes passos:
 1. Crie um target group. Um target group nada mais é do que um agrupamento lógico de alvos para onde você deseja distribuir o tráfego da sua aplicação. Você pode criar esse grupo usando o comando `create-target-group`, especificando alguns atributos. Como no exemplo abaixo:

 ```
aws elbv2 create-target-group \
  --name my-target-group \
  --protocol HTTP \
  --port 80 \
  --target-type instance \
  --vpc-id <seu-endereço-vpc>
 ```
> Substitua `seu-endereço-vpc` pelo IF da sua VPC onde suas instâncias EC2 estão criadas.

<br>

2. Registre os Alvos como no exemplo abaixo:

```
aws elbv2 register-targets \
  --target-group-arn <target-group-arn> \
  --target Id =<instance-id>
```

>Substitua `<target-group-arn>` com o ARN do grupo alvo que você criou no passo anterior, E substitua `<instance-id>` com o ID da instância EC2 que você deseja registrar como alvo.

<br>

3. Crie seu Load Balancer como no exemplo:
```
aws elbv2 create-load-balancer \
  --name my-load-balancer \
  --subnets <ids-da-subnet-separado-por-virgula> \
  --security-groups <ids-dos-security-groups-separado-por-virgula> \
```
> Substitua `<ids-da-subnet-separado-por-virgula>` pelos IDs das subnets que você deseja que o ALB seja implantado. Substitua `<ids-dos-security-groups-separado-por-virgula>` com os IDs dos security groups que você deseja associar com o ALB.

<br>

4. Configure os listeners como no exemplo abaixo:
```
aws elbv2 create-listener \
  --load-balancer-arn <load-balancer-arn> \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=<target-group-arn>
```

> Substitua `<load-balancer-arn>` com o ARN do ALB que você criou no terceiro passo. E substitua `<target-group-arn>` com o ARN do grupo alvo criado.
 
<br>

5. Verifique a configuração do ALB com o comando 

```
aws elbv2 describe-load-balancers
```
> Esse comando irá mostrar os detalhes de do ALB, incluindo o status atual e configurações.

### **AMI**

### **Auto Scaling Groups (ASG)**

### **Hosts bastion do Linux na AWS**

### **Certificado SSL**

### **Configuração do user_data.sh**

### **Configuração do secrets/parameter store**

## **Docker-compose**

### **Configurando seu Container Wordpress**
