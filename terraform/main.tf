data "aws_caller_identity" "identity" {}

terraform {
  backend "s3" {
    bucket = "${var.project_name}-${var.environment}-tfstate"
    key    = "${var.project_name}.tfstate"
    region = var.aws_region
    dynamodb_table = "${var.environment}.tfstate"
  }
}
module "backend" {
  source = "github.com/codeforamerica/tofu-modules-aws-backend?ref=1.1.1"

  project     = var.project_name
  environment = var.environment
}

module "secrets" {
  source = "github.com/codeforamerica/tofu-modules-aws-secrets?ref=1.0.0"

  project     = var.project_name
  environment = var.environment

  secrets = {
    database = {
      description = "Credentials for our Database."
      name = "/asap-pdf/production/database"
      start_value = jsonencode({
        host = ""
        name = ""
        username = ""
        password = ""
      })
    }
    redis = {
      description = "The Redis/Elasticache url."
      name = "/asap-pdf/production/redis"
      start_value = jsonencode({
        url = ""
      })
    }
    rails = {
      description = "The Rails master key."
      name = "/asap-pdf/production/rails"
      start_value = jsonencode({
        master_key = ""
        secret_key = ""
      })
    }
    google = {
      description = "The Rails master key."
      name = "/asap-pdf/production/GOOGLE_AI_KEY"
    }
    anthropic = {
      description = "The Rails master key."
      name = "/asap-pdf/production/ANTHROPIC_KEY"
    }
  }
}

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
  availability_zones = ["us-east-1a", "us-east-1b"]
  logging_key_id       = module.logging.kms_key_arn
}

# Database
module "database" {
  source = "./modules/database"

  project_name      = var.project_name
  environment       = var.environment
  subnet_ids        = module.networking.private_subnet_ids
  security_group_id = module.networking.rds_security_group_id
}

# Redis for Sidekiq
module "cache" {
  source = "./modules/cache"

  project_name      = var.project_name
  environment       = var.environment
  subnet_ids        = module.networking.private_subnet_ids
  security_group_id = module.networking.redis_security_group_id
}

# Deployment resources (ECR, GitHub Actions, Secrets)
module "deployment" {
  source = "./modules/deployment"

  project_name      = var.project_name
  environment       = var.environment

  db_password_secret_arn = "${module.secrets.secrets["database"].secret_arn}:password"
  aws_account_id         = data.aws_caller_identity.identity.account_id
  backend_kms_arn        = module.backend.kms_key
  document_inference_lambda_arn            = module.lambda.document_inference_lambda_arn
  document_inference_evaluation_lambda_arn = module.lambda.document_inference_evaluation_lambda_arn
  evaluation_lambda_arn                    = module.lambda.evaluation_lambda_arn
}

# ECS
module "ecs" {
  source = "./modules/ecs"

  project_name      = var.project_name
  environment       = var.environment
  # @todo are these automatic? Do we need them?
  # security_group_id = module.networking.ecs_security_group_id
  # container_image   = "${module.deployment.ecr_repository_url}:latest"
  # container_port    = var.container_port
  # container_cpu     = var.container_cpu
  # container_memory  = var.container_memory

  db_host_secret_arn          = "${module.secrets.secrets["database"].secret_arn}:host"
  db_name_secret_arn          = "${module.secrets.secrets["database"].secret_arn}:name"
  db_username_secret_arn      = "${module.secrets.secrets["database"].secret_arn}:username"
  db_password_secret_arn      = "${module.secrets.secrets["database"].secret_arn}:password"
  secret_key_base_secret_arn  = "${module.secrets.secrets["rails"].secret_arn}:secret_key"
  rails_master_key_secret_arn = "${module.secrets.secrets["rails"].secret_arn}:master_key"
  redis_url_secret_arn        = "${module.secrets.secrets["redis"].secret_arn}:url"
  #target_group_arn            = module.networking.alb_target_group_arn

  vpc_id          = module.networking.vpc_id
  private_subnets = module.networking.private_subnet_ids
  public_subnets  = module.networking.public_subnet_ids
  logging_key_id  = module.logging.kms_key_arn
  domain_name     = var.domain_name
  aws_s3_bucket_arn   = aws_s3_bucket.documents.arn
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
  secret_google_ai_key_arn                         = module.secrets.secrets["google"].secret_arn
  secret_anthropic_key_arn                         = module.secrets.secrets["anthropic"].secret_arn
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



# IAM policy for ECS tasks to access Secrets Manager
# resource "aws_iam_role_policy" "ecs_secrets_access" {
#   name = "${var.project_name}-${var.environment}-ecs-secrets-access"
#   role = split("/", module.ecs.task_execution_role_arn)[1]
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = "secretsmanager:GetSecretValue"
#         Resource = [
#           module.deployment.db_host_secret_arn,
#           module.deployment.db_name_secret_arn,
#           module.deployment.db_username_secret_arn,
#           module.deployment.db_password_secret_arn,
#           module.deployment.secret_key_base_secret_arn,
#           module.deployment.rails_master_key_secret_arn,
#           module.deployment.redis_url_secret_arn
#         ]
#       }
#     ]
#   })
# }
