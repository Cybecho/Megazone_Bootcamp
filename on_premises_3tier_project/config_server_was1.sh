#!/bin/bash

# 스크립트 실행 중 오류 발생 시 중단
# set -e

sudo systemctl start docker

echo "=== [1] 도커 디렉토리 생성 ==="
mkdir -p /root/docker/was

echo "=== [2] WAS용 index.php 생성 중 ==="
cat <<'EOF' > /root/docker/was/index.php
<?php
session_start();

// DB 연결
try {
    $db = new PDO('mysql:host=192.168.3.10;dbname=StyleSanda;charset=utf8mb4', 'root', 'root');
} catch (PDOException $e) {
    die("DB connection failed: " . $e->getMessage());
}

// 세션 방문 횟수 증가
if (!isset($_SESSION['visit_count'])) {
    $_SESSION['visit_count'] = 1;
} else {
    $_SESSION['visit_count']++;
}

// 구매 버튼 누를 시 재고 1 감소
if (isset($_POST['buy'])) {
    $stmt = $db->prepare("UPDATE products SET quantity = quantity - 1 WHERE product_id = 1 AND quantity > 0");
    $stmt->execute();
    if ($stmt->rowCount() === 0) {
        echo "<script>alert('재고가 없습니다!');</script>";
    }
}

$product = $db->query("SELECT * FROM products WHERE product_id = 1")->fetch();
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>상품 페이지</title>
</head>
<body>
    <h1><?= htmlspecialchars($product['product_name']) ?></h1>
    <p>THIS IS WAS 1</p>
    <p>남은 수량: <?= htmlspecialchars($product['quantity']) ?></p>
    <p>Session ID: <?= session_id() ?></p>
    <p>방문 횟수: <?= $_SESSION['visit_count'] ?></p>
    <form method="POST">
        <button type="submit" name="buy">구매하기</button>
    </form>
</body>
</html>
EOF

echo "=== [3] PHP 세션 Redis 설정 파일(ini) 생성 중 ==="
cat <<'EOF' > /root/docker/was/redis-session.ini
; PHP 세션을 Redis로 저장
session.save_handler = redis
session.save_path = "tcp://192.168.1.10:6379?auth=root&timeout=2.5"
EOF

echo "=== [4] Dockerfile 생성 중 ==="
cat <<'EOF' > /root/docker/was/Dockerfile
FROM php:8.0-apache

# 패키지 업데이트 및 필요한 확장 설치
RUN apt-get update && apt-get install -y \
    libzip-dev \
    && docker-php-ext-install mysqli pdo_mysql

# PECL redis 확장 설치
RUN pecl install redis \
    && docker-php-ext-enable redis

# Redis 세션 설정 복사
COPY redis-session.ini /usr/local/etc/php/conf.d/redis-session.ini

# PHP 웹 소스 복사
COPY index.php /var/www/html/

# 포트 공개
EXPOSE 80
EOF

echo "=== [5] Docker 이미지 빌드 중 ==="
docker build -t custom_was /root/docker/was

echo "=== [6] Docker 컨테이너 실행 중 ==="
# 같은 이름의 컨테이너가 있다면 중지/삭제 처리
if [ "$(docker ps -aq -f name=was_container)" ]; then
    docker stop was_container || true
    docker rm was_container || true
fi
docker run -d --name was_container -p 80:80 custom_was

echo "=== [7] 설정 완료! ==="
