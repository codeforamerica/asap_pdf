# ASAP PDF Infrastructure

This directory contains the OpenTofu configuration for deploying the ASAP PDF application infrastructure to AWS.

## Architecture

The infrastructure consists of:

- VPC with public and private subnets
- RDS PostgreSQL database in private subnet
- Redis cluster for Sidekiq in private subnet
- ECS cluster with EC2 instances in public subnet
- S3 bucket for PDF storage with versioning enabled
- Lambda for running Python components

## Prerequisites

1. AWS CLI configured with appropriate credentials. Example: `aws configure --profile cfa-ai-studio`
2. OpenTofu installed (v1.0.0 or later)
3. Docker image built and pushed to a container registry

## Initial Setup

1. Create the S3 bucket for state storage:
```bash
chmod +x setup-state-bucket.sh
./setup-state-bucket.sh
```

## Usage

1. Initialize OpenTofu with the S3 backend:
```bash
tofu init
```

2. Create a `terraform.tfvars` file with your specific values:
```hcl
project_name = "asap-pdf"
environment  = "production"

# Optional overrides
db_instance_class = "db.t3.small"
redis_node_type   = "cache.t3.micro"
container_image   = "your-registry/asap-pdf:latest"
aws_account_id    = "Your AWS Account #"
```

NB: If adding `aws_account_id` to prevent OpenTofu prompting for account, make sure to wrap in quotes to include all characters.

3. Review the execution plan:
```bash
tofu plan
```

4. Apply the configuration:
```bash
tofu apply
```

Note: Initial deployment can take 10-15 minutes, primarily due to:
- RDS instance creation (~5-7 minutes)
- ElastiCache cluster creation (~5-7 minutes)
- ECS cluster setup (~3-5 minutes)

## Important Notes

1. The database password is stored in AWS Secrets Manager
2. S3 bucket has versioning enabled for PDF version history
3. ECS instances are placed in a public subnet but RDS and Redis are in private subnets
4. CloudWatch logs are enabled for container logs

## Outputs

After applying, you'll get several important outputs:

- Database connection URL
- Redis connection URL
- ECS cluster and service names
- S3 bucket name
- CloudWatch log group name

Use these outputs to configure your application environment variables.

## Scaling

- The ECS cluster can scale between 1 and 2 instances by default
- Modify `ecs_min_size` and `ecs_max_size` variables to adjust scaling limits
- RDS and Redis can be scaled by modifying their respective instance class variables

## Security

- All sensitive data is stored in AWS Secrets Manager
- Private subnets are used for databases
- Security groups restrict access appropriately
- S3 bucket has server-side encryption enabled

## Cleanup

To destroy the infrastructure:

1. First, remove any application data you want to keep:
   - Download any important PDFs from the S3 bucket
   - Export any necessary database data

2. Then destroy the resources in this order:
```bash
# First destroy the ECS service to prevent new tasks
tofu destroy -target=module.ecs.aws_ecs_service.app

# Then destroy the rest of the infrastructure
tofu destroy
```

**Warning**:
- This will delete all resources including the database and S3 bucket
- Make sure to backup any important data first
- If you encounter any issues during destroy:
  1. Try destroying problematic resources individually using `-target`
  2. Check the AWS Console for any manually created resources
  3. Ensure all ECS tasks are stopped before destroying ECS resources
