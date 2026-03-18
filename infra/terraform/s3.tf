# =============================================================================
# ReadlePress S3 Buckets
# readlepress-evidence-{env}, readlepress-pdfs-{env}, readlepress-packages-{env},
# readlepress-backups-{env}
# SSE-S3 default; SSE-KMS for evidence. Versioning enabled.
# =============================================================================

# -----------------------------------------------------------------------------
# KMS Key for Evidence Bucket (SSE-KMS)
# -----------------------------------------------------------------------------

resource "aws_kms_key" "evidence" {
  description             = "ReadlePress evidence bucket encryption"
  deletion_window_in_days = 7

  tags = {
    Name = "${local.name_prefix}-evidence-kms"
  }
}

resource "aws_kms_alias" "evidence" {
  name          = "alias/readlepress-evidence-${var.environment}"
  target_key_id = aws_kms_key.evidence.key_id
}

# -----------------------------------------------------------------------------
# Evidence Bucket (SSE-KMS)
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "evidence" {
  bucket = "readlepress-evidence-${var.environment}"

  tags = {
    Name = "readlepress-evidence-${var.environment}"
  }
}

resource "aws_s3_bucket_versioning" "evidence" {
  bucket = aws_s3_bucket.evidence.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "evidence" {
  bucket = aws_s3_bucket.evidence.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.evidence.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "evidence" {
  bucket = aws_s3_bucket.evidence.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "evidence" {
  bucket = aws_s3_bucket.evidence.id

  rule {
    id     = "transition-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# -----------------------------------------------------------------------------
# PDFs Bucket (SSE-S3)
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "pdfs" {
  bucket = "readlepress-pdfs-${var.environment}"

  tags = {
    Name = "readlepress-pdfs-${var.environment}"
  }
}

resource "aws_s3_bucket_versioning" "pdfs" {
  bucket = aws_s3_bucket.pdfs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pdfs" {
  bucket = aws_s3_bucket.pdfs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "pdfs" {
  bucket = aws_s3_bucket.pdfs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "pdfs" {
  bucket = aws_s3_bucket.pdfs.id

  rule {
    id     = "transition-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 180
    }
  }
}

# -----------------------------------------------------------------------------
# Packages Bucket (SSE-S3)
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "packages" {
  bucket = "readlepress-packages-${var.environment}"

  tags = {
    Name = "readlepress-packages-${var.environment}"
  }
}

resource "aws_s3_bucket_versioning" "packages" {
  bucket = aws_s3_bucket.packages.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "packages" {
  bucket = aws_s3_bucket.packages.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "packages" {
  bucket = aws_s3_bucket.packages.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# Backups Bucket (SSE-S3)
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "backups" {
  bucket = "readlepress-backups-${var.environment}"

  tags = {
    Name = "readlepress-backups-${var.environment}"
  }
}

resource "aws_s3_bucket_versioning" "backups" {
  bucket = aws_s3_bucket.backups.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "backups" {
  bucket = aws_s3_bucket.backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}
