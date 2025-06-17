#  Main document inference lambda.
resource "aws_lambda_function" "document_inference" {
  function_name = "${var.project_name}-document-inference-${var.environment}"
  image_uri     = "${var.document_inference_ecr_repository_url}:latest"
  package_type  = "Image"
  timeout       = 720
  memory_size   = 512

  vpc_config {
    security_group_ids = [var.security_group_id]
    subnet_ids = var.subnet_ids
  }

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function_url" "document_inference_url" {
  function_name      = aws_lambda_function.document_inference.function_name
  authorization_type = "AWS_IAM"
}


# Dev document inference lambda.
resource "aws_lambda_function" "document_inference_evaluation" {
  function_name = "${var.project_name}-document-inference-evaluation-${var.environment}"
  image_uri     = "${var.document_inference_evaluation_ecr_repository_url}:latest"
  package_type  = "Image"
  timeout       = 900
  memory_size   = 512

  vpc_config {
    security_group_ids = [var.security_group_id]
    subnet_ids = var.subnet_ids
  }

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function_url" "document_inference_evaluation_url" {
  function_name      = aws_lambda_function.document_inference_evaluation.function_name
  authorization_type = "AWS_IAM"
}

# Evaluation lambda
resource "aws_lambda_function" "evaluation" {
  function_name = "${var.project_name}-evaluation-${var.environment}"
  image_uri     = "${var.evaluation_ecr_repository_url}:latest"
  package_type  = "Image"
  timeout       = 900
  memory_size   = 640

  vpc_config {
    security_group_ids = [var.security_group_id]
    subnet_ids = var.subnet_ids
  }

  role = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_function_url" "evaluation_url" {
  function_name      = aws_lambda_function.evaluation.function_name
  authorization_type = "AWS_IAM"
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-${var.environment}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_invoke" {
  name = "${var.project_name}-${var.environment}-lambda-invoke-policy"
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:InvokeFunctionUrl",
          "lambda:GetFunctionUrlConfig"
        ]
        Resource = [
          "*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_network" {
  name = "${var.project_name}-${var.environment}-lambda-network-policy"
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeInstances",
          "ec2:AttachNetworkInterface"
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy" "lambda_secrets" {
  name = "${var.project_name}-${var.environment}-lambda-secrets-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          var.secret_google_ai_key_arn,
          var.secret_anthropic_key_arn,
          var.secret_rails_api_user,
          var.secret_rails_api_password,
          var.secret_google_service_account_evals_key_arn,
          var.secret_google_sheet_id_evals_key_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_s3" {
  name = "${var.project_name}-${var.environment}-lambda-s3-access"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_document_bucket_arn,
          "${var.s3_document_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "document_inference" {
  name              = "/lambda/${var.project_name}-document-inference-${var.environment}"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-log-group"
  }
}

resource "aws_iam_role_policy" "lambda_logging" {
  name = "${var.project_name}-${var.environment}-lambda-logging-policy"
  role = aws_iam_role.lambda_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"

        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = ["arn:aws:logs:*:*:*"]
      },
    ]
  })
}
