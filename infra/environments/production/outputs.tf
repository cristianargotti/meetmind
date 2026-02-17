# =============================================================================
# Aura Meet — Production Outputs
# =============================================================================

output "app_runner_url" {
  description = "App Runner service URL"
  value       = module.compute.service_url
}

output "ecr_repository_url" {
  description = "ECR repository URL for Docker images"
  value       = module.ecr.repository_url
}

output "database_endpoint" {
  description = "RDS endpoint"
  value       = module.database.endpoint
  sensitive   = true
}

output "cdn_domain" {
  description = "CloudFront distribution domain"
  value       = module.storage.cdn_domain_name
}

output "api_domain" {
  description = "API domain name"
  value       = "api.${var.domain_name}"
}

output "s3_bucket" {
  description = "S3 bucket for recordings"
  value       = module.storage.bucket_name
}
