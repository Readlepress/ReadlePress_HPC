# =============================================================================
# ReadlePress CloudFront Distribution
# PDF delivery from S3 origin (readlepress-pdfs-{env})
# =============================================================================

# Origin Access Control (OAC) - recommended over OAI for S3
resource "aws_cloudfront_origin_access_control" "pdfs" {
  name                              = "${local.name_prefix}-pdfs-oac"
  description                       = "OAC for ReadlePress PDF bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 bucket policy to allow CloudFront OAC access
data "aws_iam_policy_document" "pdfs_cloudfront" {
  statement {
    sid    = "AllowCloudFrontServicePrincipal"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.pdfs.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.pdfs.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "pdfs" {
  bucket = aws_s3_bucket.pdfs.id
  policy = data.aws_iam_policy_document.pdfs_cloudfront.json
}

resource "aws_cloudfront_distribution" "pdfs" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "ReadlePress PDF delivery"
  price_class         = var.cloudfront_price_class
  default_root_object = ""
  web_acl_id          = aws_wafv2_web_acl.main.arn

  origin {
    domain_name              = aws_s3_bucket.pdfs.bucket_regional_domain_name
    origin_id                 = "S3-${aws_s3_bucket.pdfs.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.pdfs.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.pdfs.id}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id = aws_cloudfront_cache_policy.pdfs.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN", "US", "GB"] # India primary; allow common regions
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${local.name_prefix}-pdfs-cdn"
  }
}

resource "aws_cloudfront_cache_policy" "pdfs" {
  name        = "${local.name_prefix}-pdfs-cache"
  comment     = "Cache policy for PDF delivery"
  default_ttl = 86400   # 1 day
  max_ttl     = 604800  # 7 days
  min_ttl     = 3600    # 1 hour

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
  }
}
