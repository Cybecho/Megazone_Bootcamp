#!/bin/bash
set -e

#####################################
# 0. Jenkins 사용자 Docker 그룹 권한 부여
#####################################
echo "Jenkins 사용자를 docker 그룹에 추가하고 서비스를 재시작합니다."
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins

#####################################
# 1. Jenkins Workspace 준비 (Dockerfile, redis-session.ini, index.php)
#####################################
WORKSPACE="/var/lib/jenkins/workspace/PHP-WAS-Deploy"
echo "Jenkins Workspace 생성: ${WORKSPACE}"
sudo -u jenkins mkdir -p "${WORKSPACE}"
cd "${WORKSPACE}"

echo "Dockerfile 생성 중..."
sudo tee Dockerfile > /dev/null <<'EOF'
FROM php:8.0-apache

RUN apt-get update && apt-get install -y \
    libzip-dev \
    && docker-php-ext-install mysqli pdo_mysql \
    && pecl install redis && docker-php-ext-enable redis

COPY redis-session.ini /usr/local/etc/php/conf.d/redis-session.ini
COPY index.php /var/www/html/

EXPOSE 80
EOF

echo "redis-session.ini 생성 중..."
sudo tee redis-session.ini > /dev/null <<'EOF'
session.save_handler = redis
session.save_path = "tcp://192.168.1.10:6379?auth=root&timeout=2.5"
EOF

echo "index.php 생성 중..."
sudo tee index.php > /dev/null <<'EOF'
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
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>상품 페이지</title>
</head>
<body>
    <h1><?= htmlspecialchars($product['product_name']) ?></h1>
    <p>남은 수량: <?= htmlspecialchars($product['quantity']) ?></p>
    <p>Session ID: <?= session_id() ?></p>
    <p>방문 횟수: <?= $_SESSION['visit_count'] ?></p>
    <form method="POST">
        <button type="submit" name="buy">구매하기</button>
    </form>
</body>
</html>
EOF

#####################################
# 2. Docker Registry 실행 (CI/CD 서버)
#####################################
REGISTRY_IP="192.168.5.10"
REGISTRY_PORT="5000"
IMAGE_NAME="custom_was"
FULL_IMAGE_NAME="${REGISTRY_IP}:${REGISTRY_PORT}/${IMAGE_NAME}:latest"

echo "Docker Registry 실행 여부 확인..."
if ! docker ps --filter "name=registry" --format '{{.Names}}' | grep -q "^registry\$"; then
  echo "Registry 미실행 → 시작합니다."
  docker run -d -p ${REGISTRY_PORT}:5000 --restart=always --name registry registry:2
else
  echo "Docker Registry가 이미 실행 중입니다."
fi

#####################################
# 3. Jenkins Workspace에서 Docker 이미지 빌드 및 푸시
#####################################
echo "Docker 이미지 빌드 시작..."
docker build -t "${FULL_IMAGE_NAME}" "${WORKSPACE}"
echo "Docker 이미지 Registry에 푸시 중..."
docker push "${FULL_IMAGE_NAME}"

#####################################
# 4. WAS 서버 무중단 배포 (SSH를 통한 컨테이너 교체)
#####################################
# 대상 WAS 서버 목록
WAS_SERVERS=("192.168.2.10" "192.168.2.20")

# SSH 옵션 (호스트 키 검증 우회)
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# 각 WAS 서버별 SSH 프라이빗 키 (실제 키 내용으로 교체)
declare -A SERVERS_KEYS
SERVERS_KEYS["192.168.2.10"]="-----BEGIN OPENSSH PRIVATE KEY-----
[192.168.2.10 전용 키 내용]
-----END OPENSSH PRIVATE KEY-----"
SERVERS_KEYS["192.168.2.20"]="-----BEGIN OPENSSH PRIVATE KEY-----
[192.168.2.20 전용 키 내용]
-----END OPENSSH PRIVATE KEY-----"

echo "WAS 서버에 배포 시작..."
for SERVER in "${WAS_SERVERS[@]}"; do
  echo "[$SERVER] 배포 시작"
  
  KEY_CONTENT="${SERVERS_KEYS[$SERVER]}"
  
  # 임시 디렉토리 및 SSH 키 파일 생성 (프로세스 서브스티튜션 문제 해결)
  TMP_DIR=$(mktemp -d)
  TMP_KEY_FILE="$TMP_DIR/deploy_key"
  echo "$KEY_CONTENT" > "$TMP_KEY_FILE"
  chmod 600 "$TMP_KEY_FILE"
  
  ssh $SSH_OPTS -i "$TMP_KEY_FILE" vagrant@"$SERVER" bash <<EOF
docker pull ${FULL_IMAGE_NAME}

docker rename was_container was_container_old || true
docker run -d --name was_container -p 80:80 ${FULL_IMAGE_NAME}

sleep 5

if curl -fs http://localhost:80 > /dev/null; then
  docker stop was_container_old || true
  docker rm was_container_old || true
  echo "[$SERVER] 배포 성공!"
else
  docker stop was_container
  docker rm was_container
  docker rename was_container_old was_container || true
  echo "[$SERVER] 배포 실패: 롤백 완료"
  exit 1
fi
EOF

  # 임시 키 파일 삭제
  rm -rf "$TMP_DIR"
done

echo "모든 WAS 서버에 배포 완료."
