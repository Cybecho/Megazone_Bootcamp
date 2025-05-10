#==========================================================================
# 파일 위치: /my-terraform-project/terraform-backend/main.tf
# 목적: Terraform 상태 저장을 위한 S3 버킷과 상태 잠금을 위한 DynamoDB 테이블 생성
# 이 코드는 자체 로컬 상태 파일을 사용하여 S3/DynamoDB를 관리합니다.
#==========================================================================

# Terraform 설정: AWS 프로바이더 지정
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # 권장 버전 범위 사용
    }
  }
}

# 프로바이더 설정: AWS 사용 및 리전 지정 (필수 요구 사항: us-west-2)
provider "aws" {
  region = "us-west-2"
}

#--------------------------------------------------------------------------
# Terraform Remote State Backend 리소스 정의
#--------------------------------------------------------------------------

# S3 버킷 생성 (Terraform 상태 파일 저장용)
resource "aws_s3_bucket" "tfstate_bucket" {
  # 버킷 이름: 전역적으로 고유해야 함 (필수 요구 사항 - mzc_user05 네이밍 적용)
  # 이 이름은 아래 terraform-infrastructure 폴더의 backend.tf에서 사용됩니다.
  bucket = "mzc-user05-tfstate-bucket"

  # 실수로 인한 버킷 삭제 방지 (프로덕션에서는 true 권장)
  # 이 Lab에서는 필요에 따라 force_destroy 사용 고려 가능 (하지만 위험)
  # prevent_destroy = true

  tags = {
    Name        = "mzc_user05_tfstate_bucket"
    Environment = "terraform-backend"
    ManagedBy   = "Terraform"
    User        = "mzc_user05"
  }
}

# S3 버킷 버전 관리 활성화 (이미지 요구사항)
resource "aws_s3_bucket_versioning" "tfstate_bucket_versioning" {
  bucket = aws_s3_bucket.tfstate_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 버킷 서버 측 암호화 설정 (이미지 요구사항 - SSE-S3 사용)
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate_bucket_sse" {
  bucket = aws_s3_bucket.tfstate_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # AWS S3 관리형 키 사용
    }
  }
}

# S3 버킷 퍼블릭 접근 차단 설정 (보안 강화 권장)
resource "aws_s3_bucket_public_access_block" "tfstate_bucket_pab" {
  bucket = aws_s3_bucket.tfstate_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB 테이블 생성 (Terraform 상태 잠금용 - 이미지 요구사항)
resource "aws_dynamodb_table" "tfstate_lock_table" {
  # 테이블 이름 (필수 요구 사항 - mzc_user05 네이밍 적용)
  # 이 이름은 아래 terraform-infrastructure 폴더의 backend.tf에서 사용됩니다.
  name = "mzc_user05-terraform-lock-table"
  # 처리량 모드: On-Demand (비용 효율적)
  billing_mode = "PAY_PER_REQUEST"
  # 파티션 키: Terraform 백엔드가 요구하는 기본 이름 및 타입
  hash_key = "LockID"

  # 속성 정의: LockID는 문자열(S) 타입
  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "mzc_user05_tfstate_lock_table"
    Environment = "terraform-backend"
    ManagedBy   = "Terraform"
    User        = "mzc_user05"
  }
}

# (선택 사항) 생성된 리소스 이름 출력
output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.tfstate_bucket.bucket
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for Terraform state locking"
  value       = aws_dynamodb_table.tfstate_lock_table.name
}
