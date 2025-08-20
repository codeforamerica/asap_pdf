data "aws_caller_identity" "identity" {}

module "secrets" {
  source = "github.com/codeforamerica/tofu-modules-aws-secrets?ref=2.0.0"

  project     = var.project_name
  environment = var.environment
  add_suffix  = false

  secrets = {
    # Database credentials - flattened
    database_host = {
      description = "Database host"
      name        = "/asap-pdf/database/host"
      start_value = ""
    }
    database_name = {
      description = "Database name"
      name        = "/asap-pdf/database/name"
      start_value = ""
    }
    database_username = {
      description = "Database username"
      name        = "/asap-pdf/database/username"
      start_value = ""
    }
    database_password = {
      description = "Database password"
      name        = "/asap-pdf/database/password"
      start_value = ""
    }

    # Redis credentials - flattened
    rails_master_key = {
      description = "Rails master key"
      name        = "/asap-pdf/rails/master_key"
      start_value = ""
    }
    rails_secret_key = {
      description = "Rails secret key"
      name        = "/asap-pdf/rails/secret_key"
      start_value = ""
    }
    redis_url = {
      description = "Redis/Elasticache URL"
      name        = "/asap-pdf/redis/url"
      start_value = ""
    }

    # SMTP credentials - flattened
    smtp_endpoint = {
      description = "SMTP endpoint"
      name        = "/asap-pdf/smtp/endpoint"
      start_value = ""
    }
    smtp_user = {
      description = "SMTP user"
      name        = "/asap-pdf/smtp/user"
      start_value = ""
    }
    smtp_password = {
      description = "SMTP password"
      name        = "/asap-pdf/smtp/password"
      start_value = ""
    }

    # Google Analytics - flattened
    google_analytics_key = {
      description = "Google Analytics key"
      name        = "/asap-pdf/google_analytics/key"
      start_value = ""
    }

    # Single-value secrets (already flat)
    google_api_key = {
      description = "Optional Google API key"
      name        = "/asap-pdf/GOOGLE_AI_KEY"
      start_value = ""
    }
    anthropic_api_key = {
      description = "Optional Anthropic API key"
      name        = "/asap-pdf/ANTHROPIC_KEY"
      start_value = ""
    }
    rails_api_user = {
      description = "The Rails API user to pass to our python components"
      name        = "/asap-pdf/RAILS_API_USER"
      start_value = ""
    }
    rails_api_password = {
      description = "The Rails API password to pass to our python components"
      name        = "/asap-pdf/RAILS_API_PASSWORD"
      start_value = ""
    }
    google_service_account = {
      description = "Service account credentials for evaluation tasks only"
      name        = "/asap-pdf/GOOGLE_SERVICE_ACCOUNT"
      start_value = ""
    }
    google_sheet_id_evaluation = {
      description = "The Google sheet id for evaluation tasks only"
      name        = "/asap-pdf/GOOGLE_SHEET_ID_EVALUATION"
      start_value = ""
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
  source = "../networking"

  project_name         = var.project_name
  environment          = var.environment
  availability_zones = ["us-east-1a", "us-east-1b"]
  logging_key_id       = module.logging.kms_key_arn
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
}

# Database
module "database" {
  source = "../database"

  project_name      = var.project_name
  environment       = var.environment
  subnet_ids        = module.networking.private_subnet_ids
  security_group_id = module.networking.rds_security_group_id
  multi_az          = var.rds_multi_az
}

# Redis for Sidekiq
module "cache" {
  source = "../cache"

  project_name      = var.project_name
  environment       = var.environment
  subnet_ids        = module.networking.private_subnet_ids
  security_group_id = module.networking.redis_security_group_id
}

# Deployment resources (ECR, GitHub Actions, Secrets)
module "deployment" {
  source = "../deployment"

  project_name = var.project_name
  environment  = var.environment

  aws_account_id                           = data.aws_caller_identity.identity.account_id
  backend_kms_arn                          = var.backend_kms_key
  document_inference_lambda_arn            = module.lambda.document_inference_lambda_arn
  document_inference_evaluation_lambda_arn = module.lambda.document_inference_evaluation_lambda_arn
  evaluation_lambda_arn                    = module.lambda.evaluation_lambda_arn
  github_branch                            = var.github_branch
  github_environment                       = var.github_environment
}

# ECS
module "ecs" {
  source = "../ecs"

  project_name      = var.project_name
  environment       = var.environment
  rails_environment = var.rails_environment

  db_host_secret_arn          = module.secrets.secrets["database_host"].secret_arn
  db_name_secret_arn          = module.secrets.secrets["database_name"].secret_arn
  db_username_secret_arn      = module.secrets.secrets["database_username"].secret_arn
  db_password_secret_arn      = module.secrets.secrets["database_password"].secret_arn
  secret_key_base_secret_arn  = module.secrets.secrets["rails_secret_key"].secret_arn
  rails_master_key_secret_arn = module.secrets.secrets["rails_master_key"].secret_arn
  smtp_endpoint_secret_arn    = module.secrets.secrets["smtp_endpoint"].secret_arn
  smtp_user_secret_arn        = module.secrets.secrets["smtp_user"].secret_arn
  smtp_password_secret_arn    = module.secrets.secrets["smtp_password"].secret_arn
  redis_url_secret_arn        = module.secrets.secrets["redis_url"].secret_arn
  google_analytics_key_arn    = module.secrets.secrets["google_analytics_key"].secret_arn

  vpc_id            = module.networking.vpc_id
  private_subnets   = module.networking.private_subnet_ids
  public_subnets    = module.networking.public_subnet_ids
  logging_key_id    = module.logging.kms_key_arn
  domain_name       = var.domain_name
  aws_s3_bucket_arn = aws_s3_bucket.documents.arn
}

# LAMBDA
module "lambda" {
  source = "../lambda"

  project_name                                     = var.project_name
  environment                                      = var.environment
  subnet_ids                                       = module.networking.private_subnet_ids
  security_group_id                                = module.networking.lambda_security_group_id
  document_inference_ecr_repository_url            = module.deployment.document_inference_ecr_repository_url
  evaluation_ecr_repository_url                    = module.deployment.evaluation_ecr_repository_url
  document_inference_evaluation_ecr_repository_url = module.deployment.document_inference_evaluation_ecr_repository_url
  secret_google_ai_key_arn                         = module.secrets.secrets["google_api_key"].secret_arn
  secret_anthropic_key_arn                         = module.secrets.secrets["anthropic_api_key"].secret_arn
  secret_rails_api_user                            = module.secrets.secrets["rails_api_user"].secret_arn
  secret_rails_api_password                        = module.secrets.secrets["rails_api_password"].secret_arn
  secret_google_service_account_evals_key_arn      = module.secrets.secrets["google_service_account"].secret_arn
  secret_google_sheet_id_evals_key_arn             = module.secrets.secrets["google_sheet_id_evaluation"].secret_arn
  s3_document_bucket_arn                           = aws_s3_bucket.documents.arn
}

module "ses" {
  source = "../ses"

  project_name = var.project_name
  environment  = var.environment
  domain_name  = var.domain_name
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