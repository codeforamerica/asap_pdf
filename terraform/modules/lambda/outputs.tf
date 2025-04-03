output "document_inference_lambda_arn" {
  description = "Name of the CloudWatch log group"
  value       = aws_lambda_function.document_inference.arn
}
