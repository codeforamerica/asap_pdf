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

variable "document_inference_evaluation_ecr_repository_url" {
  description = "Document Inference for Evaluation image repository URI"
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

variable "secret_openai_key_arn" {
  description = "Secret arn for our OpenAI creds."
  type        = string
}

variable "s3_document_bucket_arn" {
  description = "Secret arn for our Anthropic creds."
  type        = string
}

variable "secret_rails_api_user" {
  description = "Rails API user for Python access."
  type        = string
}

variable "secret_rails_api_password" {
  description = "Rails API password for Python access."
  type        = string
}

variable "secret_google_service_account_evals_key_arn" {
  description = "Google service account creds for evals."
  type        = string
}

variable "secret_google_sheet_id_evals_key_arn" {
  description = "Google sheet id for evals."
  type        = string
}