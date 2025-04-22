module "fargate_service" {
  source = "github.com/codeforamerica/tofu-modules-aws-fargate-service?ref=1.2.0"

  project       = var.project_name
  project_short = var.project_name
  environment   = var.environment
  service       = "${var.project_name}-app"
  service_short = "app"

  domain          = var.domain_name
  vpc_id          = var.vpc_id
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  logging_key_id  = var.logging_key_id
  container_port  = 3000

  execution_policies = [aws_iam_policy.ecs_task_secrets_policy.arn, aws_iam_policy.ecs_s3_access.arn]
  task_policies = [aws_iam_policy.ecs_task_lambda_invoke_policy.arn]

  environment_variables = {
    RAILS_ENV = var.environment
    PORT = tostring(var.container_port)
    WEB_CONCURRENCY = "2"
    MALLOC_ARENA_MAX = "2"
    RAILS_MAX_THREADS = "5"
    RAILS_LOG_TO_STDOUT = "true"
    RAILS_LOG_LEVEL = "debug"
  }
}

# ECS cluster
# resource "aws_ecs_cluster" "main" {
#   name = "${var.project_name}-${var.environment}"
#
#   setting {
#     name  = "containerInsights"
#     value = "enabled"
#   }
#
#   tags = {
#     Name = "${var.project_name}-${var.environment}-cluster"
#   }
# }

# IAM role for ECS tasks
# resource "aws_iam_role" "ecs_task_execution_role" {
#   name = "${var.project_name}-${var.environment}-task-execution-role"
#
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "ecs-tasks.amazonaws.com"
#         }
#       }
#     ]
#   })
#}

# Attach the AWS managed policy for ECS task execution
# resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
#   role       = aws_iam_role.ecs_task_execution_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
# }

# Add permissions for Secrets Manager access
resource "aws_iam_policy" "ecs_task_secrets_policy" {
  name = "${var.project_name}-${var.environment}-task-secrets-policy"
  # @todo Not sure how to get this.
  #role = aws_iam_role.ecs_task_execution_role.id

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
          var.redis_url_secret_arn
        ]
      }
    ]
  })
}
#
# resource "aws_iam_role_policy" "ecs_task_cli_exec" {
#   name = "${var.project_name}-${var.environment}-task-cli-exec-policy"
#   role = aws_iam_role.ecs_task_execution_role.id
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         "Effect" : "Allow",
#         "Action" : [
#           "ecs:ExecuteCommand"
#         ],
#         "Resource" : "*"
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "ssmmessages:CreateControlChannel",
#           "ssmmessages:CreateDataChannel",
#           "ssmmessages:OpenControlChannel",
#           "ssmmessages:OpenDataChannel"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }

# IAM role for ECS tasks (task role)
# resource "aws_iam_role" "ecs_task_role" {
#   name = "${var.project_name}-${var.environment}-task-role"
#
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "ecs-tasks.amazonaws.com"
#         }
#       }
#     ]
#   })
# }

# Add ECS Exec permissions to task role
# resource "aws_iam_role_policy" "ecs_task_exec_policy" {
#   name = "${var.project_name}-${var.environment}-task-exec-policy"
#   role = aws_iam_role.ecs_task_role.id
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         "Effect" : "Allow",
#         "Action" : [
#           "ecs:ExecuteCommand"
#         ],
#         "Resource" : "*"
#       },
#       {
#         Effect = "Allow"
#         Action = [
#           "ssmmessages:CreateControlChannel",
#           "ssmmessages:CreateDataChannel",
#           "ssmmessages:OpenControlChannel",
#           "ssmmessages:OpenDataChannel"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
#}


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

# Task definition
# resource "aws_ecs_task_definition" "app" {
#   family             = "${var.project_name}-${var.environment}-app"
#   network_mode       = "awsvpc"
#   requires_compatibilities = ["FARGATE"]
#   cpu                = var.container_cpu
#   memory             = var.container_memory
#   execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
#   task_role_arn      = aws_iam_role.ecs_task_role.arn
#
#   container_definitions = jsonencode([
#     {
#       name  = "app"
#       image = var.container_image
#
#       portMappings = [
#         {
#           containerPort = var.container_port
#           hostPort      = var.container_port
#           protocol      = "tcp"
#         }
#       ]
#
#       environment = [
#         {
#           name  = "RAILS_ENV"
#           value = var.environment
#         },
#         {
#           name = "PORT"
#           value = tostring(var.container_port)
#         },
#         {
#           name  = "WEB_CONCURRENCY"
#           value = "2"
#         },
#         {
#           name  = "MALLOC_ARENA_MAX"
#           value = "2"
#         },
#         {
#           name  = "RAILS_MAX_THREADS"
#           value = "5"
#         },
#         {
#           name  = "RAILS_LOG_TO_STDOUT"
#           value = "true"
#         },
#         {
#           name  = "RAILS_LOG_LEVEL"
#           value = "debug"
#         }
#       ]
#
#       secrets = [
#         {
#           name      = "DB_HOST"
#           valueFrom = var.db_host_secret_arn
#         },
#         {
#           name      = "DB_NAME"
#           valueFrom = var.db_name_secret_arn
#         },
#         {
#           name      = "DB_USERNAME"
#           valueFrom = var.db_username_secret_arn
#         },
#         {
#           name      = "DB_PASSWORD"
#           valueFrom = var.db_password_secret_arn
#         },
#         {
#           name      = "SECRET_KEY_BASE"
#           valueFrom = var.secret_key_base_secret_arn
#         },
#         {
#           name      = "RAILS_MASTER_KEY"
#           valueFrom = var.rails_master_key_secret_arn
#         },
#         {
#           name      = "REDIS_URL"
#           valueFrom = var.redis_url_secret_arn
#         }
#       ]
#
#       stopTimeout = 120
#
#       logConfiguration = {
#         logDriver = "awslogs"
#         options = {
#           "awslogs-group"         = "/ecs/${var.project_name}-${var.environment}"
#           "awslogs-region"        = "us-east-1"
#           "awslogs-stream-prefix" = "web"
#           "awslogs-create-group"  = "true"
#         }
#       }
#
#       essential = true
#     }
#   ])
#
#   tags = {
#     Name = "${var.project_name}-${var.environment}-task-definition"
#   }
# }

# CloudWatch Log Groups
# resource "aws_cloudwatch_log_group" "app" {
#   name              = "/ecs/${var.project_name}-${var.environment}"
#   retention_in_days = 30
#
#   tags = {
#     Name = "${var.project_name}-${var.environment}-log-group"
#   }
# }
#
# resource "aws_cloudwatch_log_group" "ecs_exec" {
#   name              = "/ecs/${var.project_name}-${var.environment}/exec-logs"
#   retention_in_days = 30
#
#   tags = {
#     Name = "${var.project_name}-${var.environment}-exec-log-group"
#   }
# }
#
# Add CloudWatch logging permissions to task role
# resource "aws_iam_role_policy" "ecs_task_cloudwatch_policy" {
#   name = "${var.project_name}-${var.environment}-task-cloudwatch-policy"
#   role = aws_iam_role.ecs_task_role.id
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "logs:CreateLogStream",
#           "logs:DescribeLogGroups",
#           "logs:DescribeLogStreams",
#           "logs:PutLogEvents"
#         ]
#         Resource = [
#           "${aws_cloudwatch_log_group.ecs_exec.arn}:*"
#         ]
#       }
#     ]
#   })
# }

# ECS Service
# resource "aws_ecs_service" "app" {
#   name            = "${var.project_name}-${var.environment}-service"
#   cluster         = aws_ecs_cluster.main.id
#   task_definition = aws_ecs_task_definition.app.arn
#   desired_count   = 1
#   launch_type     = "FARGATE"
#
#   deployment_maximum_percent         = 200
#   deployment_minimum_healthy_percent = 50
#
#   deployment_circuit_breaker {
#     enable   = true
#     rollback = true
#   }
#
#   enable_execute_command = true
#
#   network_configuration {
#     subnets = var.subnet_ids
#     security_groups = [
#       var.security_group_id
#     ]
#     assign_public_ip = false
#   }
#
#   load_balancer {
#     target_group_arn = var.target_group_arn
#     container_name   = "app"
#     container_port   = var.container_port
#   }
#
#   tags = {
#     Name = "${var.project_name}-${var.environment}-service"
#   }
# }
