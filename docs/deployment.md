# Simple Deployment Guide

This app deploys to AWS using automated GitHub Actions. Choose either staging or production environment.

## What You Need
- AWS account
- Domain name 

## Setup Steps

### 1. Install Tools
- Install [OpenTofu](https://opentofu.org/docs/intro/install/)
- Optionally install [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

### 2. Choose Your Environment
Navigate to either:
- `terraform/config/staging` (for testing)
- `terraform/config/production` (for live app)

### 3. Configure AWS Settings
1. Run `tofu init` to set up the directory
2. Edit `main.tf` with your AWS details
3. Optionally edit `variables.tf` for custom settings

### 4. Deploy Infrastructure
1. **First deployment**: Comment out the `asap_pdf` module in `main.tf`
2. Run `tofu plan` then `tofu apply` to create basic AWS resources
3. Run `tofu state migrate` to move settings to AWS
4. **Second deployment**: Uncomment the `asap_pdf` module
5. Run `tofu plan` then `tofu apply` again to create remaining resources

**Note**: This step can take a while, especially for database setup. If it hangs on certificate validation, check that DNS records were created in Route53.

### 5. Build Images
After infrastructure is ready, container images need to be built and uploaded to AWS (done manually or through GitHub Actions).

## GitHub Actions Deployment

After setting up your AWS infrastructure, you can deploy automatically using GitHub Actions.

### Triggering Deployments
Deployments can be triggered by:
- **Automatic**: Merging into `dev` (staging) or `main` (production) branches
- **Manual**: Using GitHub's workflow_dispatch feature

### Required Environment Variables
Set these variables in your GitHub repository settings for each environment:

| Name | Description | Example |
|------|-------------|---------|
| AWS_ACCOUNT_ID | Your AWS account ID | 073165201938 |
| AWS_REGION | AWS region for deployment | us-east-1 |
| AWS_ROLE_ARN | ARN of your GitHub AWS IAM role | arn:aws:iam::123456789:role/github-actions |
| ECR_REPOSITORY_LAMBDA_DOCUMENT_INFERENCE | ECR repo for document inference Lambda | asap-pdf-lambda-document-inference-staging |
| ECR_REPOSITORY_RAILS_APP | ECR repo for the Rails application | asap-pdf-staging-app |
| ECS_CLUSTER | ECS cluster name | asap-pdf-staging-app |
| ECS_SERVICE | ECS service name | asap-pdf-staging-app |
| FUNCTION_NAME_LAMBDA_DOCUMENT_INFERENCE | Document inference Lambda function name | asap-pdf-document-inference-staging |

### Additional LLM-evaluation-related Variables (Staging Only)

| Name | Description | Example |
|------|-------------|---------|
| ECR_REPOSITORY_LAMBDA_EVAL | ECR repo for evaluation Lambda | asap-pdf-evaluation-staging |
| ECR_REPOSITORY_LAMBDA_EVAL_DOCUMENT_INFERENCE | ECR repo for eval document inference | asap-pdf-document-inference-evaluation-staging |
| FUNCTION_NAME_LAMBDA_EVAL | Evaluation Lambda function name | asap-pdf-evaluation-staging |
| FUNCTION_NAME_LAMBDA_EVAL_DOCUMENT_INFERENCE | Eval document inference Lambda name | asap-pdf-document-inference-evaluation-staging |

### What Happens During Deployment
Each successful deployment automatically:
- Builds and pushes Rails app and Python Lambda components to ECR
- Updates ECS task definitions and SSM version parameters
- Updates Lambda function configurations

## Important Notes
- Staging and production use separate AWS accounts for complete isolation
- Production environment has higher availability features
- Route53 domain management simplifies the setup process