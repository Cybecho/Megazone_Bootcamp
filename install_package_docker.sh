#!/bin/bash
# 기본 패키지하고 도커 설치하려고 씀
# 스크립트 실행 오류 발생 시 중단

set -e  # 오류 발생 시 즉시 종료
export DEBIAN_FRONTEND=noninteractive  # 설치 시 사용자 입력 방지

# 필수 패키지 목록
COMMON_PACKAGES=(
    vim nano bind9 resolvconf dnsutils netplan.io ifupdown network-manager
    isc-dhcp-server isc-dhcp-relay curl ssh openssh-server openssh-client
    net-tools iputils-ping traceroute nmap ufw iptables tcpdump htop tree git
    wget tar cron docker-compose podman buildah skopeo containerd ca-certificates
)

echo "[+] 시스템 패키지 업데이트 중..."
apt-get update && apt-get upgrade -y

echo "[+] 필수 패키지 설치 중..."
apt-get install -y "${COMMON_PACKAGES[@]}"

# Docker 설치 (Docker 저장소 추가)
echo "[+] Docker GPG 키 추가 중..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "[+] Docker 저장소 추가 중..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "[+] Docker 패키지 설치 중..."
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin crictl

echo "[+] Docker 서비스 활성화..."
systemctl enable docker
systemctl start docker

echo "[+] 패키지 및 Docker 설치 완료!"
