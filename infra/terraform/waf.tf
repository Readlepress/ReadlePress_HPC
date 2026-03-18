# =============================================================================
# ReadlePress WAF
# SQL injection detection, rate limiting, geographic filtering (India primary)
# Associated with CloudFront for PDF delivery
# Note: WAF for CloudFront must be in us-east-1
# =============================================================================

resource "aws_wafv2_web_acl" "main" {
  provider    = aws.us_east_1
  name        = "${local.name_prefix}-waf"
  description = "ReadlePress WAF - SQL injection, rate limit, geo filter"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # SQL injection detection (AWS Managed Rule)
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }
  }

  # Rate limiting
  rule {
    name     = "RateLimitRule"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }
  }

  # Geographic filtering - allow India, US, GB; block others
  rule {
    name     = "GeoRestriction"
    priority = 3

    action {
      block {}
    }

    statement {
      not_statement {
        statement {
          or_statement {
            statement {
              geo_match_statement {
                country_codes = ["IN"]
              }
            }
            statement {
              geo_match_statement {
                country_codes = ["US"]
              }
            }
            statement {
              geo_match_statement {
                country_codes = ["GB"]
              }
            }
          }
        }
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${local.name_prefix}-waf"
  }
}
</think>

<｜tool▁calls▁begin｜><｜tool▁call▁begin｜>
StrReplace