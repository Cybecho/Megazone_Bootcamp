# ./modules/compute/main.tf

# Security Group for EC2 instances in ASG
resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-ec2-sg"
  description = "Allow traffic from ALB and outbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_sg_id] # Reference ALB SG ID passed as variable
  }
  # Add other ingress rules if needed (e.g., SSH from bastion)

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-ec2-sg" }
}

# --- IAM Role for EC2 Instances (for SSM Access if enabled) ---
resource "aws_iam_role" "ec2_ssm_role" {
  count = var.enable_ssm_access ? 1 : 0
  name  = "${var.project_name}-ec2-ssm-role"
  path  = "/"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
  tags = { Name = "${var.project_name}-ec2-ssm-role" }
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
  tags  = { Name = "${var.project_name}-ec2-ssm-profile" }
}

# --- Launch Template ---
resource "aws_launch_template" "app_lt" {
  name                   = "${var.project_name}-app-lt"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  # Assign IAM profile only if it was created
  iam_instance_profile {
    name = var.enable_ssm_access ? aws_iam_instance_profile.ec2_ssm_profile[0].name : null
  }

  # Add user_data here if needed:
  # user_data = filebase64("${path.module}/user_data.sh")

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project_name}-ec2-instance" }
  }
  lifecycle { create_before_destroy = true }
  tags = { Name = "${var.project_name}-app-lt" }
}

# --- Auto Scaling Group ---
resource "aws_autoscaling_group" "app_asg" {
  name                      = "${var.project_name}-app-asg"
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity
  vpc_zone_identifier       = var.private_subnet_ids # Launch in private subnets
  target_group_arns         = [var.target_group_arn] # Attach to ALB Target Group
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  lifecycle { create_before_destroy = true }

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
  # depends_on might not be strictly needed due to implicit dependency via target_group_arns
  # depends_on = [module.alb] # This dependency should be handled by passing the ARN
}
