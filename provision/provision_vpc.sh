#!/bin/bash

set -e

export AWS_REGION=us-east-1
export AWS_DEFAULT_OUTPUT="text"

# Creates VPC and enables hostname DNS resolution
WP_VPC_ID=$(aws ec2 create-vpc --cidr-block 172.16.0.0/16 --query="Vpc.VpcId"  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=wordpress-task-vpc}]')
aws ec2 modify-vpc-attribute --enable-dns-hostnames --vpc-id "$WP_VPC_ID"
echo "VPC <$WP_VPC_ID> created"

# Creates all subnets to be used in the project
WP_PRIV_SUBNET_1=$(aws ec2 create-subnet --vpc-id "$WP_VPC_ID" --availability-zone us-east-1a --cidr-block 172.16.0.0/22 --query='Subnet.SubnetId' \
            --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=wordpress-task-priv-subnet-1}]')
echo "Private subnet 1 <$WP_PRIV_SUBNET_1> created"
WP_PRIV_SUBNET_2=$(aws ec2 create-subnet --vpc-id "$WP_VPC_ID" --availability-zone us-east-1b --cidr-block 172.16.4.0/22 --query='Subnet.SubnetId' \
            --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=wordpress-task-priv-subnet-2}]')
echo "Private subnet 2 <$WP_PRIV_SUBNET_2> created"
WP_PUB_SUBNET_1=$(aws ec2 create-subnet --vpc-id "$WP_VPC_ID" --availability-zone us-east-1a --cidr-block 172.16.250.0/24 --query='Subnet.SubnetId' \
            --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=wordpress-task-pub-subnet-1}]')
echo "Public subnet 1 <$WP_PUB_SUBNET_1> created"
WP_PUB_SUBNET_2=$(aws ec2 create-subnet --vpc-id "$WP_VPC_ID" --availability-zone us-east-1b --cidr-block 172.16.251.0/24 --query='Subnet.SubnetId' \
            --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=wordpress-task-pub-subnet-2}]')
echo "Public subnet 2 <$WP_PUB_SUBNET_2> created"
WP_RDS_PRIV_SUBNET_1=$(aws ec2 create-subnet --vpc-id "$WP_VPC_ID" --availability-zone us-east-1a --cidr-block 172.16.254.0/28 --query='Subnet.SubnetId' \
            --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=wordpress-task-rds-priv-subnet-1}]')
echo "Private RDS subnet 1 <$WP_RDS_PRIV_SUBNET_1> created"
WP_RDS_PRIV_SUBNET_2=$(aws ec2 create-subnet --vpc-id "$WP_VPC_ID" --availability-zone us-east-1b --cidr-block 172.16.254.16/28 --query='Subnet.SubnetId' \
            --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=wordpress-task-rds-priv-subnet-2}]')
echo "Private RDS subnet 2 <$WP_RDS_PRIV_SUBNET_2> created"

# Creates an Internet Gateway and associates it with the preveiously created VPC 
WP_IGW_ID=$(aws ec2 create-internet-gateway --query='InternetGateway.InternetGatewayId'  --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=wordpress-task-igw}]')
aws ec2 attach-internet-gateway --internet-gateway-id "$WP_IGW_ID" --vpc-id "$WP_VPC_ID"
echo "Internet Gateway <$WP_IGW_ID> created"

# Allocates an Elastic IP for the NAT Gateway
WP_NATGW_PUB_IP_ID=$(aws ec2 allocate-address --query='AllocationId'  --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=wordpress-task-natgw-pub-ip}]')
echo "NAT Gateway Elastic IP <$WP_NATGW_PUB_IP_ID> allocated"

# Create a public NAT Gateway with the previously allocated Elastic IP
WP_NATGW_ID=$(aws ec2 create-nat-gateway --subnet-id "$WP_PUB_SUBNET_1" --allocation-id "$WP_NATGW_PUB_IP_ID" --connectivity-type public --query='NatGateway.NatGatewayId'  --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=wordpress-task-natgw}]')
while [[ $(aws ec2 describe-nat-gateways --nat-gateway-ids "$WP_NATGW_ID" --query 'NatGateways[0].State' ) != "available" ]]
do
sleep 10
done
echo "NAT Gateway <$WP_NATGW_ID> created"

# Gets the VPC's main route table id, adds a name tag to the route table and create a route to the Internet through the previously created NAT Gateway
WP_PRIV_RTB_ID=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$WP_VPC_ID" "Name=association.main,Values=true" --query 'RouteTables[*].RouteTableId' )
aws ec2 create-tags --resources "$WP_PRIV_RTB_ID" --tags Key=Name,Value=wordpress-task-riv-rtb
aws ec2 create-route --route-table-id "$WP_PRIV_RTB_ID" --gateway-id "$WP_NATGW_ID" --destination-cidr-block 0.0.0.0/0 > /dev/null
echo "Private route table <$WP_PRIV_RTB_ID> configured"

# Creates a new route table and adds to it a route to the internet through the previously created Internet Gateway
WP_PUB_RTB_ID=$(aws ec2 create-route-table --vpc-id "$WP_VPC_ID" --query='RouteTable.RouteTableId'  --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=wordpress-task-pub-rtb}]')
aws ec2 create-route --route-table-id "$WP_PUB_RTB_ID" --gateway-id "$WP_IGW_ID" --destination-cidr-block 0.0.0.0/0 > /dev/null
echo "Public route table <$WP_PUB_RTB_ID> configured"

# Associates the private subnets with their respective route table
for subnet in $WP_PRIV_SUBNET_1 $WP_PRIV_SUBNET_2 $WP_RDS_PRIV_SUBNET_1 $WP_RDS_PRIV_SUBNET_2
do
aws ec2 associate-route-table --route-table-id "$WP_PRIV_RTB_ID" --subnet-id "$subnet"
done
echo "Private subnets route table associations done"

for subnet in $WP_PUB_SUBNET_1 $WP_PUB_SUBNET_2
do
aws ec2 associate-route-table --route-table-id "$WP_PUB_RTB_ID" --subnet-id "$subnet"
done
echo "Public subnet route table association done"