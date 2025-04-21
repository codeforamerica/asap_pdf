moved {
  from = aws_iam_role.ecs_task_execution_role
  to   = module.fargate_service.aws_iam_role.execution
}

moved {
  from = aws_iam_role.ecs_task_role
  to   = module.fargate_service.aws_iam_role.task
}

moved {
  from = aws_ecs_cluster.main
  to   = module.ecs.module.fargate_service.module.ecs.aws_ecs_cluster.main
}

moved {
  from = aws_ecs_service.app
  to   = module.ecs.module.fargate_service.module.ecs_service.module.fargate.aws_ecs_service.main[0]
}

moved {
  from = aws_ecs_task_definition.app
  to   = module.ecs.module.fargate_service.module.ecs_service.module.fargate.module.task.aws_ecs_task_definition.main[0]
}