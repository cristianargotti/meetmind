# =============================================================================
# Module: Networking — VPC, Subnets, Security Groups, VPC Connector
# =============================================================================

variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

# --- Use default VPC (free) ---

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnets" "apprunner_compatible" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d"]
  }

  # Use default subnets (no private subnets in default VPC)
  # App Runner VPC Connector will use these
}

# --- Security Group: App Runner → RDS ---

resource "aws_security_group" "app_runner" {
  name_prefix = "${var.project_name}-apprunner-"
  description = "App Runner VPC Connector"
  vpc_id      = data.aws_vpc.default.id

  egress {
    description = "PostgreSQL to RDS"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS outbound (OpenAI, ECR)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-apprunner" }

  lifecycle {
    create_before_destroy = true
  }
}

# --- Security Group: RDS ---

resource "aws_security_group" "database" {
  name_prefix = "${var.project_name}-db-"
  description = "RDS PostgreSQL - accept from App Runner only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "PostgreSQL from App Runner"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_runner.id]
  }

  tags = { Name = "${var.project_name}-db" }

  lifecycle {
    create_before_destroy = true
  }
}

# --- VPC Connector (App Runner → VPC) ---

resource "aws_apprunner_vpc_connector" "main" {
  vpc_connector_name = "${var.project_name}-vpc"
  subnets            = data.aws_subnets.apprunner_compatible.ids
  security_groups    = [aws_security_group.app_runner.id]

  tags = { Name = "${var.project_name}-vpc-connector" }
}

# --- Outputs ---

output "vpc_id" {
  value = data.aws_vpc.default.id
}

output "private_subnet_ids" {
  value = data.aws_subnets.apprunner_compatible.ids
}

output "db_security_group_id" {
  value = aws_security_group.database.id
}

output "app_runner_security_group_id" {
  value = aws_security_group.app_runner.id
}

output "vpc_connector_arn" {
  value = aws_apprunner_vpc_connector.main.arn
}
