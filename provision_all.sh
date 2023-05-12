#!/bin/bash

# Provision VPC resources
source $(dirname "$0")/provision_vpc.sh

# Provision security groups
source $(dirname "$0")/provision_security_groups.sh

# Provision EFS resources
source $(dirname "$0")/provision_efs.sh

# Provision RDS resources
source $(dirname "$0")/provision_rds.sh