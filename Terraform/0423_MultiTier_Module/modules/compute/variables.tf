# ./modules/compute/variables.tf

variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EC2 instances"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ARN of the ALB Target Group to attach ASG instances"
  type        = string
}

variable "alb_sg_id" {
  description = "ID of the ALB's security group (for EC2 SG rules)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "asg_min_size" {
  description = "Minimum ASG size"
  type        = number
}

variable "asg_max_size" {
  description = "Maximum ASG size"
  type        = number
}

variable "asg_desired_capacity" {
  description = "Desired ASG capacity"
  type        = number
}

variable "enable_ssm_access" {
  description = "Flag to enable creation of IAM role/profile for SSM"
  type        = bool
  default     = true
}
