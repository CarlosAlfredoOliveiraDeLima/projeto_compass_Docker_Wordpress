#!/bin/bash

set -e
export AWS_DEFAULT_OUTPUT="text"
export TAGS="{Key=Project,Value=PB UNIVESP URI},{Key=CostCenter,Value=C092000004}"
export AWS_REGION="us-east-1"

## Key pair

KEY_NAME="wordpress-task-key"
if aws ec2 describe-key-pairs  --key-names "$KEY_NAME" --output=text --query 'KeyPairs[].KeyPairId' &> /dev/null; then
    key_id=$(aws ec2 describe-key-pairs  --key-names "$KEY_NAME" --output=text --query 'KeyPairs[].KeyPairId')
    aws ec2 delete-key-pair --key-pair-id "$key_id" > /dev/null
    echo "Key pair deleted successfully"
fi

key_uuid=$(uuidgen | head -c 6)
aws ec2 create-key-pair \
    --key-name "$KEY_NAME" \
    --key-type rsa \
    --key-format pem \
    --query "KeyMaterial" \
    --tag-specifications "ResourceType=key-pair,Tags=[{Key=Name,Value=$KEY_NAME},$TAGS]" \
    --output text > "$KEY_NAME-$key_uuid.pem"
chmod 400 "$KEY_NAME-$key_uuid.pem"
echo "Key pair created successfully"

## Network Stack

NETWORK_STACK_NAME="wptask-network"
NETWORK_STACK_PARAMETERS=(
    "ParameterKey=AvailabilityZones,ParameterValue='${AWS_REGION}a,${AWS_REGION}b'"
    "ParameterKey=SecurityGroupIngressCIDR,ParameterValue='$(curl ifconfig.me 2> /dev/null)/32'"
    "ParameterKey=ApplicationPort,ParameterValue='8080'"
)

aws cloudformation create-stack --stack-name "$NETWORK_STACK_NAME" \
    --template-body "file://$(dirname "$0")/network.yaml" \
    --parameters "${NETWORK_STACK_PARAMETERS[@]}" > /dev/null

stack_status="$(aws cloudformation describe-stacks --stack-name $NETWORK_STACK_NAME --query 'Stacks[0].StackStatus')"
while [[ "$stack_status" != "CREATE_COMPLETE" ]]; do
    case $stack_status in
        "CREATE_FAILED"|"ROLLBACK*") echo "Network stack creation failed"; exit 1;;
        *) sleep 15;;
    esac
    stack_status="$(aws cloudformation describe-stacks --stack-name $NETWORK_STACK_NAME --query 'Stacks[0].StackStatus')"
done
echo "Network stack created successfully"

## Data stack

DATA_STACK_NAME="wptask-data"
DATA_STACK_PARAMETERS=(
    "ParameterKey=NetworkStackName,ParameterValue='$NETWORK_STACK_NAME'"
    "ParameterKey=RDSInstanceSize,ParameterValue='db.t3.micro'"
    "ParameterKey=RDSEngineVersion,ParameterValue='8.0.32'"
    "ParameterKey=ApplicationDBName,ParameterValue='wordpress'"
    "ParameterKey=ApplicationDBUser,ParameterValue='wordpress'"
    "ParameterKey=ApplicationDBPassword,ParameterValue='$(gpg --gen-random --armor 1 21 | tail -1 | head -c 20 | sed 's![@/]!!g')'"
)

aws cloudformation create-stack --stack-name "$DATA_STACK_NAME" \
    --template-body "file://$(dirname "$0")/data.yaml" \
    --parameters "${DATA_STACK_PARAMETERS[@]}" > /dev/null

stack_status="$(aws cloudformation describe-stacks --stack-name $DATA_STACK_NAME --query 'Stacks[0].StackStatus')"
while [[ "$stack_status" != "CREATE_COMPLETE" ]]; do
    case $stack_status in
        "CREATE_FAILED"|"ROLLBACK*") echo "Data stack creation failed"; exit 1;;
        *) sleep 15;;
    esac
    stack_status="$(aws cloudformation describe-stacks --stack-name $DATA_STACK_NAME --query 'Stacks[0].StackStatus')"
done
echo "Data stack created successfully"

## Application Stack

APPLICATION_STACK_NAME="wptask-app"
APPLICATION_STACK_PARAMETERS=(
    "ParameterKey=NetworkStackName,ParameterValue='$NETWORK_STACK_NAME'"
    "ParameterKey=DataStackName,ParameterValue='$DATA_STACK_NAME'"
    "ParameterKey=SSHKey,ParameterValue='$KEY_NAME'"
    "ParameterKey=InstanceSize,ParameterValue='t2.micro'"
)

aws cloudformation create-stack --stack-name "$APPLICATION_STACK_NAME" \
    --template-body "file://$(dirname "$0")/app.yaml" \
    --parameters "${APPLICATION_STACK_PARAMETERS[@]}" > /dev/null

stack_status="$(aws cloudformation describe-stacks --stack-name $APPLICATION_STACK_NAME --query 'Stacks[0].StackStatus')"
while [[ "$stack_status" != "CREATE_COMPLETE" ]]; do
    case $stack_status in
        "CREATE_FAILED"|"ROLLBACK*") echo "Application stack creation failed"; exit 1;;
        *) sleep 15;;
    esac
    stack_status="$(aws cloudformation describe-stacks --stack-name $APPLICATION_STACK_NAME --query 'Stacks[0].StackStatus')"
done
echo "Application stack created successfully"

aws cloudformation describe-stacks --stack-name $APPLICATION_STACK_NAME --query 'Stacks[0].Outputs' --output=table


