# ============================================================================
# MeetMind — Terraform Variables
# ============================================================================

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "meetmind"
}

variable "environment" {
  description = "Deployment environment (dev/staging/production)"
  type        = string
  default     = "production"
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = "mibaggy-co"
}

# --- EC2 ---

variable "instance_type" {
  description = "EC2 instance type (t3.small = 2 vCPU, 2GB, ~$15/mo)"
  type        = string
  default     = "t3.small"
}

variable "key_pair_name" {
  description = "SSH key pair name for EC2 access"
  type        = string
}

variable "admin_cidr" {
  description = "CIDR block for SSH access (your IP/32, e.g. 190.85.x.x/32)"
  type        = string
}

# --- Secrets (passed via -var or .tfvars, never committed) ---

variable "openai_api_key" {
  description = "OpenAI API key (stored in SSM SecureString)"
  type        = string
  sensitive   = true
}

variable "huggingface_token" {
  description = "HuggingFace token for pyannote models"
  type        = string
  sensitive   = true
  default     = ""
}

# --- Domain ---

variable "domain_name" {
  description = "Domain name for Caddy HTTPS (e.g., meetmind.crisreyes.co)"
  type        = string
  default     = "meetmind.example.com"
}
