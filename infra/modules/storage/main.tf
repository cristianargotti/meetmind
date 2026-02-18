# =============================================================================
# Module: Storage — S3 (Website + Recordings)
# CloudFront will be added after AWS account verification
# =============================================================================

variable "project_name" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "hosted_zone_id" {
  type    = string
  default = ""
}

# --- S3 Bucket: Static Website (Astro build) ---

resource "aws_s3_bucket" "website" {
  bucket = "${var.project_name}-website"
  tags   = { Component = "website" }
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document { suffix = "index.html" }
  error_document { key = "index.html" }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website" {
  bucket     = aws_s3_bucket.website.id
  depends_on = [aws_s3_bucket_public_access_block.website]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.website.arn}/*"
    }]
  })
}

# --- S3 Bucket: Meeting Recordings ---

resource "aws_s3_bucket" "recordings" {
  bucket = "${var.project_name}-recordings"
  tags   = { Component = "storage" }
}

resource "aws_s3_bucket_versioning" "recordings" {
  bucket = aws_s3_bucket.recordings.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "recordings" {
  bucket = aws_s3_bucket.recordings.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "recordings" {
  bucket                  = aws_s3_bucket.recordings.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "recordings" {
  bucket = aws_s3_bucket.recordings.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"
    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }
  }
}

# --- ACM Certificate (US-East-1 for CloudFront) ---

resource "aws_acm_certificate" "website" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = ["www.${var.domain_name}"]

  tags = { Component = "cdn" }

  lifecycle {
    create_before_destroy = true
  }
}

# --- CloudFront Distribution (COMMENTED - pending AWS account verification) ---
# Uncomment after resolving AWS Support ticket for CloudFront access.

# resource "aws_cloudfront_distribution" "website" {
#   origin {
#     domain_name = aws_s3_bucket_website_configuration.website.website_endpoint
#     origin_id   = "S3-${aws_s3_bucket.website.id}"
#
#     custom_origin_config {
#       http_port              = 80
#       https_port             = 443
#       origin_protocol_policy = "http-only"
#       origin_ssl_protocols   = ["TLSv1.2"]
#     }
#   }
#
#   enabled             = true
#   is_ipv6_enabled     = true
#   default_root_object = "index.html"
#
#   aliases = [var.domain_name, "www.${var.domain_name}"]
#
#   default_cache_behavior {
#     allowed_methods  = ["GET", "HEAD"]
#     cached_methods   = ["GET", "HEAD"]
#     target_origin_id = "S3-${aws_s3_bucket.website.id}"
#
#     forwarded_values {
#       query_string = false
#       cookies { forward = "none" }
#     }
#
#     viewer_protocol_policy = "redirect-to-https"
#     min_ttl                = 0
#     default_ttl            = 3600
#     max_ttl                = 86400
#   }
#
#   viewer_certificate {
#     acm_certificate_arn      = aws_acm_certificate.website.arn
#     ssl_support_method       = "sni-only"
#     minimum_protocol_version = "TLSv1.2_2021"
#   }
#
#   restrictions {
#     geo_restriction {
#       restriction_type = "none"
#     }
#   }
#
#   tags = { Component = "cdn" }
# }

# --- ACM Validation Records (CloudFront) ---

# --- ACM Validation Records (CloudFront) ---

resource "aws_route53_record" "acm_validation" {
  for_each = toset([var.domain_name, "www.${var.domain_name}"])

  allow_overwrite = true
  zone_id         = var.hosted_zone_id
  ttl             = 60

  name = one([
    for o in aws_acm_certificate.website.domain_validation_options : o.resource_record_name
    if o.domain_name == each.key
  ])

  type = one([
    for o in aws_acm_certificate.website.domain_validation_options : o.resource_record_type
    if o.domain_name == each.key
  ])

  records = [
    one([
      for o in aws_acm_certificate.website.domain_validation_options : o.resource_record_value
      if o.domain_name == each.key
    ])
  ]
}

# --- Outputs ---

output "website_bucket" {
  value = aws_s3_bucket.website.id
}

output "website_endpoint" {
  value = aws_s3_bucket_website_configuration.website.website_endpoint
}

output "bucket_name" {
  value = aws_s3_bucket.recordings.id
}

output "bucket_arn" {
  value = aws_s3_bucket.recordings.arn
}

# CloudFront outputs (using S3 endpoint until CloudFront is enabled)
output "cdn_domain_name" {
  value = aws_s3_bucket_website_configuration.website.website_endpoint
}

output "cdn_distribution_id" {
  value = "pending-cloudfront-verification"
}

output "cdn_hosted_zone_id" {
  value = var.hosted_zone_id
}

output "website_bucket_arn" {
  value = aws_s3_bucket.website.arn
}
