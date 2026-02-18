variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "ecr_repo_url" {
  type = string
}

variable "domain_name" {
  type = string
}

variable "cpu" {
  type    = number
  default = 2048 # 2 vCPU — required for Parakeet ONNX inference
}

variable "memory" {
  type    = number
  default = 4096 # 4 GB — Parakeet INT8 model + inference buffers
}

variable "max_concurrency" {
  type    = number
  default = 100
}

variable "max_instances" {
  type    = number
  default = 25
}

variable "min_instances" {
  type    = number
  default = 1 # App Runner pauses automatically when idle (scale-to-zero)
}

variable "database_url" {
  type      = string
  sensitive = true
}

variable "openai_api_key" {
  type      = string
  sensitive = true
}

variable "jwt_secret_key" {
  type      = string
  sensitive = true
}

variable "google_client_id" {
  type      = string
  sensitive = true
  default   = ""
}

variable "cors_origins" {
  type    = string
  default = "https://aurameet.live"
}

variable "vpc_connector_arn" {
  type = string
}

variable "sentry_dsn" {
  type      = string
  sensitive = true
  default   = ""
}
