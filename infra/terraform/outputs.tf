# =============================================================================
# ReadlePress Terraform Outputs
# =============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs for RDS, ElastiCache, ECS"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs for ALB, NAT"
  value       = aws_subnet.public[*].id
}

# -----------------------------------------------------------------------------
# RDS
# -----------------------------------------------------------------------------

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.main.endpoint
}

output "rds_address" {
  description = "RDS PostgreSQL host address"
  value       = aws_db_instance.main.address
}

output "rds_port" {
  description = "RDS PostgreSQL port"
  value       = aws_db_instance.main.port
}

output "rds_database_name" {
  description = "Default database name"
  value       = aws_db_instance.main.db_name
}

# -----------------------------------------------------------------------------
# ElastiCache Redis
# -----------------------------------------------------------------------------

output "redis_endpoint" {
  description = "ElastiCache Redis primary endpoint"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_port" {
  description = "ElastiCache Redis port"
  value       = aws_elasticache_replication_group.redis.port
}

# -----------------------------------------------------------------------------
# S3 Buckets
# -----------------------------------------------------------------------------

output "s3_evidence_bucket" {
  description = "Evidence bucket name (SSE-KMS)"
  value       = aws_s3_bucket.evidence.id
}

output "s3_pdfs_bucket" {
  description = "PDFs bucket name"
  value       = aws_s3_bucket.pdfs.id
}

output "s3_packages_bucket" {
  description = "Packages bucket name"
  value       = aws_s3_bucket.packages.id
}

output "s3_backups_bucket" {
  description = "Backups bucket name"
  value       = aws_s3_bucket.backups.id
}

# -----------------------------------------------------------------------------
# CloudFront
# -----------------------------------------------------------------------------

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain for PDF delivery"
  value       = aws_cloudfront_distribution.pdfs.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID"
  value       = aws_cloudfront_distribution.pdfs.hosted_zone_id
}

output "cloudfront_url" {
  description = "CloudFront URL for PDF delivery"
  value       = "https://${aws_cloudfront_distribution.pdfs.domain_name}"
}

# -----------------------------------------------------------------------------
# Secrets Manager
# -----------------------------------------------------------------------------

output "secrets_manager_prefix" {
  description = "Secrets Manager prefix for ReadlePress secrets"
  value       = "readlepress/${var.environment}"
}

# -----------------------------------------------------------------------------
# ALB
# -----------------------------------------------------------------------------

output "alb_dns_name" {
  description = "ALB DNS name for API"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID"
  value       = aws_lb.main.zone_id
}

# -----------------------------------------------------------------------------
# IAM
# -----------------------------------------------------------------------------

output "ecs_task_role_arn" {
  description = "IAM role ARN for ECS tasks"
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_execution_role_arn" {
  description = "IAM role ARN for ECS task execution"
  value       = aws_iam_role.ecs_execution.arn
}
