
# variables.tf

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "A prefix used for naming resources"
  type        = string
  default     = "mzc-user05" # Using hyphens is generally safer for more resource types than underscores
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.10.0.0/16" # Based on the diagram's VPC label
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  # Based on the diagram's subnet labels within the 10.10.0.0/16 VPC
  default = ["10.10.1.0/24", "10.10.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  # Based on the diagram's subnet labels
  default = ["10.10.128.0/22", "10.10.132.0/22"]
}

variable "instance_type" {
  description = "EC2 instance type for the Auto Scaling Group"
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 4
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 2
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS instance in GB"
  type        = number
  default     = 20
}

variable "db_engine" {
  description = "RDS database engine"
  type        = string
  default     = "mysql" # Example, change if needed (e.g., postgres)
}

variable "db_engine_version" {
  description = "RDS database engine version"
  type        = string
  default     = "8.0" # Example, use appropriate version for MySQL 8.0
}

variable "db_name" {
  description = "Name for the RDS database"
  type        = string
  default     = "mydatabase"
}

variable "db_username" {
  description = "Username for the RDS database master user"
  type        = string
  default     = "adminuser"
}

variable "db_password" {
  description = "Password for the RDS database master user"
  type        = string
  sensitive   = true # Mark as sensitive, won't be shown in outputs
  # Provide this value in terraform.tfvars or via environment variable/prompt
}

variable "ami_id" {
  description = "AMI ID for EC2 instances. Uses latest Amazon Linux 2023 by default."
  type        = string
  default     = "" # Keep empty to use the data source lookup
}

variable "enable_ssm_access" {
  description = "Set to true to create IAM role/profile for SSM access and VPC Endpoints"
  type        = bool
  default     = true # Recommended for management without SSH keys/Bastion
}
