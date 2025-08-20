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

variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}
