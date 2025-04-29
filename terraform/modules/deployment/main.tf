# Main application ECR Repository
data "aws_iam_policy_document" "lambda_ecr" {
  statement {
    effect = "Allow"

    principals {
      identifiers = ["*"]
      type = "AWS"
    }

    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:SetRepositoryPolicy",
    ]
  }
}

resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-${var.environment}"
  force_delete         = true
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
  }
}

# Document inference ECR repository.
resource "aws_ecr_repository" "document_inference" {
  name                 = "${var.project_name}-lambda-document-inference-${var.environment}"
  force_delete         = true
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_ecr_repository_policy" "document_inference" {
  policy  = data.aws_iam_policy_document.lambda_ecr.json
  repository = aws_ecr_repository.document_inference.name
}

resource "aws_ecr_repository" "evaluation" {
  name                 = "${var.project_name}-evaluation-${var.environment}"
  force_delete         = true
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_ecr_repository_policy" "evaluation" {
  policy  = data.aws_iam_policy_document.lambda_ecr.json
  repository = aws_ecr_repository.evaluation.name
}

# GitHub OIDC Provider
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1", # GitHub's OIDC thumbprint
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"  # GitHub's OIDC v2 thumbprint
  ]

  tags = {
    Name = "github-actions"
  }
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-${var.environment}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_repository}:*",
              "repo:${var.github_repository}:ref:refs/heads/main",
              "repo:${var.github_repository}:environment:production"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-github-actions"
    Environment = var.environment
  }
}

# IAM Policy for GitHub Actions
resource "aws_iam_role_policy" "github_actions" {
  name = "${var.project_name}-${var.environment}-github-actions"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService",
          "ecs:RegisterTaskDefinition",
          "ecs:ListTaskDefinitions",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTasks",
          "ecs:DescribeTasks"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:GetLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/ecs/${var.project_name}-${var.environment}:*"
      },
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          "arn:aws:iam::${var.aws_account_id}:role/${var.project_name}-${var.environment}-task-execution-role",
          "arn:aws:iam::${var.aws_account_id}:role/${var.project_name}-${var.environment}-task-role"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode"
        ]
        Resource = [
          var.document_inference_lambda_arn,
          var.document_inference_evaluation_lambda_arn,
          var.evaluation_lambda_arn
        ]
      }
    ]
  })
}

# Database Host Secret
resource "aws_secretsmanager_secret" "db_host" {
  name = "${var.project_name}/${var.environment}/DB_HOST"

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-host"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_host" {
  secret_id     = aws_secretsmanager_secret.db_host.id
  secret_string = var.db_endpoint
}

# Database Name Secret
resource "aws_secretsmanager_secret" "db_name" {
  name = "${var.project_name}/${var.environment}/DB_NAME"

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-name"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_name" {
  secret_id     = aws_secretsmanager_secret.db_name.id
  secret_string = var.db_name
}

# Database Username Secret
resource "aws_secretsmanager_secret" "db_username" {
  name = "${var.project_name}/${var.environment}/DB_USERNAME"

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-username"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_username" {
  secret_id     = aws_secretsmanager_secret.db_username.id
  secret_string = var.db_username
}

# Database Password Secret (using existing secret)
resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.project_name}/${var.environment}/DB_PASSWORD"

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-password"
    Environment = var.environment
  }
}

# Get the existing password from the provided secret ARN
data "aws_secretsmanager_secret" "db_password" {
  arn = var.db_password_secret_arn
}

data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = data.aws_secretsmanager_secret.db_password.id
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = data.aws_secretsmanager_secret_version.db_password.secret_string
}

# Rails Master Key Secret
resource "aws_secretsmanager_secret" "rails_master_key" {
  name = "${var.project_name}/${var.environment}/RAILS_MASTER_KEY"

  tags = {
    Name        = "${var.project_name}-${var.environment}-rails-master-key"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "rails_master_key" {
  secret_id     = aws_secretsmanager_secret.rails_master_key.id
  secret_string = var.rails_master_key
}

# Secret Key Base Secret
resource "aws_secretsmanager_secret" "secret_key_base" {
  name = "${var.project_name}/${var.environment}/SECRET_KEY_BASE"

  tags = {
    Name        = "${var.project_name}-${var.environment}-secret-key-base"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "secret_key_base" {
  secret_id     = aws_secretsmanager_secret.secret_key_base.id
  secret_string = var.secret_key_base
}

# Redis URL Secret
resource "aws_secretsmanager_secret" "redis_url" {
  name = "${var.project_name}/${var.environment}/REDIS_URL"

  tags = {
    Name        = "${var.project_name}-${var.environment}-redis-url"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "redis_url" {
  secret_id     = aws_secretsmanager_secret.redis_url.id
  secret_string = var.redis_url
}

# Google/Gemini API Keys
resource "aws_secretsmanager_secret" "google_ai_key" {
  name = "${var.project_name}/${var.environment}/GOOGLE_AI_KEY"

  tags = {
    Name        = "${var.project_name}-${var.environment}-google-ai-key"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "google_ai_key" {
  secret_id     = aws_secretsmanager_secret.google_ai_key.id
  secret_string = var.google_ai_key
}

resource "aws_secretsmanager_secret" "anthropic_key" {
  name = "${var.project_name}/${var.environment}/ANTHROPIC_KEY"

  tags = {
    Name        = "${var.project_name}-${var.environment}-anthropic-key"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "anthropic_key" {
  secret_id     = aws_secretsmanager_secret.anthropic_key.id
  secret_string = var.anthropic_key
}
