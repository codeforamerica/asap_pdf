variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 3000
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

variable "smtp_endpoint_secret_arn" {
  description = "ARN of the SMTP endpoint"
  type        = string
}

variable "smtp_user_secret_arn" {
  description = "ARN of the SMTP user name"
  type        = string
}

variable "smtp_password_secret_arn" {
  description = "ARN of the SMTP password"
  type        = string
}

variable "redis_url_secret_arn" {
  description = "ARN of the Redis URL secret in Secrets Manager"
  type        = string
}

variable "vpc_id" {
  description = "The VPC id from our network friend."
  type        = string
}

variable "private_subnets" {
  description = "The private subnet ids."
  type = list(string)
}

variable "public_subnets" {
  description = "The public subnet ids."
  type = list(string)
}

variable "logging_key_id" {
  description = "The KMS logging key id."
  type        = string
}

variable "domain_name" {
  description = "The application domain name."
  type        = string
}

variable "aws_s3_bucket_arn" {
  description = "The S3 bucket arn."
  type        = string
}




