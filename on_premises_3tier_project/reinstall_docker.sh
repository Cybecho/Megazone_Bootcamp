#!/bin/bash
set -e

echo "=== 기존 Docker 관련 패키지 제거 ==="
sudo apt-get remove -y docker docker-engine docker.io containerd runc

echo "=== APT 업데이트 및 필수 패키지 설치 ==="
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

echo "=== Docker 공식 GPG 키 추가 ==="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "=== Docker 안정화 저장소 설정 ==="
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "=== APT 업데이트 (Docker 저장소 추가 후) ==="
sudo apt-get update

echo "=== Docker CE, CLI 및 containerd 설치 ==="
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

echo "=== Docker 서비스 시작 ==="
sudo systemctl start docker

echo "=== Docker 서비스 상태 확인 ==="
sudo systemctl status docker.service
