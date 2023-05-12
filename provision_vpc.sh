#!/bin/bash

set -e

AWS_REGION=us-east-1
AWS_DEFAULT_OUTPUT="text"

# Creates VPC and enables hostname DNS resolution
VPC_ID=$(aws ec2 create-vpc --cidr-block 172.16.0.0/16 --query="Vpc.VpcId" --output text --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=wordpress-task-vpc}]')
aws ec2 modify-vpc-attribute --enable-dns-hostnames --vpc-id $VPC_ID
echo "VPC <$VPC_ID> created"

# Creates all subnets to be used in the project
PRIV_SUBNET_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --availability-zone us-east-1a --cidr-block 172.16.0.0/22 --query='Subnet.SubnetId' --output text --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=wordpress-task-priv-subnet-1}]')
echo "Private subnet 1 <$PRIV_SUBNET_1> created"
PRIV_SUBNET_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --availability-zone us-east-1b --cidr-block 172.16.4.0/22 --query='Subnet.SubnetId' --output text --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=wordpress-task-priv-subnet-2}]')
echo "Private subnet 2 <$PRIV_SUBNET_2> created"
PUB_SUBNET_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --availability-zone us-east-1a --cidr-block 172.16.250.0/24 --query='Subnet.SubnetId' --output text --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=wordpress-task-pub-subnet-1}]')
echo "Public subnet 1 <$PUB_SUBNET_1> created"
RDS_PRIV_SUBNET_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --availability-zone us-east-1a --cidr-block 172.16.254.0/28 --query='Subnet.SubnetId' --output text --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=wordpress-task-rds-priv-subnet-1}]')
echo "Private RDS subnet 1 <$RDS_PRIV_SUBNET_1> created"
RDS_PRIV_SUBNET_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --availability-zone us-east-1b --cidr-block 172.16.254.16/28 --query='Subnet.SubnetId' --output text --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=wordpress-task-rds-priv-subnet-2}]')
echo "Private RDS subnet 2 <$RDS_PRIV_SUBNET_2> created"

# Creates an Internet Gateway and associates it with the preveiously created VPC 
IGW_ID=$(aws ec2 create-internet-gateway --query='InternetGateway.InternetGatewayId' --output text --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=wordpress-task-igw}]')
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
echo "Internet Gateway <$IGW_ID> created"

# Allocates an Elastic IP for the NAT Gateway
NATGW_PUB_IP_ID=$(aws ec2 allocate-address --query='AllocationId' --output text --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=wordpress-task-natgw-pub-ip}]')
echo "NAT Gateway Elastic IP <$NATGW_PUB_IP_ID> allocated"

# Create a public NAT Gateway with the previously allocated Elastic IP
NATGW_ID=$(aws ec2 create-nat-gateway --subnet-id $PUB_SUBNET_1 --allocation-id $NATGW_PUB_IP_ID --connectivity-type public --query='NatGateway.NatGatewayId' --output text --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=wordpress-task-natgw}]')
while [[ `aws ec2 describe-nat-gateways --nat-gateway-ids $NATGW_ID --query 'NatGateways[0].State' --output text` != "available" ]]
do
sleep 10
done
echo "NAT Gateway <$NATGW_ID> created"

# Gets the VPC's main route table id, adds a name tag to the route table and create a route to the Internet through the previously created NAT Gateway
PRIV_RTB_ID=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=true" --query 'RouteTables[*].RouteTableId' --output text)
aws ec2 create-tags --resources $PRIV_RTB_ID --tags Key=Name,Value=wordpress-task-riv-rtb
aws ec2 create-route --route-table-id $PRIV_RTB_ID --gateway-id $NATGW_ID --destination-cidr-block 0.0.0.0/0 > /dev/null
echo "Private route table <$PRIV_RTB_ID> configured"

# Creates a new route table and adds to it a route to the internet through the previously created Internet Gateway
PUB_RTB_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query='RouteTable.RouteTableId' --output text --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=wordpress-task-pub-rtb}]')
aws ec2 create-route --route-table-id $PUB_RTB_ID --gateway-id $IGW_ID --destination-cidr-block 0.0.0.0/0 > /dev/null
echo "Public route table <$PUB_RTB_ID> configured"

# Associates the private subnets with their respective route table
for subnet in $PRIV_SUBNET_1 $PRIV_SUBNET_2 $RDS_PRIV_SUBNET_1 $RDS_PRIV_SUBNET_2
do
aws ec2 associate-route-table --route-table-id $PRIV_RTB_ID --subnet-id $subnet
done
echo "Private subnets route table associations done"

# Associates the only public subnet with the public route table
aws ec2 associate-route-table --route-table-id $PUB_RTB_ID --subnet-id $PUB_SUBNET_1
echo "Public subnet route table association done"