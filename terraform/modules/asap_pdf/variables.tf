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
