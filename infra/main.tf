terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # TODO: Enable remote state after creating S3 bucket
  # backend "s3" {
  #   bucket  = "meetmind-terraform-state"
  #   key     = "meetmind/terraform.tfstate"
  #   region  = "us-east-1"
  #   profile = "mibaggy-co"
  # }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "meetmind"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
