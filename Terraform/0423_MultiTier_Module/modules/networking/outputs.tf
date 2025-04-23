# ./modules/networking/outputs.tf

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

output "vpc_endpoint_sg_id" {
  description = "The ID of the VPC Endpoint Security Group (if created)"
  value       = length(aws_security_group.vpc_endpoint_sg) > 0 ? aws_security_group.vpc_endpoint_sg[0].id : null
}
