terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "meetmind-terraform-state"
    key    = "meetmind/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region

  # In CI, aws_profile is empty → uses EC2 instance profile.
  # Locally, set via terraform.tfvars (e.g. "mibaggy-co").
  profile = var.aws_profile != "" ? var.aws_profile : null

  default_tags {
    tags = {
      Project     = "meetmind"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
