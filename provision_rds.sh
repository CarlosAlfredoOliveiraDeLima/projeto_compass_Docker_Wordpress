#!/bin/bash

# Required Environment Variables:
#   RDS_PRIV_SUBNET_1
#   RDS_PRIV_SUBNET_2
#   RDS_SG_ID

set -e

AWS_REGION=us-east-1
AWS_DEFAULT_OUTPUT="text"

DB_SUBNET_GROUP_NAME=wordpress-task-rds-mysql-subnet-group
# Creates a subnet group for the RDS instance
aws rds create-db-subnet-group \
    --db-subnet-group-name $DB_SUBNET_GROUP_NAME \
    --db-subnet-group-description "Subnet Group for MySQL RDS" \
    --subnet-ids "[\"$RDS_PRIV_SUBNET_1\",\"$RDS_PRIV_SUBNET_2\"]" > /dev/null

RDS_MYSQL_WP_ID=wordpress-task-rds-mysql
RDS_MYSQL_WP_ADMIN_USER=admin
RDS_MYSQL_WP_DBNAME=wordpress
RDS_MYSQL_WP_ADMIN_PASSWD=$(gpg --gen-random --armor 1 21 | tail -1 | head -c 20 | sed 's![@/]!!g')
# Creates an RDS MySQL instance
aws rds create-db-instance \
    --db-instance-identifier $RDS_MYSQL_WP_ID \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --engine-version "8.0.32" \
    --master-username $RDS_MYSQL_WP_ADMIN_USER \
    --master-user-password $RDS_MYSQL_WP_ADMIN_PASSWD \
    --db-name $RDS_MYSQL_WP_DBNAME \
    --allocated-storage 20 \
    --max-allocated-storage 25 \
    --storage-type gp3 \
    --db-subnet-group-name $DB_SUBNET_GROUP_NAME \
    --vpc-security-group-ids $RDS_SG_ID \
    --no-publicly-accessible \
    --backup-retention-period 0 \
    --no-auto-minor-version-upgrade > /dev/null

while [[ `aws rds describe-db-instances --db-instance-identifier $RDS_MYSQL_WP_ID --query 'DBInstances[0].DBInstanceStatus'` != "available" ]]
do
sleep 30
done

RDS_MYSQL_WP_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier $RDS_MYSQL_WP_ID --query 'DBInstances[0].Endpoint.Address')

echo "RDS Endpoint: $RDS_MYSQL_WP_ENDPOINT"
echo "DB name: $RDS_MYSQL_WP_DBNAME"
echo "Admin user: $RDS_MYSQL_WP_ADMIN_USER"
echo "Admin password: $RDS_MYSQL_WP_ADMIN_PASSWD"
