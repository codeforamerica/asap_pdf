output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "ecr_repository_name" {
  value = aws_ecr_repository.app.name
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "db_host_secret_arn" {
  value = aws_secretsmanager_secret.db_host.arn
}

output "db_name_secret_arn" {
  value = aws_secretsmanager_secret.db_name.arn
}

output "db_username_secret_arn" {
  value = aws_secretsmanager_secret.db_username.arn
}

output "db_password_secret_arn" {
  value = aws_secretsmanager_secret.db_password.arn
}

output "rails_master_key_secret_arn" {
  value = aws_secretsmanager_secret.rails_master_key.arn
}

output "secret_key_base_secret_arn" {
  value = aws_secretsmanager_secret.secret_key_base.arn
}

output "redis_url_secret_arn" {
  value = aws_secretsmanager_secret.redis_url.arn
}

output "gemini_key_secret_arn" {
  value = aws_secretsmanager_secret.google_ai_key.arn
}

output "anthropic_key_secret_arn" {
  value = aws_secretsmanager_secret.anthropic_key.arn
}

output "document_inference_ecr_repository_url" {
  value = aws_ecr_repository.document_inference.repository_url
}

