# ReadlePress Terraform Infrastructure

AWS infrastructure for ReadlePress (ap-south-1 Mumbai). PDF specification compliant.

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured with credentials
- Variables: `db_master_username`, `db_master_password` (sensitive)

## Quick Start

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and set db_master_username, db_master_password

terraform init
terraform plan
terraform apply
```

For production, use remote state and pass secrets via environment:

```bash
export TF_VAR_db_master_username="readlepress_admin"
export TF_VAR_db_master_password="<secure-password>"
terraform apply
```

## Backend

Configure S3 backend in `main.tf` or via `-backend-config`:

```bash
terraform init -backend-config=backend.hcl
```

## Resources

| Resource | Description |
|----------|-------------|
| **VPC** | Public/private subnets, NAT gateway, security groups |
| **RDS** | PostgreSQL 16 Multi-AZ, pg_cron, pgaudit, RLS-ready |
| **S3** | evidence (SSE-KMS), pdfs, packages, backups |
| **ElastiCache** | Redis 7, auth token |
| **CloudFront** | PDF delivery from S3, WAF |
| **ALB** | Application Load Balancer with WAF |
| **Secrets Manager** | db-password, jwt-signing-key, msg91-api-key, etc. |

## DB Roles

Roles `app_rw`, `app_ro`, `audit_viewer`, `migration_runner` are created by application migrations (`db/init/00_roles.sql`), not Terraform.

## RDS Extensions

`pg_cron` and `pgaudit` require `shared_preload_libraries` (configured in parameter group). After first apply, **reboot the RDS instance** for extensions to load. Then run migrations to create extensions.

## Instance Sizing

| Environment | RDS | Redis |
|-------------|-----|-------|
| dev | db.t3.medium | cache.t3.micro |
| prod | db.r6g.large | cache.r6g.large |
