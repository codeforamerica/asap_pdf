# Redis subnet group
resource "aws_elasticache_subnet_group" "main" {
  name        = "${var.project_name}-${var.environment}"
  description = "Subnet group for Redis cluster"
  subnet_ids  = var.subnet_ids
}

# Redis parameter group
resource "aws_elasticache_parameter_group" "main" {
  family = "redis7"
  name   = "${var.project_name}-${var.environment}"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-parameter-group"
  }
}

# Redis cluster
resource "aws_elasticache_cluster" "main" {
  cluster_id           = "${var.project_name}-${var.environment}"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = aws_elasticache_parameter_group.main.name
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [var.security_group_id]

  maintenance_window = "sun:05:00-sun:06:00"
  snapshot_window    = "04:00-05:00"

  snapshot_retention_limit = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-redis"
  }
}
