#!/bin/bash

# Required Environment Variables:
#   PUB_SUBNET_1
#   BASTION_SG_ID

set -e

export AWS_REGION=us-east-1
export AWS_DEFAULT_OUTPUT="text"

# Creates a key pair to be used with the bastion host and other project-related instances
BASTION_KEY_NAME="wordpress-task-key"
aws ec2 create-key-pair \
    --key-name "$BASTION_KEY_NAME" \
    --key-type rsa \
    --key-format pem \
    --query "KeyMaterial" \
    --output text > "$BASTION_KEY_NAME.pem"
chmod 400 "$BASTION_KEY_NAME.pem"
echo "Bastion Host Key Pair created"

TAGS='[{Key=Name, Value=Bastion Host}, {Key=Project, Value=PB UNIVESP URI}, {Key=CostCenter, Value=C092000004}]'
BASTION_ID=$(aws ec2 run-instances \
    --count=1 \
    --image-id ami-06a0cd9728546d178 \
    --instance-type t3.small \
    --key-name "$BASTION_KEY_NAME" \
    --subnet-id "$PUB_SUBNET_1" \
    --security-group-ids "$BASTION_SG_ID" \
    --tag-specifications "ResourceType=instance,Tags=$TAGS" \
                         "ResourceType=volume,Tags=$TAGS" \
    --query 'Instances[0].InstanceId')

# Waits for the instance to be running
while [[ $(aws ec2 describe-instances --instance-ids "$BASTION_ID" --query 'Reservations[0].Instances[0].State.Name') != "running" ]]
do
sleep 15
done
echo "Bastion Host <$BASTION_ID> created and running"

# Allocates an Elastic IP for the Bastion Host
BASTION_EIP_ID=$(aws ec2 allocate-address --query='AllocationId'  --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=wordpress-task-bastion-eip}]')
aws ec2 associate-address --allocation-id "$BASTION_EIP_ID" --instance-id "$BASTION_ID" > /dev/null
echo "Bastion Host Public IP: $(aws ec2 describe-instances --instance-ids "$BASTION_ID" --query 'Reservations[0].Instances[0].PublicIpAddress')"


