variable "project_name" {
  type = string
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name (e.g. user/repo)"
}

variable "website_bucket_arn" {
  type        = string
  description = "ARN of the website S3 bucket for deployment"
}
