# =============================================================================
# Aura Meet — Production Variables
# =============================================================================

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = "aurameet"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "aurameet"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,20}$", var.project_name))
    error_message = "Project name must be lowercase alphanumeric, 3-21 chars."
  }
}

variable "domain_name" {
  description = "Primary domain"
  type        = string
  default     = "aurameet.live"
}

variable "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID"
  type        = string
  default     = "Z00591181YGSRKA76SQD9"
}

# --- Compute ---

variable "app_runner_cpu" {
  description = "App Runner vCPU (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "app_runner_memory" {
  description = "App Runner memory in MB"
  type        = number
  default     = 2048
}

variable "app_runner_max_concurrency" {
  description = "Max concurrent requests per instance"
  type        = number
  default     = 100
}

variable "app_runner_max_instances" {
  description = "Max instances for auto-scaling"
  type        = number
  default     = 25
}

variable "app_runner_min_instances" {
  description = "Min instances (0 = scale to zero)"
  type        = number
  default     = 1 # App Runner pauses automatically when idle
}

# --- Database ---

variable "db_instance_class" {
  description = "RDS instance type"
  type        = string
  default     = "db.t4g.micro" # Free Tier + Graviton
}

variable "db_allocated_storage" {
  description = "RDS storage in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.db_allocated_storage >= 20 && var.db_allocated_storage <= 100
    error_message = "DB storage must be 20-100 GB."
  }
}

# --- Secrets (from GitHub Secrets / SSM, NEVER in tfvars) ---

variable "openai_api_key" {
  description = "OpenAI API key — pass via -var or TF_VAR_"
  type        = string
  sensitive   = true
}

variable "jwt_secret_key" {
  description = "JWT signing secret — pass via -var or TF_VAR_"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "PostgreSQL master password — pass via -var or TF_VAR_"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 16
    error_message = "DB password must be at least 16 characters."
  }
}

variable "google_client_id" {
  description = "Google OAuth client ID"
  type        = string
  sensitive   = true
  default     = ""
}

variable "sentry_dsn" {
  description = "Sentry DSN for error tracking — pass via -var or TF_VAR_"
  type        = string
  sensitive   = true
  default     = ""
}
