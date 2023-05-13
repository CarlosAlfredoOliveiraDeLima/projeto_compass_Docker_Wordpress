#!/bin/bash

# Required Environment Variables:
#   WP_RDS_PRIV_SUBNET_1
#   WP_RDS_PRIV_SUBNET_2
#   WP_RDS_SG_ID

set -e

export AWS_REGION=us-east-1
export AWS_DEFAULT_OUTPUT="text"
export TAGS='{"Key":"Task","Value":"Docker-WordPress"},{"Key":"Project","Value":"PB UNIVESP URI"},{"Key":"CostCenter","Value":"C092000004"}'

WP_DB_SUBNET_GROUP_NAME=wordpress-task-rds-mysql-subnet-group
# Creates a subnet group for the RDS instance
aws rds create-db-subnet-group \
    --db-subnet-group-name $WP_DB_SUBNET_GROUP_NAME \
    --db-subnet-group-description "Subnet Group for MySQL RDS" \
    --subnet-ids "[\"$WP_RDS_PRIV_SUBNET_1\",\"$WP_RDS_PRIV_SUBNET_2\"]" \
    --tags "[{\"Key\":\"Name\",\"Value\":\"$WP_DB_SUBNET_GROUP_NAME\"},$TAGS]" > /dev/null

echo "RDS Subnet Group <$WP_DB_SUBNET_GROUP_NAME> created"

WP_RDS_MYSQL_ID="wordpress-task-rds-mysql"
WP_RDS_MYSQL_ADMIN_USER="admin"
WP_RDS_MYSQL_DBNAME="wordpress"
WP_RDS_MYSQL_ADMIN_PASSWD=$(gpg --gen-random --armor 1 21 | tail -1 | head -c 20 | sed 's![@/]!!g')

echo "DB name: ${WP_RDS_MYSQL_DBNAME}"
echo "Admin user: ${WP_RDS_MYSQL_ADMIN_USER}"
echo "Admin password: ${WP_RDS_MYSQL_ADMIN_PASSWD}" | tee rds-admin-password.txt

# Creates an RDS MySQL instance
aws rds create-db-instance \
    --db-instance-identifier "$WP_RDS_MYSQL_ID" \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --engine-version "8.0.32" \
    --master-username "$WP_RDS_MYSQL_ADMIN_USER" \
    --master-user-password "$WP_RDS_MYSQL_ADMIN_PASSWD" \
    --db-name "$WP_RDS_MYSQL_DBNAME" \
    --allocated-storage 20 \
    --max-allocated-storage 25 \
    --storage-type gp3 \
    --db-subnet-group-name "$WP_DB_SUBNET_GROUP_NAME" \
    --vpc-security-group-ids "$WP_RDS_SG_ID" \
    --no-publicly-accessible \
    --backup-retention-period 0 \
    --no-auto-minor-version-upgrade \
    --tags "[{\"Key\":\"Name\",\"Value\":\"$WP_RDS_MYSQL_ID\"},$TAGS]" > /dev/null

while [[ $(aws rds describe-db-instances --db-instance-identifier $WP_RDS_MYSQL_ID --query 'DBInstances[0].DBInstanceStatus') != "available" ]]
do
sleep 30
done

WP_RDS_MYSQL_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $WP_RDS_MYSQL_ID --query 'DBInstances[0].Endpoint.Address')

echo "RDS Endpoint: ${WP_RDS_MYSQL_ENDPOINT}"