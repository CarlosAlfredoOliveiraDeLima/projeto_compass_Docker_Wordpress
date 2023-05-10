# Projeto Docker + AWS + Wordpress - Compass.UOL
**Objetivo** <br>
Esse projeto tem como objetivo realizar o estudo do provisionamento de instâncias EC2 através de user_data.sh, provisionamento do serviço Wordpress através de um container Docker, configurar um Application Load Balancer (ALB) para realizar o balanço de requisições em multiplas Regiões de Disponibilidade num Auto Scaling Group (ASG). E, também, configurar um Amazon Relational Database Service (AWS RDS) para gerenciar  os arquivos privados do Wordpress num volume EFS.

** TO-DO ** <br>
+ Sessão VPC - Adicionar breve explicação sobre o uso da VPC e dessa arquitetura
+  


## Requisitos

1. AWS CLI Instalado e Configurado.
2. Conhecimento em Redes.
3. Conhecimento em Docker e Docker-compose.
4. Conhecimento do Sistema Operacional Linux.
5. Conhecimento de AWS CLI e GUI.

## Arquitetura AWS

### **VPC**

Primeiramente iremos configurar nossa VPC. Incluindo as subnets que iremos utilizar, tabelas de rota, Internet Gateway e NAT Gate.

1. Instale e Configure a AWS CLI em sua máquina local. <br>
2. Abra seu terminal e execute o seguinte comando para criar a VPC: <br>
```
aws ec2 create-vpc --cidr-block <CIDR block> --region <region>
```

> Substitua o `<CIDR block>` com o block de endereços de IP que você deseja atrelar à sua VPC. Como por exemplo: `10.0.0.0/16`. substitua `<region>` com o código da região que você deseja criar sua VPC. Por exemplo, `ap-southeast-2`.

3. O comando acima irá retornar um arquivo JSON contendo os detalhes da VPC recém criada, incluindo seu ID. Copie o ID da VPC, pois você precisará dele para os próximos passos. <br>
4. Agora iremos criar as subnets públicas e privadas que irão compor nossa VPC. Para criar uma subnet dentro da VPC, execute o seguinte comando: <br>
```
aws ec2 creatsubnet --vpc-id <VPC ID> --cidr-block <CIDR block> --region <region>
```
> Substitua o `<VPC ID>` com o ID da VPC que você acabou de criar, e o `<CIDR block>` com o bloco de endereços IP que você deseja atrelar subnet, por exemplo `10.0.1.0/24`.

Basta repetir o procedimento agora para quantas subredes você desejar criar. 

> Algumas boas práticas para se manter em mante são: <br>
> 1.Planeje cuidadosamente os intervalos de endereços IP da sua sub-rede <br>
> 2.Use várias Zonas de Disponibilidade <br>
> 3.Use diferentes tipos de sub-redes (Públicas e Privadas) <br>
> 4.Use grupos de segurança e NACLs apropriados <br>
> 5.Considere o uso de diferentes sub-redes para diferentes camadas  <br>
> 6.Use nomes e tags descritivos <br>


5. Para criar um Internet Gateway e atrelá-lo à sua VPC, execute os seguintes comandos: <br>

```
aws ec2 create-internet-gateway --region <region>
aws ec2 attach-internet-gateway --internet-gateway-id <internet gateway ID> --vpc-id <VPC ID> --region <region>
```

> Substitua `<internet gateway ID>` com o ID do internet gateway que foi criado.

6. Finalmente, crie uma tabela de rotas pública para a VPC e associe ela com subnet criada anteriormente com os seguintes comandos: <br>

```
aws ec2 create-route-table --vpc-id <VPC ID> --region <region>
aws ec2 associate-route-table --route-table-id <route table ID> subnet-subnet ID> --region <region>
```
> Substitua `<route table ID>` com o Id da tabela de rota que acabou de ser criada e subnet ID>` com o ID da subnet criada anteriormente.

7. Crie um IP Elástico que você possa associar com o seu Portão NAT com o comando: <br>
```
aws ec2 allocate-address --region <region>
```
> Guarde o AllocationID que é retornado pelo comando para ser usado nas próximas etapas.

8. Crie um Portão NAT usando o Endereço de IP Elástico <br>
```
aws ec2 create-nat-gateway --subnet-id <public subnet ID> --allocation-id <allocation ID> --region <region>`
```

> Substitua `public subnet ID` pelo ID de uma de suas subnets públicas, e `allocation ID` com o ID retornado pelo comando `allocate-address` na etapa anterior. Anote o ID do Portão NAT retornado pelo comando para as próximas etapas.

9. Crie uma tabela de rotas privada que aponte para o Portão NAT: <br>
```
aws ec2 create-route --route-table-id <private route table ID> --destination-cidr-block 0.0.0.0/0 --nat-gateway-id <NAT gateway ID> --region <region>`
```

> Substituaa `<private route table ID>` com o ID da tabela de rotas privada que você criou anteriormente, e o `<NAT gateway ID>` com o ID retornado pelo comando `create-nat-gateway` no passo anterior

10. Associe as subnets privadas à tabela de rotas: <br>

```
aws ec2 associate-route-table --route-table-id <private route table ID> --subnet-id <private subnet ID> --region <region>`
```
> Substitua `<private route table ID>` com o ID da tabela de rotas privada que você criou anteriormente, e `<private subnet ID>` pelo ID da subnet privada.

### EFS

Agora, iremos configurar nosso Amazon Elastic File system (EFS) em uma instância EC2 e torná-lo persistente para armazenar arquivos privados dos serviços que utilizaremos à seguir.

Para montar nosso EFS, você pode seguir o seguinte passo a passo<br>
1. Crie um Sistema de Arquivos EFS em sua conta AWS. Anote o `File System ID` para o sistema de arquivos que você criou. <br>
2. Configure um novo grupo de segurança e permitir tráfego de entrada do NFS que está atrelado ao Sistema de Arquivos EFS.
3. Instale o NFS-utils na sua instância EC2 usando o comando:
```
sudo yum install -y nfs-utils
```
4. Crie um diretório em sua instância EC2 que servirá como ponto de montagem para o sistema de arquivos EFS com o comando:
```
sudo mkdir /mnt/my-efs
```
5. Monte o sistema de arquivos EFS no diretório do ponto de montagem que você criou usando o comando :
```
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard, timeo=600,retrans=2 \
fs-12345678.efs.us-west-2.amazonaws.com:/ /mnt/my-efs
``` 
> Substitua `fs-12345678` com o File System ID do seu sistema de arquivos EFS.

6. Para  tornar a montagem persistente em caso de reinicializações é necessário adicionar uma entrada ao arquivo `/etc/fstab`. Por exemplo:
```
fs-12345678.efs.us-west-2.amazonaws.com:/ /mnt/my-efs nfs4 \    nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 0 0
```
> Isso adiciona uma entrada ao arquivo `/etc/fstab` que informa ao sistema para montar o sistema de arquivos EFS em `/mnt/my-efs` usando as mesmas opções do comando mount acima. Isso garante que o sistema de arquivos EFS seja montado automaticamente sempre que a instância do EC2 for iniciada.

### RDS

### ALB

### ASG

### Bastion

### SSL

### user_data.sh

### secrets/parameter store

## Docker-compose

### Container Wordpress
