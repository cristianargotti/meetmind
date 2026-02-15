# ============================================================================
# MeetMind — EC2 Instance (Docker Host)
# Cheapest performant option: t3.small + Docker + Caddy
# ============================================================================

# --- Data sources ---

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = ["${var.aws_region}a"]
  }
}

# --- Security Group ---

resource "aws_security_group" "meetmind" {
  name_prefix = "${var.project_name}-"
  description = "MeetMind backend - HTTPS, HTTP, SSH"
  vpc_id      = data.aws_vpc.default.id

  # HTTPS (Caddy)
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP (Caddy redirect to HTTPS + ACME challenge)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH (restricted to admin IP)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    description = "HTTPS outbound (OpenAI API, ECR, SSM)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP outbound (package updates)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Component = "networking"
  }
}

# --- IAM Role (ECR pull + SSM read) ---

resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecr_pull" {
  name = "ecr-pull"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ssm_read" {
  name = "ssm-read"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SSMRead"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2"
  role = aws_iam_role.ec2.name
}

# --- EC2 Instance ---

resource "aws_instance" "meetmind" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.meetmind.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  # Enforce IMDSv2 (prevent SSRF credential theft)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Install Docker
    dnf update -y
    dnf install -y docker
    systemctl enable docker
    systemctl start docker

    # Install Docker Compose plugin
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
      -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

    # Add ec2-user to docker group
    usermod -aG docker ec2-user

    # Install AWS CLI v2 (for ECR login)
    dnf install -y aws-cli

    # Create app directory
    mkdir -p /opt/meetmind
    chown ec2-user:ec2-user /opt/meetmind

    echo "MeetMind server provisioned successfully" > /opt/meetmind/READY
  EOF

  tags = {
    Name      = "${var.project_name}-${var.environment}"
    Component = "compute"
  }
}

# --- Elastic IP ---

resource "aws_eip" "meetmind" {
  instance = aws_instance.meetmind.id
  domain   = "vpc"

  tags = {
    Name      = "${var.project_name}-${var.environment}"
    Component = "networking"
  }
}

# --- Outputs ---

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.meetmind.id
}

output "public_ip" {
  description = "Elastic IP address — point your DNS here"
  value       = aws_eip.meetmind.public_ip
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_eip.meetmind.public_ip}"
}
