moved {
  from = aws_iam_role.ecs_task_execution_role
  to   = module.fargate_service.aws_iam_role.execution
}

moved {
  from = aws_iam_role.ecs_task_role
  to   = module.fargate_service.aws_iam_role.task
}

moved {
  from = aws_cloudwatch_log_group.app
  to   = module.fargate_service.aws_cloudwatch_log_group.service
}

moved {
  from = aws_ecs_cluster.main
  to   = module.fargate_service.module.ecs.aws_ecs_cluster.main
}

moved {
  from = aws_ecs_service.app
  to   = module.fargate_service.module.ecs_service.module.fargate.aws_ecs_service.main[0]
}

moved {
  from = aws_ecs_task_definition.app
  to   = module.fargate_service.module.ecs_service.module.fargate.module.task.aws_ecs_task_definition.main[0]
}