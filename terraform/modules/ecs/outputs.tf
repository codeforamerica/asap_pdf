output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.fargate_service.cluster_name
}

output "execution_role_arn" {
  description = "ARN of the role used to execute tasks"
  value       = module.fargate_service.execution_role_arn
}

output "task_role_arn" {
  description = "ARN of the role attached to running tasks"
  value       = module.fargate_service.task_role_arn
}
