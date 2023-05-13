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
export TAGS='{"Key":"Task","Value":"Docker-WordPress"},{"Key":"Project","Value":"PB UNIVESP URI"},{"Key":"CostCenter","Value":"C092000004"}'

# Creates a role that can read SSM parameters to associate with EC2 instances
WP_SSM_ROLE_NAME="read-ssm-parameters-role"
aws iam create-role \
    --role-name "$WP_SSM_ROLE_NAME" \
    --assume-role-policy-document "file://$(dirname "$0")/ec2_trust_policy.json" \
    --tags "[{\"Key\":\"Name\",\"Value\":\"$WP_SSM_ROLE_NAME\"},$TAGS]" > /dev/null

# Attaches a policy to the role
WP_SSM_POLICY_NAME="ReadSSMParametersPolicy"
aws iam put-role-policy \
    --role-name "$WP_SSM_ROLE_NAME" \
    --policy-name "$WP_SSM_POLICY_NAME" \
    --policy-document "file://$(dirname "$0")/ssm_read_policy.json" > /dev/null

WP_SSM_INSTANCE_PROFILE_NAME="read-ssm-parameters-profile"
aws iam create-instance-profile --instance-profile-name "$WP_SSM_INSTANCE_PROFILE_NAME" \
    --tags "[{\"Key\":\"Name\",\"Value\":\"$WP_SSM_INSTANCE_PROFILE_NAME\"},$TAGS]" > /dev/null

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
    --type "SecureString" \
    --tags "[$TAGS]" > /dev/null

aws ssm put-parameter \
    --name "/wp/db-name" \
    --value "$WP_RDS_MYSQL_DBNAME" \
    --type "SecureString" \
    --tags "[$TAGS]" > /dev/null

aws ssm put-parameter \
    --name "/wp/db-user" \
    --value "$WP_RDS_MYSQL_ADMIN_USER" \
    --type "SecureString" \
    --tags "[$TAGS]" > /dev/null

aws ssm put-parameter \
    --name "/wp/db-password" \
    --value "$WP_RDS_MYSQL_ADMIN_PASSWD" \
    --type "SecureString" \
    --tags "[$TAGS]" > /dev/null

echo "SSM WordPress parameters created"