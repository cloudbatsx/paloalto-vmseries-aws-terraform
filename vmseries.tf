##############################################################################
# VM-Series EC2 Instance — Three ENIs (mgmt, untrust, trust) + EIP
# This is the core firewall deployment.
##############################################################################

# ---------------------------------------------------------------------
# Network Interfaces (one per subnet/zone)
# ---------------------------------------------------------------------

# Management ENI — device_index 0 (default, no mgmt-interface-swap needed)
resource "aws_network_interface" "mgmt" {
  subnet_id         = aws_subnet.mgmt.id
  security_groups   = [aws_security_group.mgmt.id]
  source_dest_check = true # Management traffic only, no forwarding

  tags = {
    Name = "${var.project_name}-mgmt-eni"
  }
}

# Untrust ENI — internet-facing interface (ethernet1/1)
resource "aws_network_interface" "untrust" {
  subnet_id         = aws_subnet.untrust.id
  security_groups   = [aws_security_group.data.id]
  source_dest_check = false # CRITICAL: Must be false for firewall forwarding

  tags = {
    Name = "${var.project_name}-untrust-eni"
  }
}

# Trust ENI — internal-facing interface (ethernet1/2)
resource "aws_network_interface" "trust" {
  subnet_id         = aws_subnet.trust.id
  security_groups   = [aws_security_group.data.id]
  source_dest_check = false # CRITICAL: Must be false for firewall forwarding

  tags = {
    Name = "${var.project_name}-trust-eni"
  }
}

# ---------------------------------------------------------------------
# Elastic IP — Attached to management ENI for remote access
# ---------------------------------------------------------------------
resource "aws_eip" "mgmt" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-mgmt-eip"
  }
}

resource "aws_eip_association" "mgmt" {
  allocation_id        = aws_eip.mgmt.id
  network_interface_id = aws_network_interface.mgmt.id
}

# ---------------------------------------------------------------------
# VM-Series EC2 Instance
# ---------------------------------------------------------------------
resource "aws_instance" "vmseries" {
  ami           = data.aws_ami.vmseries.id
  instance_type = var.instance_type

  # Management interface is the primary ENI (device_index = 0)
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.mgmt.id
  }

  # Untrust interface (device_index = 1 → maps to ethernet1/1 in PAN-OS)
  network_interface {
    device_index         = 1
    network_interface_id = aws_network_interface.untrust.id
  }

  # Trust interface (device_index = 2 → maps to ethernet1/2 in PAN-OS)
  network_interface {
    device_index         = 2
    network_interface_id = aws_network_interface.trust.id
  }

  # IAM profile for S3 bootstrap access
  iam_instance_profile = aws_iam_instance_profile.vmseries.name

  # Bootstrap: tell VM-Series which S3 bucket has its Day-0 config
  user_data = base64encode(join("\n", [
    "vmseries-bootstrap-aws-s3bucket=${aws_s3_bucket.bootstrap.id}",
  ]))

  # EBS root volume
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 60
    delete_on_termination = true
  }

  tags = {
    Name = "${var.project_name}-vmseries"
  }

  # Allow time for PAN-OS to boot (5-8 minutes)
  timeouts {
    create = "15m"
  }

  depends_on = [
    aws_internet_gateway.main,
    aws_s3_object.init_cfg,
  ]
}
