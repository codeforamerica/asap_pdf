output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.fargate_service.cluster_name
}
