##############################################################################
# Security Groups
# mgmt-sg: Restricted access for PAN-OS management (SSH + HTTPS)
# data-sg: Permissive for lab data interfaces (lock down in production!)
##############################################################################

# ---------------------------------------------------------------------
# Management Security Group
# Only allows SSH (22) and HTTPS (443) from specified CIDRs
# ---------------------------------------------------------------------
resource "aws_security_group" "mgmt" {
  name_prefix = "${var.project_name}-mgmt-"
  description = "Allow SSH and HTTPS to PAN-OS management interface"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-mgmt-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "mgmt_https" {
  security_group_id = aws_security_group.mgmt.id
  description       = "HTTPS access to PAN-OS web UI and XML API"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = var.allowed_mgmt_cidrs[0]
}

resource "aws_vpc_security_group_ingress_rule" "mgmt_ssh" {
  security_group_id = aws_security_group.mgmt.id
  description       = "SSH access to PAN-OS CLI"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.allowed_mgmt_cidrs[0]
}

resource "aws_vpc_security_group_egress_rule" "mgmt_all" {
  security_group_id = aws_security_group.mgmt.id
  description       = "Allow all outbound from management"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------------
# Data Plane Security Group (Untrust + Trust interfaces)
# Permissive for lab — in production, restrict to known traffic
# ---------------------------------------------------------------------
resource "aws_security_group" "data" {
  name_prefix = "${var.project_name}-data-"
  description = "Permissive SG for VM-Series data interfaces (lab only)"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-data-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "data_all" {
  security_group_id = aws_security_group.data.id
  description       = "Allow all inbound to data interfaces (lab)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "data_all" {
  security_group_id = aws_security_group.data.id
  description       = "Allow all outbound from data interfaces"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
