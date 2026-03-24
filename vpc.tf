##############################################################################
# VPC & Networking — Three-Subnet Architecture
# Management (mgmt), Untrust (public), Trust (private)
##############################################################################

# ---------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ---------------------------------------------------------------------
# Internet Gateway
# ---------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ---------------------------------------------------------------------
# Subnets (single AZ lab deployment)
# ---------------------------------------------------------------------
resource "aws_subnet" "mgmt" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.mgmt_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name = "${var.project_name}-mgmt-subnet"
  }
}

resource "aws_subnet" "untrust" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.untrust_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name = "${var.project_name}-untrust-subnet"
  }
}

resource "aws_subnet" "trust" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.trust_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name = "${var.project_name}-trust-subnet"
  }
}

# ---------------------------------------------------------------------
# Route Tables
# ---------------------------------------------------------------------

# Public route table (mgmt + untrust) — default route to IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "mgmt" {
  subnet_id      = aws_subnet.mgmt.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "untrust" {
  subnet_id      = aws_subnet.untrust.id
  route_table_id = aws_route_table.public.id
}

# Private route table (trust) — default route to VM-Series trust ENI
# This steers all trust-subnet traffic through the firewall
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route" "trust_default" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.trust.id
}

resource "aws_route_table_association" "trust" {
  subnet_id      = aws_subnet.trust.id
  route_table_id = aws_route_table.private.id
}
