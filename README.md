# **Projeto Wordpress escalável e de alta disponibilidade com Docker e AWS - Compass.UOL**
**Objetivo** <br>
O presente projeto, tem como objetivo ser um exercício prático de implementação de uma plataforma Wordpress que foi pensada para ser altalmente escalável e de alta disponibilidade, provisionada sob a infraestrutura da AWS com uso de Docker.

**Arquitetura** <br>

A arquitetura da plataforma é estabelecida sobre uma VPC na AWS onde permitira a conversa via rede de todos componentes de forma segura e restrita. Esta VPC é disponibilizada em várias AZ, permitindo um nível de segurança maior. Nela, há subnets públicas e privadas, que implementará mais um nível de segurança através do emprego de Bastion Host na subnet pública comunicando as instâncias que sustentam o sistema Wordpress nas subnets privadas.

Para a comunicação exterior à VPC, é usado um Internet Gateway que dá acesso à rede ao Bastion Host, que uma vez acessando as instâncias privadas, tem acesso à internet para download de pacotes através do NAT Gateway(este apesar de conceder acesso às subnets privadas está conectado à uma subnet pública).

Toda estrutura é protegida por firewalls, neste caso, usamos os Security Groups, porém poderíamos também fazer uso de Networks ACLs. As instâncias que suportam o Wordpress(instâncias privadas) se encontram em subnets privadas e com isto também em Security Groups isolados pois o Bastion Host possui um Security Group exclusivo que permite o acesso à rede externa.

As instâncias privadas se conectam à um volume EFS para armazenamento de metadados e dados estáticos do Wordpress, importante notar que todas instâncias se conectam, neste caso, à um único volume EFS.

Para persistência dos dados gerais do Wordpress é usado uma instância MySQL no RDS, por questões de segurança este RDS possuí um Security Group exclusivo, onde é liberado acesso somenta aos Security Groups privados, por consequência, acesso apenas às instâncias privadas.

Por uma questão de disponibilidade, empregamos um Application Load Balancer que distribui as requisições à todas instâncias privadas. Um ponto interessante é que o Application Load Balancer distribui as requisições para instâncias que estão em Subnets privadas, porém ele está ligado à Subnet pública para ser disponibilizado para a internet através do Internet Gateway. O Application Load Balancer também está ligado ao Route 53 para disponibilização de DNS.

Toda estrutura das instâncias privadas são gerenciadas pelo Auto Scaling Group que aumenta e diminui a quantidade de instâncias privadas de acordo com a necessidade. O Auto Scaling Group se comunica com o Application Load Balancer para que o roteamento de requisições se adapte à quantidade de instâncias privadas operando em cada momento.

## **Arquitetura AWS**

![Diagrama da arquitetura](static/diagram.png)