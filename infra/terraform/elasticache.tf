# =============================================================================
# ReadlePress ElastiCache Redis 7
# Auth token enabled. cache.t3.micro (dev) / cache.r6g.large (prod)
# =============================================================================

resource "random_password" "redis_auth" {
  length  = 32
  special = false
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${local.name_prefix}-redis-subnet"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${local.name_prefix}-redis"
  description          = "ReadlePress Redis cache"
  node_type            = local.redis_node_type
  num_cache_clusters   = var.redis_num_cache_clusters
  port                 = 6379
  engine               = "redis"
  engine_version       = "7.0"

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled  = true
  auth_token                 = random_password.redis_auth.result
  auth_token_update_strategy = "ROTATE"

  automatic_failover_enabled = var.environment == "prod" && var.redis_num_cache_clusters >= 2
  multi_az_enabled          = var.environment == "prod" && var.redis_num_cache_clusters >= 2

  snapshot_retention_limit = var.environment == "prod" ? 7 : 1
  snapshot_window          = "03:00-04:00"
  maintenance_window       = "sun:04:00-sun:05:00"

  tags = {
    Name = "${local.name_prefix}-redis"
  }
}
