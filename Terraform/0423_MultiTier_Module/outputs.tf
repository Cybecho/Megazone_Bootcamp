# ./outputs.tf

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets"
  value       = module.networking.private_subnet_ids
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Route 53 zone ID of the Application Load Balancer"
  value       = module.alb.alb_zone_id
}

output "rds_endpoint" {
  description = "Endpoint address of the RDS database instance"
  value       = module.rds.rds_endpoint
}

output "rds_port" {
  description = "Port the RDS database instance is listening on"
  value       = module.rds.rds_port
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.compute.asg_name
}

output "ec2_instance_ami" {
  description = "AMI ID used for EC2 instances"
  value       = local.ami_id_to_use # Use the determined AMI ID from root main.tf
}
