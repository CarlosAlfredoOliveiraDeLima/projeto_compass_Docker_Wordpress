#!/bin/bash

# Required Environment Variables:
#   VPC_ID
#   ALB_SG_ID
#   PUB_SUBNET_1
#   PUB_SUBNET_2

set -e

export AWS_REGION=us-east-1
export AWS_DEFAULT_OUTPUT="text"
export TAGS='{"Key":"Task","Value":"Docker-WordPress"},{"Key":"Project","Value":"PB UNIVESP URI"},{"Key":"CostCenter","Value":"C092000004"}'

# Creates a target group on port 8080
WP_TG_NAME=wordpress-task-tg
WP_TG_ARN=$(aws elbv2 create-target-group --name "$WP_TG_NAME" --protocol HTTP --port 8080 \
    --vpc-id "$VPC_ID" --ip-address-type ipv4 \
    --target-type instance \
    --health-check-protocol HTTP \
    --health-check-port 8080 \
    --health-check-path "/" \
    --health-check-interval-seconds 15 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 4 \
    --matcher "HttpCode=200-399" \
    --health-check-enabled \
    --tags "[{\"Key\":\"Name\",\"Value\":\"$WP_TG_NAME\"},$TAGS]" \
    --query 'TargetGroups[0].TargetGroupArn')
echo "Target Group <$WP_TG_ARN> created"

# Creates a dualstack Application Load Balancer
WP_ALB_NAME="wordpress-task-alb"
WP_ALB_ARN=$(aws elbv2 create-load-balancer --name "$WP_ALB_NAME"  \
    --subnets "$PUB_SUBNET_1" "$PUB_SUBNET_2" --security-groups "$ALB_SG_ID" \
    --ip-address-type ipv4 \
    --tags "[{\"Key\":\"Name\",\"Value\":\"$WP_ALB_NAME\"},$TAGS]" \
    --query 'LoadBalancers[0].LoadBalancerArn')
while [[ $(aws elbv2 describe-load-balancers --load-balancer-arns "$WP_ALB_ARN" --query 'LoadBalancers[0].State.Code') != "active" ]]
do
sleep 30
done
echo "Application Load Balancer <$WP_ALB_ARN> created"

# Creates a listener on port 80 forwarding to the previously created TG
aws elbv2 create-listener --load-balancer-arn "$WP_ALB_ARN" \
    --protocol HTTP --port 80  \
    --default-actions Type=forward,TargetGroupArn="$WP_TG_ARN" > /dev/null
echo "Listener created on port 80"