# ============================================================================
# MeetMind — SSM Parameter Store (Secrets)
# ============================================================================

resource "aws_ssm_parameter" "openai_api_key" {
  name        = "/${var.project_name}/${var.environment}/openai-api-key"
  description = "OpenAI API Key for MeetMind LLM provider"
  type        = "SecureString"
  value       = var.openai_api_key
  overwrite   = true

  tags = {
    Component = "secrets"
  }

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "huggingface_token" {
  name        = "/${var.project_name}/${var.environment}/huggingface-token"
  description = "HuggingFace token for pyannote diarization models"
  type        = "SecureString"
  value       = var.huggingface_token != "" ? var.huggingface_token : "unused"
  overwrite   = true

  tags = {
    Component = "secrets"
  }

  lifecycle {
    ignore_changes = [value]
  }
}

output "ssm_openai_key_arn" {
  description = "ARN of the OpenAI API key SSM parameter"
  value       = aws_ssm_parameter.openai_api_key.arn
}
