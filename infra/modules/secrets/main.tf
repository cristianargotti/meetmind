# =============================================================================
# Module: Secrets — SSM Parameter Store (SecureString)
# =============================================================================

variable "project_name" {
  type = string
}

variable "openai_api_key" {
  type      = string
  sensitive = true
}

variable "jwt_secret_key" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "google_client_id" {
  type      = string
  sensitive = true
  default   = ""
}

locals {
  prefix = "/${var.project_name}/production"
}

resource "aws_ssm_parameter" "openai_api_key" {
  name      = "${local.prefix}/openai-api-key"
  type      = "SecureString"
  value     = var.openai_api_key
  overwrite = true
  tags      = { Component = "secrets" }
}

resource "aws_ssm_parameter" "jwt_secret" {
  name      = "${local.prefix}/jwt-secret-key"
  type      = "SecureString"
  value     = var.jwt_secret_key
  overwrite = true
  tags      = { Component = "secrets" }
}

resource "aws_ssm_parameter" "db_password" {
  name      = "${local.prefix}/db-password"
  type      = "SecureString"
  value     = var.db_password
  overwrite = true
  tags      = { Component = "secrets" }
}

resource "aws_ssm_parameter" "google_client_id" {
  count     = var.google_client_id != "" ? 1 : 0
  name      = "${local.prefix}/google-client-id"
  type      = "SecureString"
  value     = var.google_client_id
  overwrite = true
  tags      = { Component = "secrets" }
}
