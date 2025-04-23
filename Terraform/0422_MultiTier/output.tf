
# outputs.tf

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.alb.dns_name
}

output "alb_zone_id" {
  description = "Route 53 zone ID of the Application Load Balancer"
  value       = aws_lb.alb.zone_id
}

output "rds_endpoint" {
  description = "Endpoint address of the RDS database instance"
  value       = aws_db_instance.rds_primary.endpoint
  sensitive   = false # Endpoint itself isn't sensitive, credentials are
}

output "rds_port" {
  description = "Port the RDS database instance is listening on"
  value       = aws_db_instance.rds_primary.port
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.app_asg.name
}

output "ec2_instance_ami" {
  description = "AMI ID used for EC2 instances"
  value       = local.ami_id
}
