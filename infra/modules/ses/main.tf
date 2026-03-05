# =============================================================================
# Module: SES — Email Identity + DKIM + Sending Policy
# =============================================================================
# Creates the SES domain identity for aurameet.live, auto-provisions DNS
# records in Route 53 (DKIM CNAMEs, SPF TXT, MAIL FROM MX), and attaches
# a minimal ses:SendEmail IAM policy to the existing App Runner instance role.
# Zero access keys — uses the instance role credential chain.
# =============================================================================

data "aws_caller_identity" "current" {}

# ─── Domain Identity ─────────────────────────────────────────────

resource "aws_ses_domain_identity" "main" {
  domain = var.domain_name
}

# Domain verification TXT record
resource "aws_route53_record" "ses_verification" {
  zone_id = var.route53_zone_id
  name    = "_amazonses.${var.domain_name}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.main.verification_token]
}

resource "aws_ses_domain_identity_verification" "main" {
  domain = aws_ses_domain_identity.main.id

  depends_on = [aws_route53_record.ses_verification]
}

# ─── DKIM ────────────────────────────────────────────────────────

resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

resource "aws_route53_record" "dkim" {
  count   = 3
  zone_id = var.route53_zone_id
  name    = "${aws_ses_domain_dkim.main.dkim_tokens[count.index]}._domainkey.${var.domain_name}"
  type    = "CNAME"
  ttl     = 1800
  records = ["${aws_ses_domain_dkim.main.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# ─── SPF ─────────────────────────────────────────────────────────

resource "aws_route53_record" "spf" {
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:amazonses.com ~all"]
}

# ─── MAIL FROM (DMARC alignment) ────────────────────────────────

resource "aws_ses_domain_mail_from" "main" {
  domain           = aws_ses_domain_identity.main.domain
  mail_from_domain = "mail.${var.domain_name}"
}

resource "aws_route53_record" "mail_from_mx" {
  zone_id = var.route53_zone_id
  name    = "mail.${var.domain_name}"
  type    = "MX"
  ttl     = 300
  records = ["10 feedback-smtp.${var.aws_region}.amazonses.com"]
}

resource "aws_route53_record" "mail_from_spf" {
  zone_id = var.route53_zone_id
  name    = "mail.${var.domain_name}"
  type    = "TXT"
  ttl     = 300
  records = ["v=spf1 include:amazonses.com ~all"]
}

# ─── DMARC ───────────────────────────────────────────────────────

resource "aws_route53_record" "dmarc" {
  zone_id = var.route53_zone_id
  name    = "_dmarc.${var.domain_name}"
  type    = "TXT"
  ttl     = 300
  records = ["v=DMARC1; p=quarantine; rua=mailto:dmarc@${var.domain_name}; pct=100"]
}

# ─── IAM Policy → App Runner instance role ───────────────────────

resource "aws_iam_role_policy" "ses_send" {
  name = "ses-send-email"
  role = var.apprunner_instance_role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ses:SendEmail",
        "ses:SendRawEmail"
      ]
      Resource = [
        aws_ses_domain_identity.main.arn,
        "arn:aws:ses:${var.aws_region}:${data.aws_caller_identity.current.account_id}:identity/*"
      ]
    }]
  })
}
