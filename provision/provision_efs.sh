#!/bin/bash

# Required Environment Variables:
#   WP_VPC_ID
#   WP_EFS_SG_ID
#   WP_PRIV_SUBNET_1
#   WP_PRIV_SUBNET_2

set -e

export AWS_REGION=us-east-1
export AWS_DEFAULT_OUTPUT="text"
export TAGS='{"Key":"Task","Value":"Docker-WordPress"},{"Key":"Project","Value":"PB UNIVESP URI"},{"Key":"CostCenter","Value":"C092000004"}'

# Creates an EFS file system
WP_EFS_NAME="wordpress-task-efs-fs"
WP_EFS_ID=$(aws efs create-file-system --performance-mode generalPurpose --throughput-mode bursting --encrypted \
        --tags "[{\"Key\":\"Name\",\"Value\":\"$WP_EFS_NAME\"},$TAGS]"  \
        --query 'FileSystemId')
while [[ $(aws efs describe-file-systems --file-system-id "$WP_EFS_ID" --query 'FileSystems[0].LifeCycleState') != "available" ]]
do
sleep 10
done
echo "EFS File System <$WP_EFS_ID> created"

# Creates mount targets on EFS FS
WP_MOUNT_TARGET_ID_1=$(aws efs create-mount-target \
    --file-system-id "$WP_EFS_ID" \
    --subnet-id "$WP_PRIV_SUBNET_1" \
    --security-groups "$WP_EFS_SG_ID" \
    --query 'MountTargetId')
while [[ $(aws efs describe-mount-targets --mount-target-id "$WP_MOUNT_TARGET_ID_1" --query 'MountTargets[0].LifeCycleState') != "available" ]]
do
sleep 10
done
echo "Mount target on private subnet 1 <$WP_PRIV_SUBNET_1> created"

WP_MOUNT_TARGET_ID_2=$(aws efs create-mount-target \
    --file-system-id "$WP_EFS_ID" \
    --subnet-id "$WP_PRIV_SUBNET_2" \
    --security-groups "$WP_EFS_SG_ID" \
    --query 'MountTargetId')
while [[ $(aws efs describe-mount-targets --mount-target-id "$WP_MOUNT_TARGET_ID_2" --query 'MountTargets[0].LifeCycleState') != "available" ]]
do
sleep 10
done
echo "Mount target on private subnet 2 <$WP_PRIV_SUBNET_2> created"

WP_EFS_DNS="$WP_EFS_ID.efs.$AWS_REGION.amazonaws.com"
echo "EFS DNS: $WP_EFS_DNS"