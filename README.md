# **Projeto Wordpress escalável e de alta disponibilidade com Docker e AWS - Compass.UOL**

## **Objetivo** <br>
O presente projeto, tem como objetivo ser um exercício prático de implementação de uma plataforma Wordpress que foi pensada para ser altalmente escalável e de alta disponibilidade, provisionada sob a infraestrutura da AWS com uso de Docker.
<br><br>
## **Arquitetura** <br>

A arquitetura da plataforma é estabelecida sobre uma VPC na AWS onde permitirá a comunicação via rede de todos componentes de forma segura e restrita. Esta VPC é disponibilizada em várias Availability Zones, permitindo um nível de segurança física maior. Nela, há subnets públicas e privadas, que implementarão mais um nível de segurança com o emprego de Bastion Host na subnet pública comunicando as instâncias que sustentam o sistema Wordpress nas subnets privadas.

Para a comunicação exterior à VPC, é usado um Internet Gateway que dá acesso à rede ao Bastion Host, que uma vez acessando as instâncias privadas, tem acesso à internet para download de pacotes de forma segura através do NAT Gateway(este apesar de conceder acesso às subnets privadas está conectado à uma subnet pública).

Toda estrutura é protegida por firewalls, neste caso, usamos os Security Groups, porém poderíamos também fazer uso de Networks ACLs para acrescentar maior segurança. As instâncias que suportam o Wordpress(instâncias privadas) se encontram em subnets privadas e com isto também em Security Groups isolados pois o Bastion Host possui um Security Group exclusivo que permite o acesso à rede externa.

As instâncias privadas se conectam à um volume Elastic File System(EFS) para armazenamento dados estáticos do Wordpress, importante notar que todas instâncias se conectam, neste caso, à um único volume EFS.

Para persistência dos dados gerais do Wordpress é usado uma instância MySQL no Relational Database Service(RDS), por questões de segurança este RDS possui um Security Group exclusivo, onde é liberado acesso somente aos Security Groups privados, por consequência, acesso apenas às instâncias privadas.

Por uma questão de disponibilidade, empregamos um Application Load Balancer que distribui as requisições à todas instâncias privadas. Um ponto interessante é que o Application Load Balancer distribui as requisições para instâncias que estão em Subnets privadas, porém ele está ligado à Subnet pública para ser disponibilizado para a internet através do Internet Gateway. O Application Load Balancer também está ligado ao Route 53 para disponibilização de DNS.

Toda estrutura de escalabilidade das instâncias privadas estão sob gerencia do Auto Scaling Group que aumenta e diminui a quantidade de instâncias privadas de acordo com a necessidade. O Auto Scaling Group se comunica com o Application Load Balancer para que o roteamento de requisições se adapte à quantidade de instâncias privadas operando em cada momento. <br><br>


## **Diagrama da Arquitetura AWS**<br>

![Diagrama da arquitetura](static/diagram.png)
<br><br>
## **Instalação**

Neste projeto a arquitetura foi implantada usando instâncias t3.small com sistema operacional Amazon Linux 2. É possível implementar a arquitetura manual através do console AWS, também com uso de Terraform ou Cloudformation, como também por automatização de shell script com acesso à AWS CLI.

No diretório provision há os arquivos shell contendo a execução dos passos para criação via CLI, o arquivo inicial é o ```provision_all.sh```.

Para dúvidas sobre os comando AWS CLI nos scripts e suas funções, na área de Wiki deste repositório há uma explicação com exemplo sobre os comandos.
