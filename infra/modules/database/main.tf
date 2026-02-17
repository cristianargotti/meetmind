# =============================================================================
# Module: Database — RDS PostgreSQL (Free Tier + Graviton)
# =============================================================================

variable "project_name" {
  type = string
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro" # Graviton, Free Tier eligible
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

# --- Subnet Group ---

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db"
  subnet_ids = var.subnet_ids

  tags = { Name = "${var.project_name}-db-subnets" }
}

# --- RDS Instance ---

resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-db"
  engine         = "postgres"
  engine_version = "16.4"

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "aurameet"
  username = "aurameet"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false
  multi_az               = false # Free Tier = Single AZ

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-final-snapshot"

  # Auto minor version upgrade for security patches
  auto_minor_version_upgrade = true

  # Performance Insights (free for db.t4g.micro)
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  tags = {
    Component = "database"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# --- Outputs ---

output "endpoint" {
  value = aws_db_instance.main.endpoint
}

output "connection_url" {
  value     = "postgresql://aurameet:${var.db_password}@${aws_db_instance.main.endpoint}/aurameet"
  sensitive = true
}

output "address" {
  value = aws_db_instance.main.address
}

output "port" {
  value = aws_db_instance.main.port
}
