# =============================================================================
# Aura Meet — Production Environment
# Modular composition: networking → secrets → database → compute → dns
# =============================================================================

locals {
  name = var.project_name
  tags = {
    Project     = var.project_name
    Environment = "production"
  }
}

# --- Networking ---
module "networking" {
  source       = "../../modules/networking"
  project_name = local.name
  aws_region   = var.aws_region
}

# --- Secrets (SSM Parameter Store) ---
module "secrets" {
  source           = "../../modules/secrets"
  project_name     = local.name
  openai_api_key   = var.openai_api_key
  jwt_secret_key   = var.jwt_secret_key
  db_password      = var.db_password
  google_client_id = var.google_client_id
}

# --- Database (RDS PostgreSQL — Free Tier) ---
module "database" {
  source = "../../modules/database"

  project_name      = local.name
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  db_password       = var.db_password
  vpc_id            = module.networking.vpc_id
  subnet_ids        = module.networking.private_subnet_ids
  security_group_id = module.networking.db_security_group_id
}

# --- Storage (S3 + CloudFront) ---
module "storage" {
  source       = "../../modules/storage"
  project_name = local.name
  domain_name    = var.domain_name
  hosted_zone_id = var.hosted_zone_id
}

# --- Compute (App Runner — Graviton, Scale to Zero) ---
module "compute" {
  source = "../../modules/compute"

  project_name    = local.name
  aws_region      = var.aws_region
  ecr_repo_url    = module.ecr.repository_url
  domain_name     = var.domain_name
  cpu             = var.app_runner_cpu
  memory          = var.app_runner_memory
  max_concurrency = var.app_runner_max_concurrency
  max_instances   = var.app_runner_max_instances
  min_instances   = var.app_runner_min_instances

  # Environment variables for the container
  database_url     = module.database.connection_url
  openai_api_key   = var.openai_api_key
  jwt_secret_key   = var.jwt_secret_key
  google_client_id = var.google_client_id
  cors_origins     = "https://${var.domain_name}"

  vpc_connector_arn = module.networking.vpc_connector_arn
}

# --- ECR Repository ---
module "ecr" {
  source       = "../../modules/ecr"
  project_name = local.name
}

# --- DNS (Route 53) ---
module "dns" {
  source = "../../modules/dns"

  domain_name            = var.domain_name
  hosted_zone_id         = var.hosted_zone_id
  app_runner_url         = module.compute.service_url
  cdn_domain             = module.storage.cdn_domain_name
  cdn_hosted_zone_id     = module.storage.cdn_hosted_zone_id
  validation_records     = module.compute.custom_domain_validation_records
}

# --- Monitoring ---
module "monitoring" {
  source       = "../../modules/monitoring"
  project_name = local.name
  alert_email  = "admin@aurameet.live"
}

# --- OIDC (GitHub Actions) ---
module "oidc" {
  source             = "../../modules/oidc"
  project_name       = local.name
  github_repo        = "cristianargotti/meetmind"
  website_bucket_arn = module.storage.website_bucket_arn
}
