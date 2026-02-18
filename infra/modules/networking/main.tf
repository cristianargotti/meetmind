# =============================================================================
# Module: Networking — VPC, Subnets, NAT Gateway, Security Groups, VPC Connector
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

# Get the first two default (public) subnets for NAT Gateway and other resources
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b"]
  }
}

# Get the default Internet Gateway for the default VPC
data "aws_internet_gateway" "default" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# =============================================================================
# NAT Gateway — Auto-scaling, zero ops, $32/mo
# =============================================================================

# Elastic IP for NAT Gateway (static public IP)
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.project_name}-nat-eip" }
}

# NAT Gateway in the first public subnet
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = tolist(data.aws_subnets.public.ids)[0]

  tags = { Name = "${var.project_name}-nat" }

  depends_on = [data.aws_internet_gateway.default]
}

# =============================================================================
# Private Subnets — For App Runner VPC Connector + RDS
# =============================================================================

resource "aws_subnet" "private_a" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.96.0/20"
  availability_zone = "us-east-1a"

  tags = { Name = "${var.project_name}-private-a" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = "172.31.112.0/20"
  availability_zone = "us-east-1b"

  tags = { Name = "${var.project_name}-private-b" }
}

# Route table for private subnets → NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = data.aws_vpc.default.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "${var.project_name}-private-rt" }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# =============================================================================
# Security Groups
# =============================================================================

# --- Security Group: App Runner VPC Connector ---

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
    description = "HTTPS outbound (Google, Groq, Apple APIs via NAT)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP outbound"
    from_port   = 80
    to_port     = 80
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

# --- Security Group: RDS (Private — accept from App Runner SG ONLY) ---

resource "aws_security_group" "database" {
  name_prefix = "${var.project_name}-db-"
  description = "RDS PostgreSQL - accept from App Runner only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "PostgreSQL from App Runner only"
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

# =============================================================================
# VPC Connector — App Runner → Private Subnets → NAT Gateway → Internet
# =============================================================================

resource "aws_apprunner_vpc_connector" "main" {
  vpc_connector_name = "${var.project_name}-vpc"
  subnets            = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  security_groups    = [aws_security_group.app_runner.id]

  tags = { Name = "${var.project_name}-vpc-connector" }
}

# =============================================================================
# Outputs
# =============================================================================

output "vpc_id" {
  value = data.aws_vpc.default.id
}

output "private_subnet_ids" {
  value = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "db_subnet_ids" {
  description = "All subnets for RDS (default + private) - cannot remove in-use subnets"
  value       = concat(data.aws_subnets.default.ids, [aws_subnet.private_a.id, aws_subnet.private_b.id])
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

output "nat_gateway_id" {
  value = aws_nat_gateway.main.id
}

output "nat_eip" {
  value = aws_eip.nat.public_ip
}
