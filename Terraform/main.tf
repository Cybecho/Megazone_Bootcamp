
# main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# --- Data Sources ---

data "aws_availability_zones" "available" {
  state = "available"
}

# Use SSM Parameter Store to get the latest Amazon Linux 2023 AMI ID dynamically
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-*-x86_64"] # Adjust filter if needed
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  # Determine the AMI ID to use - prioritize var.ami_id if set, otherwise use the dynamic lookup
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2023.id
  # Ensure we don't request more AZs than available or needed for subnets
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
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
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index] # Assigns 1st CIDR to 1st AZ, 2nd to 2nd AZ

  # Enable public IP assignment for instances in public subnets
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${local.azs[count.index]}"
    Tier = "Public"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index] # Assigns 1st CIDR to 1st AZ, 2nd to 2nd AZ

  # Disable public IP assignment for instances in private subnets
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-private-subnet-${local.azs[count.index]}"
    Tier = "Private"
  }
}

# --- NAT Gateway ---
# Requires an Elastic IP
resource "aws_eip" "nat" {
  domain = "vpc" # Required for VPC EIPs since AWS provider v4.0

  tags = {
    Name = "${var.project_name}-nat-eip"
  }
  # Explicit dependency to ensure IGW is created first, though usually inferred
  depends_on = [aws_internet_gateway.igw]
}

# Create NAT Gateway in the first public subnet (as per diagram)
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Place in the first public subnet

  tags = {
    Name = "${var.project_name}-nat-gw"
  }

  # Ensure the Internet Gateway is created before the NAT Gateway
  depends_on = [aws_internet_gateway.igw]
}

# --- Routing ---

# Public Route Table (routes to Internet Gateway)
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

# Associate Public Route Table with Public Subnets
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table 1 (routes to NAT Gateway) - For AZ 1
resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project_name}-private-rt-${local.azs[0]}" # Tag with AZ name
  }
}

# Associate Private Route Table 1 with Private Subnet 1
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private[0].id
  route_table_id = aws_route_table.private_1.id
}

# Private Route Table 2 (routes to NAT Gateway) - For AZ 2
resource "aws_route_table" "private_2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project_name}-private-rt-${local.azs[1]}" # Tag with AZ name
  }
}

# Associate Private Route Table 2 with Private Subnet 2
resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private[1].id
  route_table_id = aws_route_table.private_2.id
}


# --- Security Groups ---

# Security Group for Application Load Balancer (ALB)
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP/HTTPS traffic to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Add HTTPS if needed
  # ingress {
  #   description = "Allow HTTPS from anywhere"
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# Security Group for EC2 instances in ASG
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "Allow traffic from ALB and outbound traffic"
  vpc_id      = aws_vpc.main.id

  # Allow HTTP traffic from the ALB Security Group
  ingress {
    description     = "Allow HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Allow SSH from within VPC (optional, if direct SSH needed)
  # ingress {
  #   description = "Allow SSH from within VPC"
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = [aws_vpc.main.cidr_block]
  # }

  # Allow all outbound traffic (for updates, NAT GW, RDS, SSM endpoints etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}

# Security Group for RDS Database
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow database traffic from EC2 instances"
  vpc_id      = aws_vpc.main.id

  # Allow traffic from EC2 instances Security Group on the DB port (e.g., 3306 for MySQL)
  ingress {
    description     = "Allow DB traffic from EC2 SG"
    from_port       = 3306 # Change port if using PostgreSQL (5432) or other DBs
    to_port         = 3306 # Change port if using PostgreSQL (5432) or other DBs
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  # Typically RDS doesn't need outbound access, but allow all if necessary
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# --- IAM Role for EC2 Instances (for SSM Access) ---
resource "aws_iam_role" "ec2_ssm_role" {
  count = var.enable_ssm_access ? 1 : 0
  name  = "${var.project_name}-ec2-ssm-role"
  path  = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ec2-ssm-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attach" {
  count      = var.enable_ssm_access ? 1 : 0
  role       = aws_iam_role.ec2_ssm_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  count = var.enable_ssm_access ? 1 : 0
  name  = "${var.project_name}-ec2-ssm-profile"
  role  = aws_iam_role.ec2_ssm_role[0].name

  tags = {
    Name = "${var.project_name}-ec2-ssm-profile"
  }
}

# --- Optional: VPC Endpoints for SSM (if using private subnets without NAT/IGW for SSM) ---
# This allows instances in private subnets to reach SSM APIs without going over the internet
# (Requires the IAM role/profile above)

# Security Group for VPC Endpoints
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

# SSM Endpoint
resource "aws_vpc_endpoint" "ssm" {
  count             = var.enable_ssm_access ? 1 : 0
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id # Place endpoint ENIs in private subnets
  security_group_ids = [
    aws_security_group.vpc_endpoint_sg[0].id,
  ]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-ssm-endpoint"
  }
}

# EC2 Messages Endpoint
resource "aws_vpc_endpoint" "ec2messages" {
  count             = var.enable_ssm_access ? 1 : 0
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id
  security_group_ids = [
    aws_security_group.vpc_endpoint_sg[0].id,
  ]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-ec2messages-endpoint"
  }
}

# SSM Messages Endpoint (for Session Manager)
resource "aws_vpc_endpoint" "ssmmessages" {
  count             = var.enable_ssm_access ? 1 : 0
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private[*].id
  security_group_ids = [
    aws_security_group.vpc_endpoint_sg[0].id,
  ]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-ssmmessages-endpoint"
  }
}

# --- Application Load Balancer (ALB) ---

resource "aws_lb" "alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id # Place ALB in public subnets

  enable_deletion_protection = false # Set to true for production

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name        = "${var.project_name}-app-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance" # Target EC2 instances directly

  health_check {
    enabled             = true
    interval            = 30
    path                = "/" # Default path for health check, adjust if needed
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-399" # Expect HTTP 200-399 for healthy
  }

  tags = {
    Name = "${var.project_name}-app-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# --- Auto Scaling Group (ASG) ---

resource "aws_launch_template" "app_lt" {
  name                   = "${var.project_name}-app-lt"
  image_id               = local.ami_id # Use determined AMI ID
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  # Assign IAM profile if created
  iam_instance_profile {
    name = var.enable_ssm_access ? aws_iam_instance_profile.ec2_ssm_profile[0].name : null
  }

  # Add User Data script if needed for bootstrapping (e.g., install web server)
  # user_data = filebase64("user_data.sh") # Example

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-ec2-instance"
    }
  }

  # Optional: Add EBS volume configuration if needed
  # block_device_mappings { ... }

  lifecycle {
    create_before_destroy = true # Useful for updates without downtime
  }

  tags = {
    Name = "${var.project_name}-app-lt"
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name                      = "${var.project_name}-app-asg"
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity
  vpc_zone_identifier       = aws_subnet.private[*].id         # Launch instances in private subnets
  target_group_arns         = [aws_lb_target_group.app_tg.arn] # Attach to ALB Target Group
  health_check_type         = "ELB"                            # Use ELB health checks
  health_check_grace_period = 300                              # Time for instance to start before health checks

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest" # Always use the latest version of the launch template
  }

  # Ensure instances are replaced if the launch template changes
  lifecycle {
    create_before_destroy = true
  }

  # Tag instances launched by the ASG
  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg-instance"
    propagate_at_launch = true
  }
  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  # Optional: Add scaling policies based on CPU, etc.
  # resource "aws_autoscaling_policy" "..." { ... }
  # resource "aws_cloudwatch_metric_alarm" "..." { ... }

  depends_on = [aws_lb_listener.http] # Ensure LB is ready before ASG tries to attach
}

# --- RDS Database ---

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = aws_subnet.private[*].id # RDS instances will use private subnets

  tags = {
    Name = "${var.project_name}-rds-subnet-group"
  }
}

resource "aws_db_instance" "rds_primary" {
  identifier             = "${var.project_name}-rds-primary" # Unique identifier for the RDS instance
  allocated_storage      = var.db_allocated_storage
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  parameter_group_name   = "default.${var.db_engine}${replace(var.db_engine_version, ".", "")}" # Adjust if using custom parameter group

  # Enable Multi-AZ deployment (creates standby in another AZ)
  multi_az = true

  # Other optional settings
  storage_type            = "gp3" # General Purpose SSD v3
  backup_retention_period = 7     # Keep backups for 7 days
  skip_final_snapshot     = true  # Set to false for production to take a snapshot on deletion
  publicly_accessible     = false # Ensure DB is not publicly accessible

  tags = {
    Name = "${var.project_name}-rds-primary"
    Tier = "Database"
  }
}

# Note: The 'Secondary RDS' in the diagram is achieved via the `multi_az = true` setting
# above for a single `aws_db_instance` resource. AWS manages the standby replica.
# You don't define a separate resource for the secondary *standby* in a Multi-AZ setup.
# If you needed a *read replica*, you would use `aws_db_instance` with the `replicate_source_db` argument.
