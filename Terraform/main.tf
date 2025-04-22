# Terraform 설정 파일임, AWS 리소스를 관리하기 위한 설정을 포함하고 있음
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # 특정 버전 범위 지정 권장
    }
  }
}

# 프로바이더는 AWS를 사용하고, 리전 설정
provider "aws" {
  region = "us-west-2"
}

# 현재 AWS 리전 정보 가져오기 (VPC 엔드포인트 이름 구성에 사용)
data "aws_region" "current" {}

#--------------------------------------------------------------------------
# 네트워크 인프라 (VPC, Subnets, IGW, Routes)
#--------------------------------------------------------------------------

# VPC 생성
resource "aws_vpc" "mzc_user05_main" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true # VPC 엔드포인트 및 내부 DNS 확인에 필요
  enable_dns_hostnames = true # 퍼블릭 IP 할당 시 DNS 호스트 이름 자동 할당

  tags = {
    Name = "mzc_user05_main_vpc"
  }
}

# 인터넷 게이트웨이 생성
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.mzc_user05_main.id

  tags = {
    Name = "mzc_user05_igw"
  }
}

# 퍼블릭 라우트 테이블 생성 (인터넷 게이트웨이 경로 포함)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.mzc_user05_main.id

  route {
    cidr_block = "0.0.0.0/0"                # 모든 외부 대상 트래픽
    gateway_id = aws_internet_gateway.gw.id # 인터넷 게이트웨이로 전송
  }

  tags = {
    Name = "mzc_user05_public_rt"
  }
}

# 퍼블릭 서브넷 A 생성 (인스턴스 A 용)
resource "aws_subnet" "mzc_user05_subnet_a" {
  vpc_id                  = aws_vpc.mzc_user05_main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${data.aws_region.current.name}a" # 리전명 동적 사용
  map_public_ip_on_launch = true                               # 퍼블릭 IP 자동 할당 활성화

  tags = {
    Name = "mzc_user05_subnet_a_public"
  }
}

# 퍼블릭 라우트 테이블을 퍼블릭 서브넷 A에 연결
resource "aws_route_table_association" "public_assoc_a" {
  subnet_id      = aws_subnet.mzc_user05_subnet_a.id
  route_table_id = aws_route_table.public_rt.id
}

# 프라이빗 서브넷 B 생성 (인스턴스 B 용)
resource "aws_subnet" "mzc_user05_subnet_b" {
  vpc_id                  = aws_vpc.mzc_user05_main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${data.aws_region.current.name}b" # 리전명 동적 사용
  map_public_ip_on_launch = false                              # 퍼블릭 IP 자동 할당 비활성화

  tags = {
    Name = "mzc_user05_subnet_b_private"
  }
}

#--------------------------------------------------------------------------
# IAM (SSM 접근 권한)
#--------------------------------------------------------------------------

# EC2 인스턴스용 IAM 역할 생성
resource "aws_iam_role" "ssm_role" {
  name = "mzc_user05_ec2_ssm_role"
  path = "/"

  # EC2 서비스가 이 역할을 맡을 수 있도록 신뢰 정책 설정
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "mzc_user05_ec2_ssm_role"
  }
}

# IAM 역할에 AWS 관리형 SSM 정책 연결
resource "aws_iam_role_policy_attachment" "ssm_policy_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM 인스턴스 프로파일 생성 (EC2 인스턴스에 역할을 연결하기 위함)
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "mzc_user05_ec2_ssm_profile"
  role = aws_iam_role.ssm_role.name

  tags = {
    Name = "mzc_user05_ec2_ssm_profile"
  }
}

#--------------------------------------------------------------------------
# 보안 그룹 (Security Groups)
#--------------------------------------------------------------------------

# 인스턴스용 보안 그룹 (내부 SSH/ICMP 허용, 모든 아웃바운드 허용)
resource "aws_security_group" "instance_sg" {
  name        = "mzc_instance_sg"
  description = "Allow internal SSH/ICMP and all outbound traffic"
  vpc_id      = aws_vpc.mzc_user05_main.id

  # 인바운드 규칙: VPC 내부에서 SSH(22) 허용
  ingress {
    description = "SSH from within VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.mzc_user05_main.cidr_block] # VPC 내부 전체 대역
  }

  # 인바운드 규칙: VPC 내부에서 ICMP(Ping) 허용
  ingress {
    description = "ICMP from within VPC"
    from_port   = -1 # 모든 ICMP 타입
    to_port     = -1 # 모든 ICMP 코드
    protocol    = "icmp"
    cidr_blocks = [aws_vpc.mzc_user05_main.cidr_block] # VPC 내부 전체 대역
  }

  # 아웃바운드 규칙: 모든 트래픽 허용 (SSM 엔드포인트, 외부 패키지 설치 등)
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1" # 모든 프로토콜
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "mzc_instance_sg"
  }
}

# VPC 엔드포인트용 보안 그룹 (내부 HTTPS 허용)
resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "mzc_vpc_endpoint_sg"
  description = "Allow HTTPS from within VPC for Interface Endpoints"
  vpc_id      = aws_vpc.mzc_user05_main.id

  # 인바운드 규칙: VPC 내부에서 HTTPS(443) 허용
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.mzc_user05_main.cidr_block] # VPC 내부 전체 대역
  }

  # 아웃바운드는 보통 기본적으로 허용되거나, 필요시 instance_sg 처럼 모든 아웃바운드 추가 가능
  # egress {
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  tags = {
    Name = "mzc_vpc_endpoint_sg"
  }
}

#--------------------------------------------------------------------------
# VPC 엔드포인트 (프라이빗 서브넷의 SSM 통신용)
#--------------------------------------------------------------------------

# SSM 서비스용 VPC 인터페이스 엔드포인트
resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = aws_vpc.mzc_user05_main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type = "Interface"

  # 엔드포인트가 위치할 서브넷 지정 (프라이빗 서브넷만 지정해도 되지만, 양쪽 다 해도 무방)
  subnet_ids = [aws_subnet.mzc_user05_subnet_a.id, aws_subnet.mzc_user05_subnet_b.id]

  security_group_ids = [
    aws_security_group.vpc_endpoint_sg.id,
  ]
  private_dns_enabled = true # 프라이빗 DNS 이름을 활성화하여 기존 엔드포인트 주소 사용

  tags = {
    Name = "mzc_user05_ssm_endpoint"
  }
}

# EC2 Messages 서비스용 VPC 인터페이스 엔드포인트
resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id            = aws_vpc.mzc_user05_main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type = "Interface"

  subnet_ids = [aws_subnet.mzc_user05_subnet_a.id, aws_subnet.mzc_user05_subnet_b.id]

  security_group_ids = [
    aws_security_group.vpc_endpoint_sg.id,
  ]
  private_dns_enabled = true

  tags = {
    Name = "mzc_user05_ec2messages_endpoint"
  }
}

# SSM Messages 서비스용 VPC 인터페이스 엔드포인트 (Session Manager 등)
resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id            = aws_vpc.mzc_user05_main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type = "Interface"

  subnet_ids = [aws_subnet.mzc_user05_subnet_a.id, aws_subnet.mzc_user05_subnet_b.id]

  security_group_ids = [
    aws_security_group.vpc_endpoint_sg.id,
  ]
  private_dns_enabled = true

  tags = {
    Name = "mzc_user05_ssmmessages_endpoint"
  }
}


#--------------------------------------------------------------------------
# EC2 인스턴스
#--------------------------------------------------------------------------

# 인스턴스 A (퍼블릭 서브넷, 퍼블릭 IP 할당)
resource "aws_instance" "mzc_user05_instance_a" {
  # 최신 Amazon Linux 2023 AMI ID를 SSM 파라미터 스토어에서 동적으로 조회
  ami           = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  instance_type = "t3.micro"

  # 퍼블릭 서브넷에 배치
  subnet_id = aws_subnet.mzc_user05_subnet_a.id

  # 인스턴스 보안 그룹 적용
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  # SSM 접근을 위한 IAM 인스턴스 프로파일 연결
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  # 키 페어 지정 (선택 사항 - SSH 직접 접속 시 필요)
  # key_name = "your-key-pair-name"

  tags = {
    Name = "mzc_user05_instance_a_public"
  }
}

# 인스턴스 B (프라이빗 서브넷, 퍼블릭 IP 미할당)
resource "aws_instance" "mzc_user05_instance_b" {
  # 최신 Amazon Linux 2023 AMI ID 사용
  ami           = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  instance_type = "t3.micro"

  # 프라이빗 서브넷에 배치
  subnet_id = aws_subnet.mzc_user05_subnet_b.id

  # 인스턴스 보안 그룹 적용 (Instance A와 동일 그룹 사용)
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  # SSM 접근을 위한 IAM 인스턴스 프로파일 연결
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  # 서브넷 설정에서 map_public_ip_on_launch = false 이므로, 별도 설정 불필요
  # associate_public_ip_address = false

  # 키 페어 지정 (선택 사항 - SSM 통해 접속 예정이므로 필수는 아님)
  # key_name = "your-key-pair-name"

  tags = {
    Name = "mzc_user05_instance_b_private"
  }
}

#--------------------------------------------------------------------------
# 출력 (Outputs - 필요시)
#--------------------------------------------------------------------------

output "instance_a_public_ip" {
  description = "Public IP address of instance A"
  value       = aws_instance.mzc_user05_instance_a.public_ip
}

output "instance_a_private_ip" {
  description = "Private IP address of instance A"
  value       = aws_instance.mzc_user05_instance_a.private_ip
}

output "instance_b_private_ip" {
  description = "Private IP address of instance B"
  value       = aws_instance.mzc_user05_instance_b.private_ip
}
