#!/bin/bash

# Required Environment Variables:
#   WP_EFS_URL
#   WP_RDS_MYSQL_ENDPOINT
#   WP_RDS_MYSQL_ADMIN_USER
#   WP_RDS_MYSQL_DBNAME
#   WP_RDS_MYSQL_ADMIN_PASSWD

set -e

export AWS_REGION=us-east-1
export AWS_DEFAULT_OUTPUT="text"

# Creates a role that can read SSM parameters to associate with EC2 instances
WP_SSM_ROLE_NAME="read-ssm-parameters-role"
aws iam create-role \
    --role-name "$WP_SSM_ROLE_NAME" \
    --assume-role-policy-document "file://$(dirname "$0")/ec2_trust_policy.json" > /dev/null

# Attaches a policy to the role
WP_SSM_POLICY_NAME="ReadSSMParametersPolicy"
aws iam put-role-policy \
    --role-name "$WP_SSM_ROLE_NAME" \
    --policy-name "$WP_SSM_POLICY_NAME" \
    --policy-document "file://$(dirname "$0")/ssm_read_policy.json" > /dev/null

WP_SSM_INSTANCE_PROFILE_NAME="read-ssm-parameters-profile"
aws iam create-instance-profile --instance-profile-name "$WP_SSM_INSTANCE_PROFILE_NAME" > /dev/null

aws iam add-role-to-instance-profile \
    --instance-profile-name "$WP_SSM_INSTANCE_PROFILE_NAME" \
    --role-name "$WP_SSM_ROLE_NAME" > /dev/null

echo "Instance Profile <$WP_SSM_INSTANCE_PROFILE_NAME> created"

aws ssm put-parameter \
    --name "/wp/efs-url" \
    --value "$WP_EFS_URL" \
    --type "SecureString" > /dev/null

aws ssm put-parameter \
    --name "/wp/db-host" \
    --value "$WP_RDS_MYSQL_ENDPOINT" \
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