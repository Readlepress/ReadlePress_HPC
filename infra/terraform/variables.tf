# =============================================================================
# ReadlePress Terraform Variables
# =============================================================================

variable "aws_region" {
  description = "AWS region (Mumbai per PDF specification)"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment: dev, staging, or prod"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "readlepress"
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones (ap-south-1 has a, b, c)"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

# -----------------------------------------------------------------------------
# RDS
# -----------------------------------------------------------------------------

variable "db_name" {
  description = "Name of the default database"
  type        = string
  default     = "readlepress"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS (GB)"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Max allocated storage for autoscaling (GB)"
  type        = number
  default     = 100
}

variable "db_master_username" {
  description = "Master username for RDS"
  type        = string
  sensitive   = true
}

variable "db_master_password" {
  description = "Master password for RDS (use Secrets Manager for production)"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# ElastiCache Redis
# -----------------------------------------------------------------------------

variable "redis_num_cache_clusters" {
  description = "Number of cache nodes in Redis cluster"
  type        = number
  default     = 1
}

# -----------------------------------------------------------------------------
# S3
# -----------------------------------------------------------------------------
# Evidence bucket uses SSE-KMS with auto-created key (alias: readlepress-evidence-{env})

# -----------------------------------------------------------------------------
# CloudFront
# -----------------------------------------------------------------------------

variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_200" # India, Europe, North America
}

# -----------------------------------------------------------------------------
# WAF
# -----------------------------------------------------------------------------

variable "waf_rate_limit" {
  description = "Rate limit (requests per 5 min) per IP"
  type        = number
  default     = 2000
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
