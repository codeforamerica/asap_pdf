output "vpc_id" {
  description = "ID of the VPC"
  value       = module.asap_pdf.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.asap_pdf.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.asap_pdf.private_subnet_ids
}

output "db_endpoint" {
  description = "Endpoint of the RDS instance"
  value       = module.asap_pdf.db_endpoint
}

output "db_name" {
  description = "Name of the database"
  value       = module.asap_pdf.db_name
}

output "db_username" {
  description = "Master username of the database"
  value       =  module.asap_pdf.db_username
}

output "db_password_secret_arn" {
  description = "ARN of the secret containing the database password"
  value       = module.asap_pdf.db_password_secret_arn
  sensitive   = true
}

output "redis_endpoint" {
  description = "Endpoint of the Redis cluster"
  value       = module.asap_pdf.redis_endpoint
}

output "redis_port" {
  description = "Port of the Redis cluster"
  value       = module.asap_pdf.redis_port
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.asap_pdf.ecs_cluster_name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for document storage"
  value       = module.asap_pdf.s3_bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for document storage"
  value       = module.asap_pdf.s3_bucket_arn
}

# Application URLs and connection strings
output "database_url" {
  description = "Database connection URL"
  value = module.asap_pdf.database_url
  sensitive = true
}

output "redis_url" {
  description = "Redis connection URL"
  value = module.asap_pdf.redis_url
}

output "github_actions_role_arn" {
  description = "The ARN of the IAM role for GitHub Actions"
  value       = module.asap_pdf.github_actions_role_arn
}
