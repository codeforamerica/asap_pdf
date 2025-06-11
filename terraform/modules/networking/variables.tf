variable "project_name" {
  description = "Name of the project, used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones for resources"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "logging_key_id" {
  description = "KMS key id to encrypt logs."
  type = string
}