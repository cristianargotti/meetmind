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

# Placeholder until CloudFront is enabled
output "cdn_domain_name" {
  value = aws_s3_bucket_website_configuration.website.website_endpoint
}

output "cdn_distribution_id" {
  value = "pending-cloudfront-verification"
}

output "website_bucket_arn" {
  value = aws_s3_bucket.website.arn
}
