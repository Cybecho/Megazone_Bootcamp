# ./modules/networking/main.tf

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Ensure we don't request more AZs than available or needed for subnets
  num_public_subnets  = length(var.public_subnet_cidrs)
  num_private_subnets = length(var.private_subnet_cidrs)
  num_azs_needed      = max(local.num_public_subnets, local.num_private_subnets)
  available_azs       = data.aws_availability_zones.available.names
  azs                 = slice(local.available_azs, 0, local.num_azs_needed)
}

# --- Networking ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy     = "default"

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  count      = local.num_public_subnets
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidrs[count.index]
  # Cycle through AZs if fewer AZs than subnets, otherwise direct map
  availability_zone       = local.azs[count.index % length(local.azs)]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${local.azs[count.index % length(local.azs)]}"
    Tier = "Public"
  }
}

resource "aws_subnet" "private" {
  count                   = local.num_private_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index % length(local.azs)]
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-private-subnet-${local.azs[count.index % length(local.azs)]}"
    Tier = "Private"
  }
}

# --- NAT Gateway ---
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "${var.project_name}-nat-eip"
  }
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  # Only create NAT GW if there are public subnets
  count         = local.num_public_subnets > 0 ? 1 : 0
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Place in the first public subnet

  tags = {
    Name = "${var.project_name}-nat-gw"
  }
  depends_on = [aws_internet_gateway.igw]
}

# --- Routing ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = local.num_public_subnets
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Private Routing (Simplified: One RT for all private subnets pointing to NAT) ---
resource "aws_route_table" "private" {
  # Only create if NAT GW exists
  count  = length(aws_nat_gateway.nat) > 0 ? 1 : 0
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[0].id
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_route_table.private) > 0 ? local.num_private_subnets : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

# --- Optional: VPC Endpoints for SSM ---
resource "aws_security_group" "vpc_endpoint_sg" {
  count       = var.enable_ssm_access ? 1 : 0
  name        = "${var.project_name}-vpc-endpoint-sg"
  description = "Allow HTTPS from within VPC for Interface Endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project_name}-vpc-endpoint-sg"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  count               = var.enable_ssm_access && local.num_private_subnets > 0 ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint_sg[0].id]
  private_dns_enabled = true
  tags                = { Name = "${var.project_name}-ssm-endpoint" }
}

resource "aws_vpc_endpoint" "ec2messages" {
  count               = var.enable_ssm_access && local.num_private_subnets > 0 ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint_sg[0].id]
  private_dns_enabled = true
  tags                = { Name = "${var.project_name}-ec2messages-endpoint" }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  count               = var.enable_ssm_access && local.num_private_subnets > 0 ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoint_sg[0].id]
  private_dns_enabled = true
  tags                = { Name = "${var.project_name}-ssmmessages-endpoint" }
}
