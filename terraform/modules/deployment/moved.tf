moved {
  from = aws_ecr_repository.app
  to   = module.ecs.module.fargate_service.module.ecr["this"].aws_ecr_repository.this
}

