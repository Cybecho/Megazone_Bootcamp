#!/bin/bash

# 스크립트 실행 중 오류 발생 시 중단
# set -e

# 1. 작업 디렉토리 생성 (MariaDB 관련 설정)
mkdir -p /root/docker/mariadb

# 2. MariaDB 초기화 SQL 파일 생성
cat <<'EOF' > /root/docker/mariadb/init.sql
-- 데이터베이스 생성
CREATE DATABASE StyleSanda;
USE StyleSanda;

-- 테이블 생성
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    quantity INT NOT NULL DEFAULT 10,
    image_url VARCHAR(255)
);

-- 샘플 데이터 삽입
INSERT INTO products (product_name, quantity, image_url)
VALUES ('샘플상품', 10, '');

-- 원격 접속 허용 설정
DROP USER IF EXISTS 'root'@'%';
CREATE USER 'root'@'%' IDENTIFIED BY 'root';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

# 3. Dockerfile 생성 (MariaDB 공식 이미지를 기반으로 init.sql 복사)
cat <<'EOF' > /root/docker/mariadb/Dockerfile
FROM mariadb
COPY init.sql /docker-entrypoint-initdb.d/
EOF

# 4. Docker 이미지 빌드
docker build -t custom_mariadb /root/docker/mariadb

# 5. 데이터 저장을 위한 호스트 볼륨 디렉토리 생성 및 권한 설정
mkdir -p /root/docker/volumes
sudo chown -R 999:999 /root/docker/volumes
sudo chmod -R 777 /root/docker/volumes

# 6. MariaDB 컨테이너 실행 (포트 3306, 볼륨 마운트)
sudo docker run -d --name mariadb_container --user root \
  -e MYSQL_ROOT_PASSWORD=root \
  -p 3306:3306 \
  -v /root/docker/volumes:/var/lib/mysql \
  custom_mariadb
