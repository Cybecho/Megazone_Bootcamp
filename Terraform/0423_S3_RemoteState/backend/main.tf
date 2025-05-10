#==========================================================================
# 파일 위치: /my-terraform-project/terraform-infrastructure/main.tf
# 목적: 이 Terraform 프로젝트로 관리할 실제 AWS 인프라 리소스(VPC, EC2 등) 정의
# 이 파일은 backend.tf에 설정된 S3 백엔드를 사용하여 상태를 관리합니다.
#==========================================================================

# 프로바이더 설정: AWS 사용 (리전은 보통 backend.tf의 설정이 우선하거나 일치해야 함)
provider "aws" {
  region = "us-west-2" # 백엔드 리전과 동일하게 유지하는 것이 좋습니다.
  # 다른 프로바이더 설정 ...
}

#--------------------------------------------------------------------------
# 실제 인프라 리소스 정의 시작 (여기에 VPC, Subnet, EC2, SG 등 코드를 작성합니다)
#--------------------------------------------------------------------------

# 예시: 간단한 변수 정의 (실제 리소스 코드는 여기에 작성)
variable "environment" {
  description = "Deployment environment (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

# 실제 VPC, EC2 등의 resource 블록들이 이 아래에 작성됩니다.
# resource "aws_vpc" "my_vpc" { ... }
# resource "aws_instance" "my_server" { ... }
