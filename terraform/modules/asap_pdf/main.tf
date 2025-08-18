data "aws_caller_identity" "identity" {}

module "secrets" {
  source = "github.com/codeforamerica/tofu-modules-aws-secrets?ref=1.0.0"

  project     = var.project_name
  environment = var.environment

  secrets = {
    database = {
      description = "Credentials for our Database."
      name        = "/asap-pdf/production/database"
      start_value = jsonencode({
        host     = ""
        name     = ""
        username = ""
        password = ""
      })
    }
    redis = {
      description = "The Redis/Elasticache url."
      name        = "/asap-pdf/production/redis"
      start_value = jsonencode({
        url = ""
      })
    }
    rails = {
      description = "The Rails master key."
      name        = "/asap-pdf/production/rails"
      start_value = jsonencode({
        master_key = ""
        secret_key = ""
      })
    }
    smtp = {
      description = "The SMTP credentials."
      name        = "/asap-pdf/production/smtp"
      start_value = jsonencode({
        endpoint = ""
        user     = ""
        password = ""
      })
    }
    google_analytics = {
      description = "Optional Google Analytics key."
      name        = "/asap-pdf/production/GOOGLE_ANALYTICS_KEY"
      start_value = jsonencode({
        key = ""
      })
    }
    google = {
      description = "Optional Google API key."
      name        = "/asap-pdf/production/GOOGLE_AI_KEY"
    }
    anthropic = {
      description = "Optional Anthropic API key."
      name        = "/asap-pdf/production/ANTHROPIC_KEY"
    }
    rails_api_user = {
      description = "The Rails API user to pass to our python components."
      name        = "/asap-pdf/production/RAILS_API_USER"
    }
    rails_api_password = {
      description = "The Rails API password to pass to our python components."
      name        = "/asap-pdf/production/RAILS_API_PASSWORD"
    }
    google_service_account = {
      description = "Service account credentials for evaluation tasks only."
      name        = "/asap-pdf/production/GOOGLE_SERVICE_ACCOUNT"
    },
    google_sheet_id_evaluation = {
      description = "The Google sheet id for evaluation tasks only."
      name        = "/asap-pdf/production/GOOGLE_SHEET_ID_EVALUATION"
    },
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

  project_name   = var.project_name
  environment    = var.environment
  availability_zones = ["us-east-1a", "us-east-1b"]
  logging_key_id = module.logging.kms_key_arn
  vpc_cidr = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs = var.public_subnet_cidrs
}

# Database
module "database" {
  source = "../database"

  project_name      = var.project_name
  environment       = var.environment
  subnet_ids        = module.networking.private_subnet_ids
  security_group_id = module.networking.rds_security_group_id
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

  db_password_secret_arn                   = "${module.secrets.secrets["database"].secret_arn}:password"
  aws_account_id                           = data.aws_caller_identity.identity.account_id
  backend_kms_arn                          = var.backend_kms_key
  document_inference_lambda_arn            = module.lambda.document_inference_lambda_arn
  document_inference_evaluation_lambda_arn = module.lambda.document_inference_evaluation_lambda_arn
  evaluation_lambda_arn                    = module.lambda.evaluation_lambda_arn
  github_branch = var.github_branch
  github_environment = var.github_environment
}

# ECS
module "ecs" {
  source = "../ecs"

  project_name = var.project_name
  environment  = var.environment
  rails_environment = var.rails_environment

  db_host_secret_arn          = "${module.secrets.secrets["database"].secret_arn}:host"
  db_name_secret_arn          = "${module.secrets.secrets["database"].secret_arn}:name"
  db_username_secret_arn      = "${module.secrets.secrets["database"].secret_arn}:username"
  db_password_secret_arn      = "${module.secrets.secrets["database"].secret_arn}:password"
  secret_key_base_secret_arn  = "${module.secrets.secrets["rails"].secret_arn}:secret_key"
  rails_master_key_secret_arn = "${module.secrets.secrets["rails"].secret_arn}:master_key"
  smtp_endpoint_secret_arn    = "${module.secrets.secrets["smtp"].secret_arn}:endpoint"
  smtp_user_secret_arn        = "${module.secrets.secrets["smtp"].secret_arn}:user"
  smtp_password_secret_arn    = "${module.secrets.secrets["smtp"].secret_arn}:password"
  redis_url_secret_arn        = "${module.secrets.secrets["redis"].secret_arn}:url"
  google_analytics_key_arn    = "${module.secrets.secrets["google_analytics"].secret_arn}:key"

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
  secret_google_ai_key_arn                         = module.secrets.secrets["google"].secret_arn
  secret_anthropic_key_arn                         = module.secrets.secrets["anthropic"].secret_arn
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