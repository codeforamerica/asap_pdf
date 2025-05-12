output "document_inference_lambda_arn" {
  description = "ARN of the production document_inference lambda."
  value       = aws_lambda_function.document_inference.arn
}

output "document_inference_evaluation_lambda_arn" {
  description = "ARN of the dev document_inference lambda."
  value       = aws_lambda_function.document_inference_evaluation.arn
}

output "evaluation_lambda_arn" {
  description = "ARN of the evaluation lambda."
  value       = aws_lambda_function.evaluation.arn
}
