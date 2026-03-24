##############################################################################
# Variables — Palo Alto VM-Series on AWS (Layer 1: Infrastructure)
# CloudBats x Palo Alto Networks
##############################################################################

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "cloudbats-pan"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.100.0.0/16"
}

variable "mgmt_subnet_cidr" {
  description = "CIDR block for the management subnet"
  type        = string
  default     = "10.100.1.0/24"
}

variable "untrust_subnet_cidr" {
  description = "CIDR block for the untrust (public) subnet"
  type        = string
  default     = "10.100.2.0/24"
}

variable "trust_subnet_cidr" {
  description = "CIDR block for the trust (private) subnet"
  type        = string
  default     = "10.100.3.0/24"
}

variable "availability_zone" {
  description = "AZ for all subnets (single-AZ lab deployment)"
  type        = string
  default     = "us-west-2a"
}

variable "instance_type" {
  description = "EC2 instance type for VM-Series (minimum m5.xlarge)"
  type        = string
  default     = "m5.xlarge"
}

variable "allowed_mgmt_cidrs" {
  description = "CIDR blocks allowed to access the management interface (SSH + HTTPS)"
  type        = list(string)
  default     = ["0.0.0.0/0"] # LOCK THIS DOWN to your IP in terraform.tfvars!
}

variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH access (optional, PAN-OS uses password auth)"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "CloudBats-PaloAlto-Lab"
    Environment = "lab"
    ManagedBy   = "terraform"
    Owner       = "cloudbatsx"
  }
}
