variable "project_name" {
  description = "Name of the project, used in resource naming"
  type        = string
  default     = "asap-pdf"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "domain_name" {
  description = "Name of the project"
  type        = string
  default     = "demo.codeforamerica.ai"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

# Database Configuration
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.small"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS instance in GB"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "access_pdf_production"
}

variable "db_username" {
  description = "Master username for the RDS instance"
  type        = string
  default     = "asap_pdf"
}

# Redis Configuration
variable "redis_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_port" {
  description = "Port for Redis"
  type        = number
  default     = 6379
}

# Container Configuration
variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 3000 # Rails default port
}

variable "container_cpu" {
  description = "CPU units for Fargate task (256 = 0.25 vCPU, 512 = 0.5 vCPU, 1024 = 1 vCPU)"
  type        = number
  default     = 1024 # 1 vCPU
}

variable "container_memory" {
  description = "Memory for Fargate task in MiB (Valid values: 512, 1024, 2048, 3072, 4096, etc.)"
  type        = number
  default     = 2048 # 2GB memory
}

# GitHub Configuration
variable "github_repository" {
  description = "GitHub repository in format owner/repo"
  type        = string
}

# Application Configuration
variable "rails_master_key" {
  description = "Rails master key for the application"
  type        = string
  sensitive   = true
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "secret_key_base" {
  description = "Rails secret key base for production"
  type        = string
  sensitive   = true
}

variable "google_ai_key" {
  description = "Google/Gemini API Key"
  type        = string
  sensitive   = true
}

variable "anthropic_key" {
  description = "Anthropic API Key"
  type        = string
  sensitive   = true
}
