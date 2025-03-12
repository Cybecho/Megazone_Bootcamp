#!/bin/bash
# 기본 패키지하고 도커 설치하려고 씀
# 스크립트 실행 오류 발생 시 중단
set -e

echo "=== [1] 디렉토리 생성 중 ==="
mkdir -p /root/docker/redis
mkdir -p /root/docker/apache2

echo "=== [2] Redis 설정 파일 생성 중 ==="
cat <<EOF > /root/docker/redis/redis.conf
bind 0.0.0.0
requirepass root
EOF

echo "=== [3] Redis Dockerfile 생성 중 ==="
cat <<EOF > /root/docker/redis/Dockerfile
FROM redis
COPY redis.conf /usr/local/etc/redis/redis.conf
CMD ["redis-server", "/usr/local/etc/redis/redis.conf"]
EOF

echo "=== [4] Apache2 설정 파일 생성 중 ==="
cat <<EOF > /root/docker/apache2/000-default.conf
<VirtualHost *:80>
    ProxyPreserveHost On

    <Proxy "balancer://was_cluster">
        BalancerMember http://192.168.2.10 route=was1
        BalancerMember http://192.168.2.20 route=was2
    </Proxy>

    ProxyPassMatch "^/$" "balancer://was_cluster/index.php"
    ProxyPass "/" "balancer://was_cluster/"
    ProxyPassReverse "/" "balancer://was_cluster/"

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

echo "=== [5] Apache2 Dockerfile 생성 중 ==="
cat <<EOF > /root/docker/apache2/Dockerfile
FROM httpd:2.4
RUN sed -i '/#LoadModule proxy_module/s/^#//g' /usr/local/apache2/conf/httpd.conf && \\
    sed -i '/#LoadModule proxy_http_module/s/^#//g' /usr/local/apache2/conf/httpd.conf && \\
    sed -i '/#LoadModule proxy_balancer_module/s/^#//g' /usr/local/apache2/conf/httpd.conf && \\
    sed -i '/#LoadModule lbmethod_byrequests_module/s/^#//g' /usr/local/apache2/conf/httpd.conf && \\
    sed -i '/#LoadModule session_module/s/^#//g' /usr/local/apache2/conf/httpd.conf && \\
    sed -i '/#LoadModule session_cookie_module/s/^#//g' /usr/local/apache2/conf/httpd.conf
COPY 000-default.conf /usr/local/apache2/conf/extra/000-default.conf
RUN echo "Include conf/extra/000-default.conf" >> /usr/local/apache2/conf/httpd.conf
EOF

echo "=== [6] Redis Docker 이미지 빌드 중 ==="
docker build -t custom_redis /root/docker/redis

echo "=== [7] Apache2 Docker 이미지 빌드 중 ==="
docker build -t custom_apache2 /root/docker/apache2

echo "=== [8] Redis 컨테이너 실행 중 ==="
docker run -d --name redis_container -p 6379:6379 custom_redis

echo "=== [9] Apache2 컨테이너 실행 중 ==="
docker run -d --name apache2_container -p 80:80 custom_apache2

echo "=== [10] 설정 완료! ==="
