# =============================================================================
# Module: DNS — Route 53 Records
# =============================================================================

variable "domain_name" {
  type = string
}

variable "hosted_zone_id" {
  type = string
}

variable "app_runner_url" {
  type = string
}

variable "cdn_domain" {
  type = string
}

variable "validation_records" {
  type = set(object({
    name  = string
    type  = string
    value = string
  }))
  default = []
}

# --- api.aurameet.live → App Runner ---

resource "aws_route53_record" "api" {
  zone_id = var.hosted_zone_id
  name    = "api.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.app_runner_url]
}

# --- ACM Validation Records (SSL) ---

resource "aws_route53_record" "validation" {
  for_each = { for record in var.validation_records : record.name => record }

  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.value]
  allow_overwrite = true
}

# --- Outputs ---

output "api_fqdn" {
  value = aws_route53_record.api.fqdn
}
