#!/usr/bin/env bash
# ==============================================================================
# restore_up_to_step2.sh
# 다른 컴퓨터의 새로 만든 Ubuntu 22.04 (OrbStack) 환경에서
# Step 0 ~ Step 2-2까지의 모든 설정을 한 번에 자동 복구하는 스크립트입니다.
#
# [사용 방법 (우분투 터미널 안에서 실행)]
#   sudo bash etc/restore_up_to_step2.sh
# ==============================================================================

set -euo pipefail

echo "============================================================"
echo "[Step 0] 패키지 저장소(HTTPS) 설정 및 필수 패키지 설치 중..."
echo "============================================================"

ARCH=$(uname -m)
if [ "${ARCH}" = "x86_64" ]; then
    sudo sed -i 's|http://archive.ubuntu.com|https://mirror.kakao.com|g; s|http://security.ubuntu.com|https://mirror.kakao.com|g' /etc/apt/sources.list
else
    sudo sed -i 's|http://ports.ubuntu.com|https://ports.ubuntu.com|g' /etc/apt/sources.list
fi

sudo apt update
sudo apt install -y sudo openssh-server ufw acl cron iproute2 procps logrotate bc
sudo systemctl enable --now cron

echo ""
echo "============================================================"
echo "[Step 1-1] SSH 포트(20022) 변경 및 Root 원격 접속 차단 중..."
echo "============================================================"

[ -f /etc/ssh/sshd_config.bak ] || sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sudo sed -i 's/^#*Port .*/Port 20022/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
grep -q "^Port 20022" /etc/ssh/sshd_config || echo "Port 20022" | sudo tee -a /etc/ssh/sshd_config > /dev/null
grep -q "^PermitRootLogin no" /etc/ssh/sshd_config || echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config > /dev/null

sudo systemctl stop ssh.socket 2>/dev/null || true
sudo systemctl disable ssh.socket 2>/dev/null || true
sudo systemctl enable --now ssh.service
sudo systemctl restart ssh

echo ""
echo "============================================================"
echo "[Step 1-2] UFW 방화벽 설정 및 활성화 중..."
echo "============================================================"

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 20022/tcp
sudo ufw allow 15034/tcp
sudo ufw --force enable

echo ""
echo "============================================================"
echo "[Step 2-1] 그룹(agent-common, agent-core) 및 계정 3개 생성 중..."
echo "============================================================"

getent group agent-common >/dev/null || sudo groupadd agent-common
getent group agent-core >/dev/null || sudo groupadd agent-core

id -u agent-admin >/dev/null 2>&1 || sudo useradd -m -s /bin/bash agent-admin
id -u agent-dev   >/dev/null 2>&1 || sudo useradd -m -s /bin/bash agent-dev
id -u agent-test  >/dev/null 2>&1 || sudo useradd -m -s /bin/bash agent-test

sudo usermod -aG agent-common,agent-core agent-admin
sudo usermod -aG agent-common,agent-core agent-dev
sudo usermod -aG agent-common agent-test

echo ""
echo "============================================================"
echo "[Step 2-2] 디렉토리 구조 생성 및 소유권/권한/ACL 적용 중..."
echo "============================================================"

sudo mkdir -p /home/agent-admin/agent-app/upload_files
sudo mkdir -p /home/agent-admin/agent-app/api_keys
sudo mkdir -p /home/agent-admin/agent-app/bin
sudo mkdir -p /var/log/agent-app

# 상위 디렉토리 통과 권한
sudo chmod 755 /home/agent-admin
sudo chown agent-admin:agent-common /home/agent-admin/agent-app
sudo chmod 750 /home/agent-admin/agent-app

# upload_files (agent-common R/W)
sudo chown agent-admin:agent-common /home/agent-admin/agent-app/upload_files
sudo chmod 2770 /home/agent-admin/agent-app/upload_files
sudo setfacl -m g:agent-common:rwx /home/agent-admin/agent-app/upload_files
sudo setfacl -d -m g:agent-common:rwx /home/agent-admin/agent-app/upload_files

# api_keys (agent-core ONLY R/W)
sudo chown agent-admin:agent-core /home/agent-admin/agent-app/api_keys
sudo chmod 2770 /home/agent-admin/agent-app/api_keys
sudo setfacl -m g:agent-core:rwx /home/agent-admin/agent-app/api_keys
sudo setfacl -d -m g:agent-core:rwx /home/agent-admin/agent-app/api_keys

# bin (agent-dev 소유, agent-core 그룹)
sudo chown agent-dev:agent-core /home/agent-admin/agent-app/bin
sudo chmod 2770 /home/agent-admin/agent-app/bin

# /var/log/agent-app (agent-core ONLY R/W)
sudo chown agent-admin:agent-core /var/log/agent-app
sudo chmod 2770 /var/log/agent-app
sudo setfacl -m g:agent-core:rwx /var/log/agent-app
sudo setfacl -d -m g:agent-core:rwx /var/log/agent-app

echo ""
echo "============================================================"
echo "✅ [복구 완료] Step 0 ~ Step 2-2 상태 검증 요약"
echo "============================================================"
echo "--- [1] SSH 설정 및 포트 ---"
grep -E "^(Port|PermitRootLogin)" /etc/ssh/sshd_config
sudo ss -tulnp | grep sshd

echo ""
echo "--- [2] UFW 방화벽 상태 ---"
sudo ufw status verbose

echo ""
echo "--- [3] 계정 및 그룹 ---"
id agent-admin
id agent-dev
id agent-test

echo ""
echo "--- [4] 디렉토리 권한 및 ACL ---"
ls -ld /home/agent-admin/agent-app \
       /home/agent-admin/agent-app/upload_files \
       /home/agent-admin/agent-app/api_keys \
       /home/agent-admin/agent-app/bin \
       /var/log/agent-app

echo ""
echo "🎉 모든 복구가 끝났습니다! 이제 Step 3부터 이어서 진행하세요."
