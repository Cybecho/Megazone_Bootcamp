# ./modules/rds/outputs.tf

output "rds_endpoint" {
  description = "Endpoint address of the RDS database instance"
  value       = aws_db_instance.rds_primary.endpoint
}

output "rds_port" {
  description = "Port the RDS database instance is listening on"
  value       = aws_db_instance.rds_primary.port
}

output "rds_instance_id" {
  description = "The ID of the RDS instance"
  value       = aws_db_instance.rds_primary.id
}

output "rds_sg_id" {
  description = "The ID of the RDS Security Group"
  value       = aws_security_group.rds_sg.id
}
