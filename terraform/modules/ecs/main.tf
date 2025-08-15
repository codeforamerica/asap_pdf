module "fargate_service" {
  source = "github.com/codeforamerica/tofu-modules-aws-fargate-service?ref=1.3.0"

  project       = var.project_name
  project_short = var.project_name
  environment   = var.environment
  service       = "app"
  service_short = "app"

  domain          = var.domain_name
  vpc_id          = var.vpc_id
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  logging_key_id  = var.logging_key_id
  cpu             = 1024
  memory          = 2048
  container_port  = 3000

  execution_policies = [aws_iam_policy.ecs_task_secrets_policy.arn, aws_iam_policy.ecs_s3_access.arn]
  task_policies = [aws_iam_policy.ecs_task_lambda_invoke_policy.arn]

  enable_execute_command   = true
  create_version_parameter = true
  public                   = true
  health_check_path        = "/up"

  environment_variables = {
    RAILS_ENV           = var.rails_environment
    PORT = tostring(var.container_port)
    WEB_CONCURRENCY     = "2"
    MALLOC_ARENA_MAX    = "2"
    RAILS_MAX_THREADS   = "5"
    RAILS_LOG_TO_STDOUT = "true"
    RAILS_LOG_LEVEL     = "debug"
  }

  environment_secrets = {
    DB_HOST : var.db_host_secret_arn
    DB_NAME : var.db_name_secret_arn
    DB_USERNAME : var.db_username_secret_arn
    DB_PASSWORD : var.db_password_secret_arn
    SECRET_KEY_BASE : var.secret_key_base_secret_arn
    RAILS_MASTER_KEY : var.rails_master_key_secret_arn
    REDIS_URL : var.redis_url_secret_arn,
    SMTP_ENDPOINT : var.smtp_endpoint_secret_arn,
    SMTP_USER : var.smtp_user_secret_arn,
    SMTP_PASSWORD : var.smtp_password_secret_arn,
    GOOGLE_ANALYTICS_KEY : var.google_analytics_key_arn,
  }
}

# Add permissions for Secrets Manager access
resource "aws_iam_policy" "ecs_task_secrets_policy" {
  name = "${var.project_name}-${var.environment}-task-secrets-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          var.db_host_secret_arn,
          var.db_name_secret_arn,
          var.db_username_secret_arn,
          var.db_password_secret_arn,
          var.secret_key_base_secret_arn,
          var.rails_master_key_secret_arn,
          var.redis_url_secret_arn,
          var.smtp_endpoint_secret_arn,
          var.smtp_user_secret_arn,
          var.smtp_password_secret_arn,
          var.google_analytics_key_arn,
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "ecs_task_lambda_invoke_policy" {
  name = "${var.project_name}-${var.environment}-ecs-lambda-invoke-policy"
  # @todo Not sure how to get this.
  #role = aws_iam_role.ecs_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:InvokeFunctionUrl",
          "lambda:GetFunctionUrlConfig",
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM policy for ECS tasks to access S3
resource "aws_iam_policy" "ecs_s3_access" {
  name = "${var.project_name}-${var.environment}-ecs-s3-access"
  #role = split("/", module.ecs.task_execution_role_arn)[1]

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
          var.aws_s3_bucket_arn,
          "${var.aws_s3_bucket_arn}/*"
        ]
      }
    ]
  })
}
