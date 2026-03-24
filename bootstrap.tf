##############################################################################
# Bootstrap — S3 bucket with Day-0 config for VM-Series
# The firewall pulls this config at first boot, eliminating manual GUI setup.
##############################################################################

# ---------------------------------------------------------------------
# Random suffix for globally unique bucket name
# ---------------------------------------------------------------------
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# ---------------------------------------------------------------------
# S3 Bootstrap Bucket
# ---------------------------------------------------------------------
resource "aws_s3_bucket" "bootstrap" {
  bucket        = "${var.project_name}-bootstrap-${random_id.bucket_suffix.hex}"
  force_destroy = true # Lab only — allows terraform destroy to clean up

  tags = {
    Name = "${var.project_name}-bootstrap"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bootstrap" {
  bucket = aws_s3_bucket.bootstrap.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "bootstrap" {
  bucket = aws_s3_bucket.bootstrap.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------
# Bootstrap Directory Structure
# PAN-OS expects: config/, content/, license/, software/
# ---------------------------------------------------------------------

# init-cfg.txt — Day-0 settings (hostname, DNS, type)
resource "aws_s3_object" "init_cfg" {
  bucket  = aws_s3_bucket.bootstrap.id
  key     = "config/init-cfg.txt"
  content = <<-EOT
    type=dhcp-client
    hostname=${var.project_name}-fw
    dns-primary=169.254.169.253
    dns-secondary=8.8.8.8
    vm-auth-key=
    panorama-server=
    tplname=
    dgname=
    op-command-modes=jumbo-frame
  EOT

  tags = {
    Name = "${var.project_name}-init-cfg"
  }
}

# Empty placeholder directories (PAN-OS requires these folders to exist)
resource "aws_s3_object" "content_dir" {
  bucket  = aws_s3_bucket.bootstrap.id
  key     = "content/"
  content = ""
}

resource "aws_s3_object" "license_dir" {
  bucket  = aws_s3_bucket.bootstrap.id
  key     = "license/"
  content = ""
}

resource "aws_s3_object" "software_dir" {
  bucket  = aws_s3_bucket.bootstrap.id
  key     = "software/"
  content = ""
}

# ---------------------------------------------------------------------
# IAM Role — Allows the VM-Series EC2 instance to read from S3
# ---------------------------------------------------------------------
resource "aws_iam_role" "vmseries" {
  name = "${var.project_name}-vmseries-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-vmseries-role"
  }
}

resource "aws_iam_role_policy" "vmseries_bootstrap" {
  name = "${var.project_name}-bootstrap-policy"
  role = aws_iam_role.vmseries.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:ListBucket",
        "s3:GetObject"
      ]
      Resource = [
        aws_s3_bucket.bootstrap.arn,
        "${aws_s3_bucket.bootstrap.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "vmseries" {
  name = "${var.project_name}-vmseries-profile"
  role = aws_iam_role.vmseries.name
}
