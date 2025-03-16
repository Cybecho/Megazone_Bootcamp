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
try {
    $db = new PDO('mysql:host=192.168.3.10;dbname=StyleSanda;charset=utf8mb4', 'root', 'root');
} catch (PDOException $e) {
    die("DB connection failed: " . $e->getMessage());
}

if (!isset($_SESSION['visit_count'])) {
    $_SESSION['visit_count'] = 1;
} else {
    $_SESSION['visit_count']++;
}

if (isset($_POST['buy'])) {
    $stmt = $db->prepare("UPDATE products SET quantity = quantity - 1 WHERE product_id = 1 AND quantity > 0");
    $stmt->execute();
    if ($stmt->rowCount() === 0) {
        echo "<script>alert('재고가 없습니다!');</script>";
    }
}

$product = $db->query("SELECT * FROM products WHERE product_id = 1")->fetch();
$containerId = gethostname();
?>
<!DOCTYPE html>
<html lang="ko">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= htmlspecialchars($product['product_name']) ?> - 구매 페이지</title>
    <style>
        body {
            margin: 0;
            font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;
            background-color: #f5f5f5;
        }
        .product-page {
            max-width: 1200px;
            margin: 20px auto;
            background: #fff;
            padding: 20px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        .product-header {
            display: flex;
            flex-wrap: wrap;
            border-bottom: 1px solid #e1e1e1;
            padding-bottom: 20px;
            margin-bottom: 20px;
        }
        .product-image {
            flex: 1;
            min-width: 300px;
            text-align: center;
        }
        .product-image img {
            max-width: 100%;
            height: auto;
            border: 1px solid #ddd;
            border-radius: 4px;
            padding: 5px;
            background: #fff;
        }
        .product-details {
            flex: 2;
            padding: 20px;
        }
        .product-title {
            font-size: 2em;
            margin-bottom: 10px;
            color: #333;
        }
        .product-price {
            font-size: 1.8em;
            color: #B12704;
            margin: 10px 0;
        }
        .stock-info {
            font-size: 1em;
            margin: 15px 0;
            color: #555;
        }
        .product-description {
            margin: 20px 0;
            line-height: 1.6;
            color: #555;
        }
        .buy-button {
            background-color: #ffd814;
            border: 1px solid #fcd200;
            padding: 15px 25px;
            font-size: 1em;
            font-weight: bold;
            cursor: pointer;
            border-radius: 4px;
            transition: background 0.3s;
        }
        .buy-button:hover {
            background-color: #f7ca00;
        }
        .additional-info {
            font-size: 0.9em;
            color: #888;
            margin-top: 20px;
            border-top: 1px solid #e1e1e1;
            padding-top: 10px;
        }
        @media (max-width: 768px) {
            .product-header {
                flex-direction: column;
            }
            .product-details {
                padding: 10px;
            }
        }
    </style>
</head>
<body>
    <div class="product-page">
        <div class="product-header">
            <div class="product-image">
                <img src="<?= htmlspecialchars($product['image_url']) ?>" alt="<?= htmlspecialchars($product['product_name']) ?>">
            </div>
            <div class="product-details">
                <h1 class="product-title"><?= htmlspecialchars($product['product_name']) ?></h1>
                <p class="product-price">₩560,000</p>
                <div class="stock-info">
                    남은 수량: <?= htmlspecialchars($product['quantity']) ?>
                </div>
                <p class="product-description">
                    이 제품은 최신 트렌드를 반영한 프리미엄 상품입니다. 최고의 품질과 성능을 자랑하며, 지금 구매하시면 특별한 혜택을 누리실 수 있습니다.
                </p>
                <form method="POST">
                    <button type="submit" name="buy" class="buy-button">바로 구매하기</button>
                </form>
            </div>
        </div>
        <div class="additional-info">
            <p>Session ID: <?= session_id() ?></p>
            <p>방문 횟수: <?= $_SESSION['visit_count'] ?></p>
            <p>컨테이너 식별자: <?= htmlspecialchars($containerId) ?></p>
        </div>
    </div>
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
