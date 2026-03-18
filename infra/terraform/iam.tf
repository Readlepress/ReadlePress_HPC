# =============================================================================
# ReadlePress IAM Roles
# ECS/EC2 access to S3, Secrets Manager
# =============================================================================

locals {
  ecs_task_s3_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.evidence.arn,
          "${aws_s3_bucket.evidence.arn}/*",
          aws_s3_bucket.pdfs.arn,
          "${aws_s3_bucket.pdfs.arn}/*",
          aws_s3_bucket.packages.arn,
          "${aws_s3_bucket.packages.arn}/*",
          aws_s3_bucket.backups.arn,
          "${aws_s3_bucket.backups.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [aws_kms_key.evidence.arn]
      }
    ]
  })
  ecs_task_secrets_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.db_password.arn,
          aws_secretsmanager_secret.jwt_signing_key.arn,
          aws_secretsmanager_secret.msg91_api_key.arn,
          aws_secretsmanager_secret.emudhra_signing_cert.arn,
          aws_secretsmanager_secret.tsa_credentials.arn,
          aws_secretsmanager_secret.ai_provider_key.arn,
          aws_secretsmanager_secret.redis_auth_token.arn
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# ECS Task Role (application identity)
# -----------------------------------------------------------------------------

resource "aws_iam_role" "ecs_task" {
  name = "${local.name_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-ecs-task-role"
  }
}

# S3 access for evidence, PDFs, packages, backups
resource "aws_iam_role_policy" "ecs_task_s3" {
  name   = "${local.name_prefix}-ecs-task-s3"
  role   = aws_iam_role.ecs_task.id
  policy = local.ecs_task_s3_policy
}

# Secrets Manager access
resource "aws_iam_role_policy" "ecs_task_secrets" {
  name   = "${local.name_prefix}-ecs-task-secrets"
  role   = aws_iam_role.ecs_task.id
  policy = local.ecs_task_secrets_policy
}

# -----------------------------------------------------------------------------
# ECS Task Execution Role (pull images, write logs)
# -----------------------------------------------------------------------------

resource "aws_iam_role" "ecs_execution" {
  name = "${local.name_prefix}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-ecs-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Execution role needs Secrets Manager for db password etc.
resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "${local.name_prefix}-ecs-execution-secrets"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.db_password.arn,
          aws_secretsmanager_secret.redis_auth_token.arn
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# EC2 Instance Role (for EC2-based deployments)
# -----------------------------------------------------------------------------

resource "aws_iam_role" "ec2" {
  count = var.environment == "dev" ? 1 : 0

  name = "${local.name_prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-ec2-role"
  }
}

resource "aws_iam_instance_profile" "ec2" {
  count = var.environment == "dev" ? 1 : 0

  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2[0].name
}

resource "aws_iam_role_policy" "ec2_s3" {
  count = var.environment == "dev" ? 1 : 0

  name   = "${local.name_prefix}-ec2-s3"
  role   = aws_iam_role.ec2[0].id
  policy = local.ecs_task_s3_policy
}

resource "aws_iam_role_policy" "ec2_secrets" {
  count = var.environment == "dev" ? 1 : 0

  name   = "${local.name_prefix}-ec2-secrets"
  role   = aws_iam_role.ec2[0].id
  policy = local.ecs_task_secrets_policy
}
