#!/bin/bash

# Provision VPC resources
source "$(dirname "$0")/provision_vpc.sh"

# Provision security groups
source "$(dirname "$0")/provision_security_groups.sh"

# Provision EFS resources
source "$(dirname "$0")/provision_efs.sh"

# Provision RDS resources
source "$(dirname "$0")/provision_rds.sh"

# Provision Bastion Host
source "$(dirname "$0")/provision_bastion.sh"

# Provision SSM
source "$(dirname "$0")/provision_ssm.sh"

# Provision ALB
source "$(dirname "$0")/provision_alb.sh"

# Provision ASG
source "$(dirname "$0")/provision_asg.sh"