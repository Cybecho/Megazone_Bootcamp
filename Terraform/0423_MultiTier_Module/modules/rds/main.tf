# ./modules/rds/main.tf

# Security Group for RDS Database
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow database traffic from EC2 instances"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow DB traffic from EC2 SG"
    # Assuming MySQL, adjust port if needed
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.ec2_sg_id] # Reference EC2 SG ID passed as variable
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-rds-sg" }
}

# DB Subnet Group
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = var.private_subnet_ids # Use private subnets

  tags = { Name = "${var.project_name}-rds-subnet-group" }
}

# RDS Database Instance
resource "aws_db_instance" "rds_primary" {
  identifier             = "${var.project_name}-rds-primary"
  allocated_storage      = var.db_allocated_storage
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  instance_class         = var.db_instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  # Ensure correct parameter group name format
  parameter_group_name = "default.${var.db_engine}${var.db_engine_version}"

  multi_az                = true
  storage_type            = "gp3"
  backup_retention_period = 7
  skip_final_snapshot     = true
  publicly_accessible     = false

  tags = {
    Name = "${var.project_name}-rds-primary"
    Tier = "Database"
  }
}
