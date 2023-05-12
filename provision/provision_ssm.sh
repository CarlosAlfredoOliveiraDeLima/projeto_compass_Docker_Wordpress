#!/bin/bash

# Required Environment Variables:
#   EFS_URL
#   RDS_MYSQL_WP_ENDPOINT
#   RDS_MYSQL_WP_ADMIN_USER
#   RDS_MYSQL_WP_DBNAME
#   RDS_MYSQL_WP_ADMIN_PASSWD

set -e

export AWS_REGION=us-east-1
export AWS_DEFAULT_OUTPUT="text"

# Creates a role that can read SSM parameters to associate with EC2 instances
SSM_ROLE_NAME="read-ssm-parameters-role"
aws iam create-role \
    --role-name "$SSM_ROLE_NAME" \
    --assume-role-policy-document file://ec2_trust_policy.json > /dev/null

# Attaches a policy to the role
SSM_POLICY_NAME="ReadSSMParametersPolicy"
aws iam put-role-policy \
    --role-name "$SSM_ROLE_NAME" \
    --policy-name "$SSM_POLICY_NAME" \
    --policy-document file://ssm_read_policy.json > /dev/null

SSM_INSTANCE_PROFILE_NAME="read-ssm-parameters-profile"
aws iam create-instance-profile --instance-profile-name "$SSM_INSTANCE_PROFILE_NAME" > /dev/null

aws iam add-role-to-instance-profile \
    --instance-profile-name "$SSM_INSTANCE_PROFILE_NAME" \
    --role-name "$SSM_ROLE_NAME" > /dev/null

echo "Instance Profile <$SSM_INSTANCE_PROFILE_NAME> created"

aws ssm put-parameter \
    --name "/wp/efs-url" \
    --value "$EFS_URL" \
    --type "SecureString" > /dev/null

aws ssm put-parameter \
    --name "/wp/db-host" \
    --value "$RDS_MYSQL_WP_ENDPOINT" \
    --type "SecureString" > /dev/null

aws ssm put-parameter \
    --name "/wp/db-name" \
    --value "$WORDPRESS_DB_NAME" \
    --type "SecureString" > /dev/null

aws ssm put-parameter \
    --name "/wp/db-user" \
    --value "$WORDPRESS_DB_USER" \
    --type "SecureString" > /dev/null

aws ssm put-parameter \
    --name "/wp/db-password" \
    --value "$WORDPRESS_DB_PASSWORD" \
    --type "SecureString" > /dev/null

echo "SSM WordPress parameters created"