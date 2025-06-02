# Deployment Guide

This section is a work in progress. This application is deployed to AWS ECS using GitHub Actions. To create a copy of
ASAP begin by forking the repository.

## Prerequisites

1. **Terraform Configuration**
    - If desired, Update main [variables.tf](../terraform/variables.tf) with "project_name", "environment" and "
      domain_name" default values. A domain is required to run the application. For lowest friction, it should be
      managed via AWS Route53.
    - Ensure AWS CLI is installed with an active session.

2. **Infrastructure Deployment**
    - Run Terraform to set up:
        - ECR repository
        - ECS cluster and service
        - GitHub Actions OIDC provider and role
        -
        - AWS Secrets Manager secrets
      ```bash
      tofu init
      tofu plan
      tofu apply
      ```

3. **Update deploy.yml and .aws/task-definition.json**

- Update the environmental variables at the top of [deploy.yml](../.github/workflows/deploy.yml) to match your project
  details and AWS account.
- After ECS cluster and service are running, update [task-definition.json](../.aws/task-definition.json) via
  `aws ecs describe-task-definition --task-definition <your task name>`.

4. **Manually set Secrets**

- The OpenTofu scripts should have created AWS secrets for database credentials, the Rails master key and LLM API
  credentials. To prevent leaking credentials, secret values are not provided via code and must be entered manually.
  Only active LLM services require values set in their secret.

5. **Verify Domain for SSL Certificate**

- Within the AWS web UI, navigate to the AWS Certificate Manager service. The terraform scripts should have created a
  pending certificate. Perform CNAME or other domain validation steps as suggested by the UI.

You are now ready to run your first deployment. NB: Images will not be built and pushed to their respective ECR
repositories until a deployment is made.

## Deployment Process

1. **Manual Deployment**
    - Push changes to the `main` branch
    - GitHub Actions will automatically:
        - Build the Docker images
        - Push to ECR
        - Update ECS task definition
        - Update SSM parameter for Rails app image
        - Deploy to ECS service

2. **Monitoring Deployments**
    - Check GitHub Actions tab for deployment status
    - Monitor ECS service events in AWS Console
    - View application logs in CloudWatch

## Health Checks

The application uses Rails' built-in health check endpoint at `/up` for container health monitoring. This endpoint is
provided by Rails and automatically checks the application's basic functionality, including database connectivity.

The ECS task definition includes a health check configuration that:

- Calls the `/up` endpoint every 30 seconds
- Times out after 5 seconds
- Retries 3 times before marking unhealthy
- Allows 60 seconds startup time for initial health check

## Infrastructure

Given project_name "asap-pdf" and environment "production".

- **ECS Service**: `asap-pdf-production-service`
- **Task Definition**: Located in `.aws/task-definition.json`
- **Container**: Runs on port 80
- **Logs**: Available in CloudWatch group `/ecs/asap-pdf-production`

## Rollback Process

To rollback to a previous version:

1. Find the desired task definition revision in AWS Console
2. Update the ECS service to use that revision:
   ```bash
   aws ecs update-service \
     --cluster asap-pdf-production \
     --service asap-pdf-production-service \
     --task-definition asap-pdf-production:<REVISION_NUMBER>
   ```

## Common Issues

1. **Health Check Failures**
    - Verify the application is binding to port 80
    - Check CloudWatch logs for application errors
    - Ensure database migrations have run successfully

2. **Memory Issues**
    - Monitor CloudWatch metrics
    - Consider adjusting task definition memory limits if needed

3. **Database Connection Issues**
    - Verify security group settings
    - Check DATABASE_URL secret in AWS Secrets Manager
    - Ensure RDS instance is running and accessible
