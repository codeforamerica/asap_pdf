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
}

variable "rails_environment" {
  description = "The rails environment (test or production)."
  type        = string
}

variable "backend_kms_key" {
  description = "KMS key for deployment decryption"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "Public CIDR blocks"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private CIDR blocks"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "The VPC's CIDR"
  type        = string
}

variable "github_branch" {
  description = "The branch that Github should be able to trigger deployments with."
  type        = string
}

variable "github_environment" {
  description = "The environment that Github should be able to trigger deployments from."
  type        = string
}

variable "single_nat_gateway" {
  description = "Whether to create multiple NAT gateways or just one"
  type        = string
}

variable "rds_multi_az" {
  description = "Whether or not the RDS instance should have multiple availability zones"
  type        = bool
}