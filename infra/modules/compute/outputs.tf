output "service_url" {
  value = aws_apprunner_service.main.service_url
}

output "service_arn" {
  value = aws_apprunner_service.main.arn
}

output "service_id" {
  value = aws_apprunner_service.main.service_id
}

output "custom_domain_validation_records" {
  value = aws_apprunner_custom_domain_association.api.certificate_validation_records
}

output "instance_role_id" {
  description = "IAM role ID of the App Runner instance role (used by SES module)"
  value       = aws_iam_role.instance.id
}
