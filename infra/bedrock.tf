# ============================================================================
# MeetMind — IAM for Bedrock Access
# ============================================================================

# IAM Policy: Bedrock model invocation (Haiku, Sonnet, Opus)
resource "aws_iam_policy" "bedrock_invoke" {
  name        = "${var.project_name}-${var.environment}-bedrock-invoke"
  description = "Allow invoking Bedrock models for MeetMind AI agents"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockInvokeModels"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
        ]
        Resource = [
          # Claude Haiku 3.5 — Screening ($0.05/hr)
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-3-5-haiku-20241022-v1:0",
          # Claude Sonnet 4.5 — Analysis ($0.50/hr)
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-sonnet-4-5-20250514-v1:0",
          # Claude Opus 4 — Deep Think ($1.00/hr)
          "arn:aws:bedrock:${var.aws_region}::foundation-model/anthropic.claude-opus-4-0-20250514-v1:0",
        ]
      },
      {
        Sid    = "BedrockListModels"
        Effect = "Allow"
        Action = [
          "bedrock:ListFoundationModels",
          "bedrock:GetFoundationModel",
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role for the backend (ECS/Lambda/EC2)
resource "aws_iam_role" "backend" {
  name = "${var.project_name}-${var.environment}-backend"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backend_bedrock" {
  role       = aws_iam_role.backend.name
  policy_arn = aws_iam_policy.bedrock_invoke.arn
}

# Output the role ARN for the backend
output "backend_role_arn" {
  description = "IAM role ARN for backend Bedrock access"
  value       = aws_iam_role.backend.arn
}

output "bedrock_policy_arn" {
  description = "IAM policy ARN for Bedrock model invocation"
  value       = aws_iam_policy.bedrock_invoke.arn
}
