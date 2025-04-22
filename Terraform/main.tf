terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-west-2"
}

resource "aws_vpc" "mzc_user05_main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "mzc_user05_main"
  }
}

# Subnets in each Availability Zone
resource "aws_subnet" "mzc_user05_subnet_a" {
  vpc_id                  = aws_vpc.mzc_user05_main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "mzc_user05_subnet_a"
  }
}

resource "aws_subnet" "mzc_user05_subnet_b" {
  vpc_id                  = aws_vpc.mzc_user05_main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-west-2b"
  map_public_ip_on_launch = true

  tags = {
    Name = "mzc_user05_subnet_b"
  }
}

resource "aws_subnet" "mzc_user05_subnet_c" {
  vpc_id                  = aws_vpc.mzc_user05_main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-west-2c"
  map_public_ip_on_launch = true

  tags = {
    Name = "mzc_user05_subnet_c"
  }
}

#Get the Ubuntu 20.04 AMI
data "aws_ami" "ubuntu_2004" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu) Public AWS Account

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  tags = {
    "OS_Version" = "Ubuntu 20.04"
  }
}

output "ubuntu_2004_ami_id" {
  description = "Ubuntu 20.04 AMI ID for the Seoul Region"
  value       = data.aws_ami.ubuntu_2004.id
}

output "ubuntu_2004_ami_name" {
  description = "Ubuntu 20.04 AMI ID for the Seoul Region"
  value       = data.aws_ami.ubuntu_2004.name
}

/*
resource "aws_instance" "web" {
  count         = 3
  ami           = data.aws_ami.ubuntu_2004.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.mzc_user05_subnet_a.id # 서브넷 ID 지정

  tags = {
    Name = "web-instance-${count.index}"
  }
}
*/

resource "aws_instance" "server" {
  for_each      = var.instance_type
  ami           = data.aws_ami.ubuntu_2004.id
  instance_type = each.value
  subnet_id     = aws_subnet.mzc_user05_subnet_a.id # 서브넷 ID 지정

  tags = {
    Name = "server-web-instance${each.key}"
  }
}

resource "aws_s3_bucket" "mzc_user05_bucket" {
  bucket = "mzc-user05-bucket"

  lifecycle {
    prevent_destroy = false # destroy할때 실제 s3 bucket을 삭제할 수 있도록 설정 만약 true로 설정하면 삭제가 안됨
  }


}

resource "aws_s3_object" "mzc_user05_object" {
  bucket  = aws_s3_bucket.mzc_user05_bucket.id
  key     = "helloworld.txt"
  content = "Hello, World!"

  depends_on = [aws_s3_bucket.mzc_user05_bucket]
}
