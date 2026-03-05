variable "domain_name" {
  description = "The domain to verify in SES (e.g. aurameet.live)"
  type        = string
}

variable "route53_zone_id" {
  description = "The Route 53 hosted zone ID for the domain"
  type        = string
}

variable "aws_region" {
  description = "AWS region for SES (must match App Runner region)"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
}

variable "apprunner_instance_role_id" {
  description = "IAM role ID of the App Runner instance role to attach SES policy to"
  type        = string
}
