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

# ECR 30 day expiration policy.
data "aws_ecr_lifecycle_policy_document" "thirty_day_expiration_policy" {
  rule {
    priority    = 1
    description = "Remove all images older than 30 days old that are not associated with an active service."

    selection {
      tag_status   = "any"
      count_type   = "sinceImagePushed"
      count_unit   = "days"
      count_number = "30"
    }

    action {
      type = "expire"
    }
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
  policy     = data.aws_iam_policy_document.lambda_ecr.json
  repository = aws_ecr_repository.document_inference.name
}

resource "aws_ecr_lifecycle_policy" "document_inference" {
  repository = aws_ecr_repository.document_inference.name
  policy     = data.aws_ecr_lifecycle_policy_document.thirty_day_expiration_policy.json
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
  policy     = data.aws_iam_policy_document.lambda_ecr.json
  repository = aws_ecr_repository.evaluation.name
}

resource "aws_ecr_lifecycle_policy" "evaluation" {
  repository = aws_ecr_repository.evaluation.name
  policy     = data.aws_ecr_lifecycle_policy_document.thirty_day_expiration_policy.json
}

resource "aws_ecr_repository" "document_inference_evaluation" {
  name                 = "${var.project_name}-document-inference-evaluation-${var.environment}"
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

resource "aws_ecr_repository_policy" "document_inference_evaluation" {
  policy     = data.aws_iam_policy_document.lambda_ecr.json
  repository = aws_ecr_repository.document_inference_evaluation.name
}

resource "aws_ecr_lifecycle_policy" "document_inference_evaluation" {
  repository = aws_ecr_repository.document_inference_evaluation.name
  policy     = data.aws_ecr_lifecycle_policy_document.thirty_day_expiration_policy.json
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
              "repo:${var.github_repository}:ref:refs/heads/${var.github_branch}",
              "repo:${var.github_repository}:environment:${var.github_environment}"
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
          "ecs:DescribeTasks",
          "ecs:TagResource",
          "ecs:DeregisterTaskDefinition",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:GetLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/ecs/${var.project_name}/${var.environment}/app:*"
      },
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          "arn:aws:iam::${var.aws_account_id}:role/${var.project_name}-${var.environment}-app-execution",
          "arn:aws:iam::${var.aws_account_id}:role/${var.project_name}-${var.environment}-app-task"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:InvokeFunction"
        ]
        Resource = [
          var.document_inference_lambda_arn,
          var.document_inference_evaluation_lambda_arn,
          var.evaluation_lambda_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:PutParameter"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.project_name}/${var.environment}/app/version",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:DeleteItem",
        ]
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/*.tfstate"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
        ]
        Resource = [
          "arn:aws:kms:${var.aws_region}:${var.aws_account_id}:key/${var.backend_kms_arn}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:PutEncryptionConfiguration",
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-tfstate/*",
          "arn:aws:s3:::${var.project_name}-${var.environment}-logs",
          "arn:aws:s3:::${var.project_name}-${var.environment}-logs/*",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:CreateSecret",
          "secretsmanager:TagResource",
        ]
        # @todo use prod and staging some day.
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${var.project_name}/${var.environment}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_readonly" {
  role       = aws_iam_role.github_actions.id
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
