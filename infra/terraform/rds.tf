# =============================================================================
# ReadlePress RDS PostgreSQL 16 Multi-AZ
# Extensions: pgcrypto, pg_cron, pgaudit
# Row Level Security enabled via application migrations (R__rls_policies.sql)
# DB roles (app_rw, app_ro, audit_viewer, migration_runner) via db/init/00_roles.sql
# =============================================================================

resource "aws_db_parameter_group" "main" {
  name        = "${local.name_prefix}-pg16-params"
  family      = "postgres16"
  description = "ReadlePress PostgreSQL 16 parameter group - RLS, pg_cron, pgaudit"

  # pg_cron and pgaudit require shared_preload_libraries
  parameter {
    name  = "shared_preload_libraries"
    value = "pg_cron,pgaudit"
  }

  # Force SSL for connections
  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  # pgaudit: log DDL and DML
  parameter {
    name  = "pgaudit.log"
    value = "ddl, write"
  }

  tags = {
    Name = "${local.name_prefix}-pg16-params"
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${local.name_prefix}-db-subnet"
  }
}

resource "aws_db_instance" "main" {
  identifier     = "${local.name_prefix}-db"
  engine         = "postgres"
  engine_version = "16.4"

  instance_class    = local.rds_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_master_username
  password = var.db_master_password
  port     = 5432

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  parameter_group_name = aws_db_parameter_group.main.name

  max_allocated_storage = var.db_max_allocated_storage
  backup_retention_period = var.environment == "prod" ? 30 : 7
  backup_window         = "03:00-04:00"
  maintenance_window    = "sun:04:00-sun:05:00"

  skip_final_snapshot = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${local.name_prefix}-final-snapshot" : null

  performance_insights_enabled = var.environment == "prod"
  performance_insights_retention_period = var.environment == "prod" ? 7 : null

  tags = {
    Name = "${local.name_prefix}-db"
  }
}

# -----------------------------------------------------------------------------
# Extensions (pgcrypto, pg_cron, pgaudit) are created by application migrations
# in db/migrations and db/init. pg_cron and pgaudit require shared_preload_
# libraries (configured above). pgcrypto is loaded on demand.
# -----------------------------------------------------------------------------
