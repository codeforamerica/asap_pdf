variable "project_name" {
  description = "Name of the project, used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs where RDS will be placed"
  type        = list(string)
}

variable "security_group_id" {
  description = "ID of the security group for RDS"
  type        = string
}

# variable "instance_class" {
#   description = "RDS instance class"
#   type        = string
# }

# variable "allocated_storage" {
#   description = "Allocated storage for RDS instance in GB"
#   type        = number
# }

# variable "db_name" {
#   description = "Name of the database"
#   type        = string
# }

# variable "db_username" {
#   description = "Master username for the RDS instance"
#   type        = string
# }
