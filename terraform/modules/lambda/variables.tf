variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "document_inference_ecr_repository_url" {
  description = "Document Inference Image URI"
  type        = string
}

variable "evaluation_ecr_repository_url" {
  description = "Evaluation image repository URI"
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

variable "secret_google_ai_key_arn" {
  description = "Secret arn for our Google creds."
  type        = string
}

variable "secret_anthropic_key_arn" {
  description = "Secret arn for our Anthropic creds."
  type        = string
}