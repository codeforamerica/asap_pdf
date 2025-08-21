variable "project_name" {
  description = "Name of the project, used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "multi_az" {
  description = "Whether or not the RDS instance should have multiple availability zones"
  type        = bool
}

variable "subnet_ids" {
  description = "List of subnet IDs where RDS will be placed"
  type        = list(string)
}

variable "security_group_id" {
  description = "ID of the security group for RDS"
  type        = string
}

