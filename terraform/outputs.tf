output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.networking.private_subnet_ids
}

output "db_endpoint" {
  description = "Endpoint of the RDS instance"
  value       = module.database.db_instance_endpoint
}

output "db_name" {
  description = "Name of the database"
  value       = module.database.db_instance_name
}

output "db_username" {
  description = "Master username of the database"
  value       = module.database.db_instance_username
}

output "db_password_secret_arn" {
  description = "ARN of the secret containing the database password"
  value       = module.database.db_password_secret_arn
  sensitive   = true
}

output "redis_endpoint" {
  description = "Endpoint of the Redis cluster"
  value       = module.cache.redis_endpoint
}

output "redis_port" {
  description = "Port of the Redis cluster"
  value       = module.cache.redis_port
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.ecs.service_name
}

output "cloudwatch_log_group" {
  description = "Name of the CloudWatch log group"
  value       = module.ecs.cloudwatch_log_group_name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for document storage"
  value       = aws_s3_bucket.documents.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for document storage"
  value       = aws_s3_bucket.documents.arn
}

# Application URLs and connection strings
output "database_url" {
  description = "Database connection URL"
  value = format("postgres://%s:%s@%s/%s",
    module.database.db_instance_username,
    module.database.db_password_secret_arn,
    module.database.db_instance_endpoint,
    module.database.db_instance_name
  )
  sensitive = true
}

output "redis_url" {
  description = "Redis connection URL"
  value = format("redis://%s:%s",
    module.cache.redis_endpoint,
    module.cache.redis_port
  )
}

output "ecr_repository_name" {
  description = "The name of the ECR repository"
  value       = module.deployment.ecr_repository_name
}

output "github_actions_role_arn" {
  description = "The ARN of the IAM role for GitHub Actions"
  value       = module.deployment.github_actions_role_arn
}
