# =============================================================================
# ReadlePress Terraform Infrastructure
# PDF Specification: AWS Mumbai (ap-south-1)
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Uncomment and configure for remote state:
  # backend "s3" {
  #   bucket         = "readlepress-terraform-state"
  #   key            = "readlepress/${var.environment}/terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "readlepress-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ReadlePress"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# WAF for CloudFront must be in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "ReadlePress"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  name_prefix = "readlepress-${var.environment}"

  # Instance sizing by environment
  rds_instance_class = var.environment == "prod" ? "db.r6g.large" : "db.t3.medium"
  redis_node_type    = var.environment == "prod" ? "cache.r6g.large" : "cache.t3.micro"

  # DB roles (app_rw, app_ro, audit_viewer, migration_runner) are created via
  # application migrations (db/init/00_roles.sql, db/repeatable/R__rls_policies.sql)
  # not by Terraform.
}
