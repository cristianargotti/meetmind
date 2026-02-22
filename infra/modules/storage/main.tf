# =============================================================================
# Module: Storage — S3 (Website + Recordings) + CloudFront CDN
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

# Keep website configuration for S3 origin compatibility
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document { suffix = "index.html" }
  error_document { key = "index.html" }
}

# Block ALL public access — CloudFront OAC is the only entry point
resource "aws_s3_bucket_public_access_block" "website" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy: Allow access ONLY from CloudFront via OAC
resource "aws_s3_bucket_policy" "website" {
  bucket     = aws_s3_bucket.website.id
  depends_on = [aws_s3_bucket_public_access_block.website]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontOAC"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.website.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.website.arn
        }
      }
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

# --- ACM Validation Records ---

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

# Wait for cert validation before CloudFront can use it
resource "aws_acm_certificate_validation" "website" {
  certificate_arn         = aws_acm_certificate.website.arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]
}

# --- CloudFront Origin Access Control (OAC) ---

resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "${var.project_name}-website-oac"
  description                       = "OAC for AuraMeet website S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# --- CloudFront Function: Redirect naked → www + directory index rewrite ---

resource "aws_cloudfront_function" "redirect_www" {
  name    = "${var.project_name}-redirect-www"
  runtime = "cloudfront-js-2.0"
  comment = "Redirect naked domain to www and rewrite directory URIs"
  publish = true
  code    = <<-EOF
    function handler(event) {
      var request = event.request;
      var host = request.headers.host.value;
      var uri = request.uri;

      // Redirect naked domain and CloudFront domain → www
      if (host === '${var.domain_name}' || host.endsWith('.cloudfront.net')) {
        return {
          statusCode: 301,
          statusDescription: 'Moved Permanently',
          headers: {
            'location': { value: 'https://www.${var.domain_name}' + uri }
          }
        };
      }

      // Rewrite directory URIs → index.html (S3 REST API doesn't do this)
      if (uri.endsWith('/')) {
        request.uri += 'index.html';
      } else if (!uri.includes('.')) {
        request.uri += '/index.html';
      }

      return request;
    }
  EOF
}

# --- CloudFront Distribution ---

resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  http_version        = "http2and3"
  price_class         = "PriceClass_100" # US, Canada, Europe (cheapest)
  comment             = "AuraMeet website CDN"

  aliases = [var.domain_name, "www.${var.domain_name}"]

  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.website.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website.id}"
    compress         = true

    viewer_protocol_policy = "redirect-to-https"

    # Use managed CachingOptimized policy (recommended)
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.redirect_www.arn
    }
  }

  # Static assets with long TTL
  ordered_cache_behavior {
    path_pattern     = "_assets/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website.id}"
    compress         = true

    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
  }

  # SPA/i18n fallback: 404 → index.html for client-side routing
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.website.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  depends_on = [aws_acm_certificate_validation.website]

  tags = { Component = "cdn" }
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

output "cdn_domain_name" {
  value = aws_cloudfront_distribution.website.domain_name
}

output "cdn_distribution_id" {
  value = aws_cloudfront_distribution.website.id
}

output "cdn_hosted_zone_id" {
  value = aws_cloudfront_distribution.website.hosted_zone_id
}

output "website_bucket_arn" {
  value = aws_s3_bucket.website.arn
}
