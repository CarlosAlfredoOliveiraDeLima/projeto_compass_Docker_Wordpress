#!/bin/bash

# Required Environment Variables:
#   WP_VPC_ID 

set -e

export AWS_REGION=us-east-1
export AWS_DEFAULT_OUTPUT="text"

MY_IP=$(curl ifconfig.me)

# Bastion Host SG
WP_BASTION_SG_ID=$(aws ec2 create-security-group --group-name 'wordpress-task-bastion-sg' --description 'Security group for Bastion host - Allows SSH' --vpc-id "$WP_VPC_ID"\
                --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=wordpress-task-bastion-sg}]'\
                --query 'GroupId')
# Allows SSH from my internet IP
aws ec2 authorize-security-group-ingress \
    --group-id "$WP_BASTION_SG_ID" \
    --protocol tcp \
    --port 22 \
    --cidr "$MY_IP"/32 > /dev/null
echo "Bastion Host SG <$WP_BASTION_SG_ID> configured"

# Application Load Balancer SG
WP_ALB_SG_ID=$(aws ec2 create-security-group --group-name 'wordpress-task-alb-sg' --description 'Security group for ALB - Allows HTTP and HTTPS' --vpc-id "$WP_VPC_ID"\
        --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=wordpress-task-alb-sg}]'\
        --query 'GroupId')
# Allows HTTP access from the internet
aws ec2 authorize-security-group-ingress \
    --group-id "$WP_ALB_SG_ID" \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 > /dev/null
# Allows HTTPS access from the internet
aws ec2 authorize-security-group-ingress \
    --group-id "$WP_ALB_SG_ID" \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 > /dev/null
echo "Application Load Balancer SG <$WP_ALB_SG_ID> configured"

# WordPress SG
WP_WP_SG_ID=$(aws ec2 create-security-group --group-name 'wordpress-task-sg' --description 'Security group for WordPress - Allows SSH and 8080' --vpc-id "$WP_VPC_ID"\
        --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=wordpress-task-sg}]'\
        --query 'GroupId')
# Allows access to the port 8080 from the ALB SG
aws ec2 authorize-security-group-ingress \
    --group-id "$WP_WP_SG_ID" \
    --protocol tcp \
    --port 8080 \
    --source-group "$WP_ALB_SG_ID" > /dev/null
# Allows SSH access from the Bastion Host SG
aws ec2 authorize-security-group-ingress \
    --group-id "$WP_WP_SG_ID" \
    --protocol tcp \
    --port 22 \
    --source-group "$WP_BASTION_SG_ID" > /dev/null
echo "WordPress SG <$WP_WP_SG_ID> configured"

# EFS SG
WP_EFS_SG_ID=$(aws ec2 create-security-group --group-name 'wordpress-task-efs-sg' --description 'Security group for EFS - Allows NFS' --vpc-id "$WP_VPC_ID"\
        --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=wordpress-task-efs-sg}]'\
        --query 'GroupId')
# Allows NFS access from the WordPress SG
aws ec2 authorize-security-group-ingress \
    --group-id "$WP_EFS_SG_ID" \
    --protocol tcp \
    --port 2049 \
    --source-group "$WP_WP_SG_ID" > /dev/null
echo "EFS SG <$WP_EFS_SG_ID> configured"

# RDS SG
WP_RDS_SG_ID=$(aws ec2 create-security-group --group-name 'wordpress-task-rds-sg' --description 'Security group for MySQL RDS - Allows MySQL//3306' --vpc-id "$WP_VPC_ID"\
        --tag-specifications 'ResourceType=security-group,Tags=[{Key=Name,Value=wordpress-task-rds-sg}]'\
        --query 'GroupId')
# Allows NFS access from the WordPress SG
aws ec2 authorize-security-group-ingress \
    --group-id "$WP_RDS_SG_ID" \
    --protocol tcp \
    --port 3306 \
    --source-group "$WP_WP_SG_ID" > /dev/null
echo "RDS SG <$WP_RDS_SG_ID> configured"