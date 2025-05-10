#==========================================================================
# 파일 위치: /my-terraform-project/terraform-infrastructure/backend.tf
# 목적: 이 Terraform 프로젝트의 상태 파일을 S3 버킷에 저장하고, DynamoDB로 잠금 설정
# 이 파일 자체는 리소스를 생성하지 않습니다.
#==========================================================================

# Terraform 백엔드 설정: S3 사용 명시
terraform {
  backend "s3" {
    # 위에 terraform-backend 폴더에서 생성한 S3 버킷 이름과 정확히 일치해야 합니다.
    bucket = "mzc-user05-tfstate-bucket"

    # S3 버킷 내에서 이 프로젝트의 상태 파일이 저장될 경로 및 파일 이름
    # 다른 프로젝트나 환경(dev, prod)의 상태 파일과 충돌하지 않도록 경로를 지정하는 것이 좋습니다.
    key = "infra/mzc_user05/prod/terraform.tfstate" # 예시 경로

    # 백엔드 리소스(S3 버킷)가 위치한 리전 (필수 요구 사항: us-west-2)
    region = "us-west-2"

    # 상태 잠금을 위한 DynamoDB 테이블 이름
    # 위에 terraform-backend 폴더에서 생성한 DynamoDB 테이블 이름과 정확히 일치해야 합니다.
    dynamodb_table = "mzc_user05-terraform-lock-table"

    # 상태 파일 암호화 활성화 (S3 버킷의 기본 암호화 설정(SSE-S3)을 사용)
    encrypt = true
  }
}
