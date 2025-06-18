output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "document_inference_ecr_repository_url" {
  value = aws_ecr_repository.document_inference.repository_url
}

output "evaluation_ecr_repository_url" {
  value = aws_ecr_repository.evaluation.repository_url
}

output "document_inference_evaluation_ecr_repository_url" {
  value = aws_ecr_repository.document_inference_evaluation.repository_url
}

