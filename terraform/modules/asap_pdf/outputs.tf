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
  value       = module.secrets.secrets["DB_PASSWORD"].secret_arn
  sensitive   = true
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for document storage"
  value       = aws_s3_bucket.documents.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for document storage"
  value       = aws_s3_bucket.documents.arn
}

output "logging_bucket" {
  description = "Logging bucket name."
  value       = module.logging.bucket
}

# Application URLs and connection strings
output "database_url" {
  description = "Database connection URL"
  value = format("postgres://%s:%s@%s/%s",
    module.database.db_instance_username,
    module.secrets.secrets["DB_PASSWORD"].secret_arn,
    module.database.db_instance_endpoint,
    module.database.db_instance_name
  )
  sensitive = true
}

output "github_actions_role_arn" {
  description = "The ARN of the IAM role for GitHub Actions"
  value       = module.deployment.github_actions_role_arn
}
