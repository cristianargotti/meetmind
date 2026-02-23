# =============================================================================
# Module: Database — Aurora Serverless v2 (Auto-scaling PostgreSQL)
# =============================================================================

variable "project_name" {
  type = string
}

variable "min_capacity" {
  description = "Minimum ACUs (0.5 ACU = ~1GB RAM). Set to 0 for scale-to-zero."
  type        = number
  default     = 0.5
}

variable "max_capacity" {
  description = "Maximum ACUs (1 ACU = ~2GB RAM). Scales automatically up to this."
  type        = number
  default     = 16
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

# --- Aurora Serverless v2 Cluster ---

resource "aws_rds_cluster" "main" {
  cluster_identifier = "${var.project_name}-db"
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned" # v2 uses provisioned mode
  engine_version     = "16.4"

  database_name   = "aurameet"
  master_username = "aurameet"
  master_password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]

  storage_encrypted = true

  # Auto-scaling configuration
  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"

  skip_final_snapshot = true # No data to preserve (app not live)

  tags = {
    Component = "database"
  }
}

# --- Aurora Serverless v2 Instance ---

resource "aws_rds_cluster_instance" "main" {
  identifier         = "${var.project_name}-db-1"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless" # Auto-scales via cluster config
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  publicly_accessible = false

  # Performance Insights (free tier)
  performance_insights_enabled          = true
  performance_insights_retention_period = 7

  tags = {
    Component = "database"
  }
}

# --- Outputs ---

output "endpoint" {
  value = aws_rds_cluster.main.endpoint
}

output "connection_url" {
  value     = "postgresql://aurameet:${var.db_password}@${aws_rds_cluster.main.endpoint}/aurameet"
  sensitive = true
}

output "address" {
  value = aws_rds_cluster.main.endpoint
}

output "port" {
  value = aws_rds_cluster.main.port
}
