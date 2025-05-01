module "logging" {
  source = "github.com/codeforamerica/tofu-modules-aws-logging?ref=2.1.0"

  project     = var.project_name
  environment = var.environment
}

# Networking
module "networking" {
  source = "./modules/networking"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  logging_key_id       = module.logging.kms_key_arn
}

# Database
module "database" {
  source = "./modules/database"

  project_name      = var.project_name
  environment       = var.environment
  subnet_ids        = module.networking.private_subnet_ids
  security_group_id = module.networking.rds_security_group_id
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  db_name           = var.db_name
  db_username       = var.db_username
}

# Redis for Sidekiq
module "cache" {
  source = "./modules/cache"

  project_name      = var.project_name
  environment       = var.environment
  subnet_ids        = module.networking.private_subnet_ids
  security_group_id = module.networking.redis_security_group_id
  node_type         = var.redis_node_type
  port              = var.redis_port
}

# Deployment resources (ECR, GitHub Actions, Secrets)
module "deployment" {
  source = "./modules/deployment"

  project_name      = var.project_name
  environment       = var.environment
  github_repository = var.github_repository

  db_username            = var.db_username
  db_password_secret_arn = module.database.db_password_secret_arn
  db_endpoint            = module.database.db_instance_endpoint
  db_name                = var.db_name
  rails_master_key       = var.rails_master_key
  aws_account_id         = var.aws_account_id
  redis_url = format("redis://%s:%s",
    module.cache.redis_endpoint,
    module.cache.redis_port
  )
  secret_key_base                          = var.secret_key_base
  google_ai_key                            = var.google_ai_key
  anthropic_key                            = var.anthropic_key
  document_inference_lambda_arn            = module.lambda.document_inference_lambda_arn
  document_inference_evaluation_lambda_arn = module.lambda.document_inference_evaluation_lambda_arn
  evaluation_lambda_arn                    = module.lambda.evaluation_lambda_arn
}

# ECS
module "ecs" {
  source = "./modules/ecs"

  project_name      = var.project_name
  environment       = var.environment
  subnet_ids        = module.networking.private_subnet_ids
  security_group_id = module.networking.ecs_security_group_id
  container_image   = "${module.deployment.ecr_repository_url}:latest"
  container_port    = var.container_port
  container_cpu     = var.container_cpu
  container_memory  = var.container_memory

  db_host_secret_arn          = module.deployment.db_host_secret_arn
  db_name_secret_arn          = module.deployment.db_name_secret_arn
  db_username_secret_arn      = module.deployment.db_username_secret_arn
  db_password_secret_arn      = module.deployment.db_password_secret_arn
  secret_key_base_secret_arn  = module.deployment.secret_key_base_secret_arn
  rails_master_key_secret_arn = module.deployment.rails_master_key_secret_arn
  redis_url_secret_arn        = module.deployment.redis_url_secret_arn
  target_group_arn            = module.networking.alb_target_group_arn
}

# LAMBDA
module "lambda" {
  source = "./modules/lambda"

  project_name                                     = var.project_name
  environment                                      = var.environment
  subnet_ids                                       = module.networking.private_subnet_ids
  security_group_id                                = module.networking.lambda_security_group_id
  document_inference_ecr_repository_url            = module.deployment.document_inference_ecr_repository_url
  evaluation_ecr_repository_url                    = module.deployment.evaluation_ecr_repository_url
  document_inference_evaluation_ecr_repository_url = module.deployment.document_inference_evaluation_ecr_repository_url
  secret_google_ai_key_arn                         = module.deployment.gemini_key_secret_arn
  secret_anthropic_key_arn                         = module.deployment.anthropic_key_secret_arn
  s3_document_bucket_arn                           = aws_s3_bucket.documents.arn
}

# S3 bucket for PDF storage
resource "aws_s3_bucket" "documents" {
  bucket = "${var.project_name}-${var.environment}-documents"

  tags = {
    Name        = "${var.project_name}-${var.environment}-documents"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# IAM policy for ECS tasks to access S3
resource "aws_iam_role_policy" "ecs_s3_access" {
  name = "${var.project_name}-${var.environment}-ecs-s3-access"
  role = split("/", module.ecs.task_execution_role_arn)[1]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.documents.arn,
          "${aws_s3_bucket.documents.arn}/*"
        ]
      }
    ]
  })
}

# IAM policy for ECS tasks to access Secrets Manager
resource "aws_iam_role_policy" "ecs_secrets_access" {
  name = "${var.project_name}-${var.environment}-ecs-secrets-access"
  role = split("/", module.ecs.task_execution_role_arn)[1]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "secretsmanager:GetSecretValue"
        Resource = [
          module.deployment.db_host_secret_arn,
          module.deployment.db_name_secret_arn,
          module.deployment.db_username_secret_arn,
          module.deployment.db_password_secret_arn,
          module.deployment.secret_key_base_secret_arn,
          module.deployment.rails_master_key_secret_arn,
          module.deployment.redis_url_secret_arn
        ]
      }
    ]
  })
}
