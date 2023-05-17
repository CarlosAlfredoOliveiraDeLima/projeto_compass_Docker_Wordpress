#!/bin/bash

set -e
export AWS_DEFAULT_OUTPUT="text"
export AWS_REGION="us-east-1"

function delete_stack {
    aws cloudformation delete-stack --stack-name "$1" > /dev/null
    stacks="$(aws cloudformation describe-stacks --query 'Stacks[].StackName')"
    while [[ "$stacks" == *"$1"* ]]; do
        stack_status="$(aws cloudformation describe-stacks --stack-name "$1" --query 'Stacks[0].StackStatus')"
        case $stack_status in
            "DELETE_FAILED") echo "$1 stack deletion failed"; exit 1;;
            *) sleep 15;;
        esac
        stacks="$(aws cloudformation describe-stacks --query 'Stacks[].StackName')"
    done
    echo "$1 stack deleted successfully"
}

for stack in "$@"; do
    if [ -n "$(aws cloudformation describe-stacks --stack-name "$stack" --query 'Stacks[].StackName')" ]; then
        delete_stack "$stack"
    fi
done