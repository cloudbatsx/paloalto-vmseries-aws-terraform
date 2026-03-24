##############################################################################
# Outputs — Key values for validation and Layer 2 connectivity
##############################################################################

output "vmseries_instance_id" {
  description = "EC2 instance ID of the VM-Series firewall"
  value       = aws_instance.vmseries.id
}

output "management_eip" {
  description = "Public IP for PAN-OS management (Web UI + API). Login: admin / <instance-id>"
  value       = aws_eip.mgmt.public_ip
}

output "management_url" {
  description = "URL to access PAN-OS web UI"
  value       = "https://${aws_eip.mgmt.public_ip}"
}

output "mgmt_private_ip" {
  description = "Private IP of the management ENI"
  value       = aws_network_interface.mgmt.private_ip
}

output "untrust_private_ip" {
  description = "Private IP of the untrust ENI (ethernet1/1)"
  value       = aws_network_interface.untrust.private_ip
}

output "trust_private_ip" {
  description = "Private IP of the trust ENI (ethernet1/2)"
  value       = aws_network_interface.trust.private_ip
}

output "ami_id" {
  description = "AMI ID used for the VM-Series instance"
  value       = data.aws_ami.vmseries.id
}

output "bootstrap_bucket" {
  description = "S3 bucket name used for bootstrap"
  value       = aws_s3_bucket.bootstrap.id
}

output "ssh_command" {
  description = "SSH command to connect and set admin password"
  value       = "ssh -i vmseries-key.pem admin@${aws_eip.mgmt.public_ip}"
}

output "password_setup_instructions" {
  description = "Steps to set PAN-OS admin password (required for PAYG images)"
  value       = <<-EOT
    1. Wait 10-15 min after deploy for PAN-OS to fully boot
    2. SSH in: ssh -i vmseries-key.pem admin@${aws_eip.mgmt.public_ip}
    3. Run: configure
    4. Run: set mgt-config users admin password
    5. Enter your desired password (8+ chars, mixed case + number/special)
    6. Run: commit
    7. Browse to https://${aws_eip.mgmt.public_ip} and login with admin/<your-password>
  EOT
}

# Outputs needed by Layer 2 (PAN-OS Terraform provider)
output "layer2_connection_info" {
  description = "Connection info for the PAN-OS provider in Layer 2"
  value = {
    hostname      = aws_eip.mgmt.public_ip
    username      = "admin"
    password_hint = "Use the EC2 instance ID as the password"
    instance_id   = aws_instance.vmseries.id
    untrust_ip    = aws_network_interface.untrust.private_ip
    trust_ip      = aws_network_interface.trust.private_ip
    untrust_gw    = cidrhost(var.untrust_subnet_cidr, 1)
    trust_gw      = cidrhost(var.trust_subnet_cidr, 1)
  }
}
