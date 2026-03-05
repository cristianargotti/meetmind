output "ses_domain_identity_arn" {
  description = "ARN of the SES domain identity"
  value       = aws_ses_domain_identity.main.arn
}

output "ses_domain_verification_token" {
  description = "Domain verification token (for manual DNS verification if needed)"
  value       = aws_ses_domain_identity.main.verification_token
  sensitive   = true
}

output "ses_sender_address" {
  description = "Recommended sender address for this domain"
  value       = "noreply@${var.domain_name}"
}
