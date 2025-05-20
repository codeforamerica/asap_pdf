moved {
  from = module.networking.aws_security_group.ecs
  to   = module.ecs.module.fargate_service.module.task_security_group.aws_security_group.this_name_prefix[0]
}

moved {
  from = module.networking.aws_security_group.alb
  to   = module.ecs.module.fargate_service.module.endpoint_security_group.aws_security_group.this_name_prefix[0]
}

moved {
  from = module.networking.aws_lb.main
  to   = module.ecs.module.fargate_service.module.alb["this"].aws_lb.this[0]
}

moved {
  from = module.networking.aws_acm_certificate.main
  to   = module.ecs.module.fargate_service.aws_acm_certificate.endpoint["this"]
}

moved {
  from = module.networking.aws_lb_listener.https
  to = module.ecs.module.fargate_service.module.alb["this"].aws_lb_listener.this["https"]
}

moved {
  from = module.networking.aws_lb_listener.http
  to = module.ecs.module.fargate_service.module.alb["this"].aws_lb_listener.this["http"]
}

moved {
  from = module.deployment.aws_ecr_repository.app
  to   = module.ecs.module.fargate_service.module.ecr["this"].aws_ecr_repository.this[0]
}

moved {
  from = module.networking.aws_lb_target_group.app
  to   = module.ecs.module.fargate_service.module.alb["this"].aws_lb_target_group.this["endpoint"]
}