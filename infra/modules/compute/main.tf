# =============================================================================
# Module: Compute — App Runner (Graviton ARM, Scale to Zero)
# =============================================================================

# IAM Role: App Runner → ECR pull ---

resource "aws_iam_role" "access" {
  name = "${var.project_name}-apprunner-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "build.apprunner.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.access.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# --- IAM Role: App Runner instance (runtime) ---

resource "aws_iam_role" "instance" {
  name = "${var.project_name}-apprunner-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "tasks.apprunner.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "instance_ssm" {
  name = "ssm-read"
  role = aws_iam_role.instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath"
      ]
      Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/*"
    }]
  })
}

resource "aws_iam_role_policy" "instance_s3" {
  name = "s3-access"
  role = aws_iam_role.instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
      Resource = "arn:aws:s3:::${var.project_name}-recordings/*"
    }]
  })
}

# --- Auto Scaling ---

resource "aws_apprunner_auto_scaling_configuration_version" "main" {
  auto_scaling_configuration_name = "${var.project_name}-scaling"
  max_concurrency                 = var.max_concurrency
  max_size                        = var.max_instances
  min_size                        = var.min_instances

  tags = { Component = "compute" }
}

# --- App Runner Service ---

resource "aws_apprunner_service" "main" {
  service_name = "${var.project_name}-api"

  source_configuration {
    auto_deployments_enabled = true

    authentication_configuration {
      access_role_arn = aws_iam_role.access.arn
    }

    image_repository {
      image_identifier      = "${var.ecr_repo_url}:latest"
      image_repository_type = "ECR"

      image_configuration {
        port = "8000"

        runtime_environment_variables = {
          MEETMIND_ENVIRONMENT      = "production"
          MEETMIND_DATABASE_URL     = var.database_url
          MEETMIND_OPENAI_API_KEY   = var.openai_api_key
          MEETMIND_OPENAI_BASE_URL  = "https://api.groq.com/openai/v1"
          MEETMIND_JWT_SECRET_KEY   = var.jwt_secret_key
          MEETMIND_GOOGLE_CLIENT_ID = var.google_client_id
          MEETMIND_LLM_PROVIDER     = "openai"
          MEETMIND_CORS_ORIGINS     = var.cors_origins
          MEETMIND_LOG_LEVEL        = "INFO"
          MEETMIND_DEBUG            = "false"
          SENTRY_DSN                = var.sentry_dsn
        }
      }
    }
  }

  instance_configuration {
    cpu               = tostring(var.cpu)
    memory            = tostring(var.memory)
    instance_role_arn = aws_iam_role.instance.arn
  }

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.main.arn

  network_configuration {
    egress_configuration {
      egress_type       = "VPC"
      vpc_connector_arn = var.vpc_connector_arn
    }
  }

  health_check_configuration {
    protocol            = "HTTP"
    path                = "/health"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 1
    unhealthy_threshold = 5
  }

  tags = { Component = "compute" }
}


# --- Custom Domain Association (SSL) ---

resource "aws_apprunner_custom_domain_association" "api" {
  service_arn          = aws_apprunner_service.main.arn
  domain_name          = "api.${var.domain_name}"
  enable_www_subdomain = false
}
