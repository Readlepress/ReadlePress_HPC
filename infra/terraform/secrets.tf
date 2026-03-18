# =============================================================================
# ReadlePress Secrets Manager
# db-password, jwt-signing-key, msg91-api-key, emudhra-signing-cert,
# tsa-credentials, ai-provider-key, redis-auth-token
# =============================================================================

locals {
  secrets_prefix = "readlepress/${var.environment}"
}

# Placeholder secrets - values must be set manually or via CI/CD
# Use aws secretsmanager put-secret-value to populate after creation

resource "aws_secretsmanager_secret" "db_password" {
  name        = "${local.secrets_prefix}/db-password"
  description = "RDS PostgreSQL master password"

  tags = {
    Name = "${local.secrets_prefix}/db-password"
  }
}

resource "aws_secretsmanager_secret" "jwt_signing_key" {
  name        = "${local.secrets_prefix}/jwt-signing-key"
  description = "JWT signing key for auth tokens"

  tags = {
    Name = "${local.secrets_prefix}/jwt-signing-key"
  }
}

resource "aws_secretsmanager_secret" "msg91_api_key" {
  name        = "${local.secrets_prefix}/msg91-api-key"
  description = "MSG91 SMS API key for OTP"

  tags = {
    Name = "${local.secrets_prefix}/msg91-api-key"
  }
}

resource "aws_secretsmanager_secret" "emudhra_signing_cert" {
  name        = "${local.secrets_prefix}/emudhra-signing-cert"
  description = "eMudhra signing certificate for digital signatures"

  tags = {
    Name = "${local.secrets_prefix}/emudhra-signing-cert"
  }
}

resource "aws_secretsmanager_secret" "tsa_credentials" {
  name        = "${local.secrets_prefix}/tsa-credentials"
  description = "Timestamp Authority (TSA) credentials for PDF signing"

  tags = {
    Name = "${local.secrets_prefix}/tsa-credentials"
  }
}

resource "aws_secretsmanager_secret" "ai_provider_key" {
  name        = "${local.secrets_prefix}/ai-provider-key"
  description = "AI provider API key"

  tags = {
    Name = "${local.secrets_prefix}/ai-provider-key"
  }
}

resource "aws_secretsmanager_secret" "redis_auth_token" {
  name        = "${local.secrets_prefix}/redis-auth-token"
  description = "ElastiCache Redis auth token"

  tags = {
    Name = "${local.secrets_prefix}/redis-auth-token"
  }
}

# Store Redis auth token (Terraform-managed)
resource "aws_secretsmanager_secret_version" "redis_auth_token" {
  secret_id     = aws_secretsmanager_secret.redis_auth_token.id
  secret_string = random_password.redis_auth.result
}
