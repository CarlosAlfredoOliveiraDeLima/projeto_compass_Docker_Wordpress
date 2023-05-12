#!/bin/bash

# Required Environment Variables:
#   VPC_ID
#   EFS_SG_ID
#   PRIV_SUBNET_1
#   PRIV_SUBNET_2

set -e

export AWS_REGION=us-east-1
export AWS_DEFAULT_OUTPUT="text"

# Creates an EFS file system
EFS_ID=$(aws efs create-file-system --performance-mode generalPurpose --throughput-mode bursting --encrypted \
        --tags Key=Name,Value=wordpress-task-efs-fs --query 'FileSystemId')
while [[ $(aws efs describe-file-systems --file-system-id "$EFS_ID" --query 'FileSystems[0].LifeCycleState') != "available" ]]
do
sleep 30
done
echo "EFS File System <$EFS_ID> created"

# Creates mount targets on EFS FS
MOUNT_TARGET_ID_1=$(aws efs create-mount-target \
    --file-system-id "$EFS_ID" \
    --subnet-id "$PRIV_SUBNET_1" \
    --security-groups "$EFS_SG_ID" \
    --query 'MountTargetId')
while [[ $(aws efs describe-mount-targets --mount-target-id "$MOUNT_TARGET_ID_1" --query 'MountTargets[0].LifeCycleState') != "available" ]]
do
sleep 30
done
echo "Mount target on private subnet 1 <$PRIV_SUBNET_1> created"

MOUNT_TARGET_ID_2=$(aws efs create-mount-target \
    --file-system-id "$EFS_ID" \
    --subnet-id "$PRIV_SUBNET_2" \
    --security-groups "$EFS_SG_ID" \
    --query 'MountTargetId')
while [[ $(aws efs describe-mount-targets --mount-target-id "$MOUNT_TARGET_ID_2" --query 'MountTargets[0].LifeCycleState') != "available" ]]
do
sleep 30
done
echo "Mount target on private subnet 1 <$PRIV_SUBNET_2> created"

EFS_DNS="$EFS_ID.efs.$AWS_REGION.amazonaws.com"
echo "EFS DNS: $EFS_DNS"