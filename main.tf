##############################################################################
# Provider & Data Sources — Palo Alto VM-Series on AWS (Layer 1)
# CloudBats x Palo Alto Networks
##############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

# ---------------------------------------------------------------------
# Data Sources
# ---------------------------------------------------------------------

# Current AWS account info (for tagging and IAM)
data "aws_caller_identity" "current" {}

# Dynamically find the latest VM-Series PAYG AMI
# Product code: hd44w1chf26uv4p52cdynb2o (Advanced Security Subs PAYG)
# Subscription Product ID: 0825b781-215f-4686-8da2-b95275cc8dd0
data "aws_ami" "vmseries" {
  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "product-code"
    values = ["hd44w1chf26uv4p52cdynb2o"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
