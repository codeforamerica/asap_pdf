variable "project_name" {
  description = "Name of the project, used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in format owner/repo"
  type        = string
  default = "codeforamerica/asap_pdf"
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

variable "document_inference_lambda_arn" {
  description = "ARN of the production document_inference lambda."
  type        = string
}

variable "document_inference_evaluation_lambda_arn" {
  description = "ARN of the dev document_inference lambda."
  type        = string
}

variable "evaluation_lambda_arn" {
  description = "ARN of the evaluation lambda."
  type        = string
}

variable "backend_kms_arn" {
  description = "Backend module's KMS key."
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

