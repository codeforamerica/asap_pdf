variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the Fargate tasks"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for the Fargate tasks"
  type        = string
}

variable "container_image" {
  description = "Docker image for the application container"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
}

variable "container_cpu" {
  description = "CPU units for the Fargate task (256 = 0.25 vCPU, 512 = 0.5 vCPU, 1024 = 1 vCPU)"
  type        = number
}

variable "container_memory" {
  description = "Memory for the Fargate task in MiB (512, 1024, 2048, etc.)"
  type        = number
}

variable "db_host_secret_arn" {
  description = "ARN of the database host secret in Secrets Manager"
  type        = string
}

variable "db_name_secret_arn" {
  description = "ARN of the database name secret in Secrets Manager"
  type        = string
}

variable "db_username_secret_arn" {
  description = "ARN of the database username secret in Secrets Manager"
  type        = string
}

variable "db_password_secret_arn" {
  description = "ARN of the database password secret in Secrets Manager"
  type        = string
}

variable "secret_key_base_secret_arn" {
  description = "ARN of the Rails secret key base secret in Secrets Manager"
  type        = string
}

variable "rails_master_key_secret_arn" {
  description = "ARN of the Rails master key secret in Secrets Manager"
  type        = string
}

variable "redis_url_secret_arn" {
  description = "ARN of the Redis URL secret in Secrets Manager"
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group"
  type        = string
}
