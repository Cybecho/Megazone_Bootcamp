# ./main.tf

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
# Find the latest Amazon Linux 2023 AMI if ami_id variable is not set
data "aws_ami" "amazon_linux_2023" {
  count = var.ami_id == "" ? 1 : 0 # Only run if var.ami_id is empty

  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-*-x86_64"]
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

# Determine the final AMI ID to use
locals {
  ami_id_to_use = var.ami_id != "" ? var.ami_id : (length(data.aws_ami.amazon_linux_2023) > 0 ? data.aws_ami.amazon_linux_2023[0].id : "")
}

# --- Networking Module ---
module "networking" {
  source = "./modules/networking"

  aws_region           = var.aws_region
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  enable_ssm_access    = var.enable_ssm_access # For VPC endpoints
}

# --- ALB Module ---
module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
}

# --- Compute Module ---
module "compute" {
  source = "./modules/compute"

  project_name         = var.project_name
  vpc_id               = module.networking.vpc_id
  private_subnet_ids   = module.networking.private_subnet_ids
  target_group_arn     = module.alb.target_group_arn
  alb_sg_id            = module.alb.alb_sg_id # Pass ALB SG ID for EC2 SG rules
  instance_type        = var.instance_type
  ami_id               = local.ami_id_to_use # Pass the determined AMI ID
  asg_min_size         = var.asg_min_size
  asg_max_size         = var.asg_max_size
  asg_desired_capacity = var.asg_desired_capacity
  enable_ssm_access    = var.enable_ssm_access # For IAM role/profile
}

# --- RDS Module ---
module "rds" {
  source = "./modules/rds"

  project_name         = var.project_name
  vpc_id               = module.networking.vpc_id
  private_subnet_ids   = module.networking.private_subnet_ids
  ec2_sg_id            = module.compute.ec2_sg_id # Pass EC2 SG ID for RDS SG rules
  db_instance_class    = var.db_instance_class
  db_allocated_storage = var.db_allocated_storage
  db_engine            = var.db_engine
  db_engine_version    = var.db_engine_version
  db_name              = var.db_name
  db_username          = var.db_username
  db_password          = var.db_password # Pass the sensitive password
}
