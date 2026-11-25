# Codyssey B4-1 — 요구사항 수행 내역서

> **미션명**: 컴퓨터가 알아서 자기 상태를 점검하게 만들기  
> **핵심 목표**: 리눅스 다중 사용자 권한 관리, 네트워크 보안 설정, 애플리케이션 배포 환경 구성, Bash 기반 시스템 관제 및 `cron` 자동화 구축

---

## 📋 수행 환경 및 제출 산출물 요약

| 항목 | 내용 |
| :--- | :--- |
| **운영체제 (OS)** | Ubuntu 22.04 LTS (`OrbStack` Linux Machine: `cody-ubuntu`) |
| **CPU 아키텍처** | `x86_64` (`agent-app-linux-x86` 사용) |
| **자동화 구현 언어** | Bash Shell Script (`#!/usr/bin/env bash`) |
| **산출물 1 (문서)** | [`README.md`](./README.md) — 요구사항 수행 내역서 (본 문서) |
| **산출물 2 (스크립트)** | [`monitor.sh`](./monitor.sh) — 시스템 상태 수집·점검·로깅·로테이션 자동화 스크립트 |

### ✅ 필수 증거 자료 체크리스트

| 번호 | 체크리스트 항목 | 상태 | 바로가기 |
| :---: | :--- | :---: | :--- |
| 1 | SSH 포트 변경(`20022`) 및 Root 원격 접속 차단 설정 확인 내역 | ✅ 완료 | [1-1. SSH 보안 설정](#1-1-ssh-포트-변경20022-및-root-원격-로그인-차단) |
| 2 | 방화벽(`UFW`) 활성화 및 `20022/tcp`, `15034/tcp`만 허용 내역 | ✅ 완료 | [1-2. 방화벽(UFW) 설정](#1-2-방화벽ufw-활성화-및-허용-포트-설정) |
| 3 | 계정/그룹(`agent-admin/dev/test`, `agent-common/core`) 생성 확인 내역 | ✅ 완료 | [2-1. 계정 및 그룹 생성](#2-1-역할-기반-계정-및-그룹-생성) |
| 4 | 디렉터리 구조 및 권한(ACL 포함) 확인 내역 | ✅ 완료 | [2-2. 디렉터리 구조 및 권한/ACL](#2-2-디렉터리-구조-및-접근-권한posix--setgid--acl-설정) |
| 5 | 앱 Boot Sequence 5단계 `[OK]` 및 `"Agent READY"` 확인 내역 | ✅ 완료 | [3. 애플리케이션 실행 환경 구성](#3-애플리케이션-실행-환경-구성-및-구동) |
| 6 | `monitor.sh` 실행 결과(프로세스/포트/리소스/경고) 내역 | ✅ 완료 | [4. 시스템 관제 스크립트 구현](#4-시스템-관제-자동화-스크립트monitor-sh-구현) |
| 7 | `/var/log/agent-app/monitor.log` 누적 기록 확인(최근 라인) 내역 | ✅ 완료 | [5-2. 로그 자동 누적 검증](#5-2-varlogagent-appmonitorlog-누적-기록-확인) |
| 8 | `crontab` 매분 실행 등록 및 자동 실행 확인(1분 후 로그 증가) 내역 | ✅ 완료 | [5-1. crontab 매분 실행 등록](#5-1-agent-admin-계정-crontab-매분-실행-등록) |

---

## 🗂️ 구축된 시스템 디렉터리 및 권한 구조

```text
/
├── etc/
│   ├── ssh/sshd_config                  # Port 20022, PermitRootLogin no
│   └── ufw/                             # Default deny incoming, 20022/tcp & 15034/tcp ALLOW
│
├── home/agent-admin/                    # 755 (agent-admin:agent-admin) — 하위 공유 폴더 통과용
│   ├── .bashrc                          # AGENT_HOME 등 5개 환경 변수 영구 등록
│   └── agent-app/                       # [$AGENT_HOME] 750 (agent-admin:agent-common)
│       ├── agent_app.py                 # 750 (agent-admin:agent-core) — 제공된 실행 바이너리
│       ├── upload_files/                # 2770 + ACL (agent-admin:agent-common) — admin/dev/test R/W
│       ├── api_keys/                    # 2770 + ACL (agent-admin:agent-core)   — admin/dev ONLY R/W
│       │   └── secret.key               # 640 (agent-admin:agent-core)         — 내용: agent_api_key_test
│       └── bin/                         # 2770 (agent-dev:agent-core)
│           └── monitor.sh               # 750 (agent-dev:agent-core)           — cron 매분 실행 대상
│
└── var/log/agent-app/                   # 2770 + ACL (agent-admin:agent-core)   — admin/dev ONLY R/W
    ├── agent_app.log                    # 앱 자체 로그
    └── monitor.log                      # monitor.sh 누적 기록 (10MB / 최대 10개 로테이션)
```

---

## 1. 기본 보안 및 네트워크 설정

### 1-1. SSH 포트 변경(`20022`) 및 Root 원격 로그인 차단

* **목적**: 기본 SSH 포트(`22`)와 최고 관리자(`root`)를 노리는 자동화 무차별 대입 공격(Brute-force Attack)을 사전에 차단합니다.
* **수행 명령어**:
  ```bash
  # 1) 설정 파일 백업 및 수정
  sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
  sudo sed -i 's/^#*Port .*/Port 20022/' /etc/ssh/sshd_config
  sudo sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config

  # 2) Ubuntu 22.04 ssh.socket 비활성화 후 ssh.service로 적용 및 재시작
  sudo systemctl stop ssh.socket 2>/dev/null || true
  sudo systemctl disable ssh.socket 2>/dev/null || true
  sudo systemctl enable --now ssh.service
  sudo systemctl restart ssh

  # 3) 설정 및 LISTEN 포트 검증
  grep -E "^(Port|PermitRootLogin)" /etc/ssh/sshd_config
  sudo ss -tulnp | grep sshd
  ```
* **확인 결과**:
  ```text
  Port 20022
  PermitRootLogin no
  tcp   LISTEN 0      128                 0.0.0.0:20022      0.0.0.0:*    users:(("sshd",pid=4409,fd=3))
  tcp   LISTEN 0      128                    [::]:20022         [::]:*    users:(("sshd",pid=4409,fd=4))
  ```
* **증거 스크린샷**:

![필수 증거 자료 1 - SSH 설정 및 포트 LISTEN 확인](./screenshots/%5B%ED%95%84%EC%88%98%20%EC%A6%9D%EA%B1%B0%20%EC%9E%90%EB%A3%8C%201%5D%20SSH%20%EC%84%A4%EC%A0%95%20%EB%B0%8F%20%ED%8F%AC%ED%8A%B8%20LISTEN%20%ED%99%95%EC%9D%B8.png)

---

### 1-2. 방화벽(`UFW`) 활성화 및 허용 포트 설정

* **목적**: 기본 인바운드 트래픽을 모두 차단(`Default Deny`)하고, 운영에 반드시 필요한 SSH(`20022/tcp`)와 애플리케이션(`15034/tcp`) 포트만 허용하는 화이트리스트 정책을 적용합니다.
* **수행 명령어**:
  ```bash
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow 20022/tcp
  sudo ufw allow 15034/tcp
  sudo ufw --force enable
  sudo ufw status verbose
  ```
* **확인 결과**:
  ```text
  Status: active
  Logging: on (low)
  Default: deny (incoming), allow (outgoing), deny (routed)
  New profiles: skip

  To                         Action      From
  --                         ------      ----
  20022/tcp                  ALLOW IN    Anywhere
  15034/tcp                  ALLOW IN    Anywhere
  20022/tcp (v6)             ALLOW IN    Anywhere (v6)
  15034/tcp (v6)             ALLOW IN    Anywhere (v6)
  ```
* **증거 스크린샷**:

![필수 증거 자료 2 - 방화벽 상태 확인](./screenshots/%5B%ED%95%84%EC%88%98%20%EC%A6%9D%EA%B1%B0%20%EC%9E%90%EB%A3%8C%202%5D%20%EB%B0%A9%ED%99%94%EB%B2%BD%20%EC%83%81%ED%83%9C%20%ED%99%95%EC%9D%B8.png)

---

## 2. 계정 / 그룹 / 권한 체계 (협업 + 최소 권한)

### 2-1. 역할 기반 계정 및 그룹 생성

* **설계 정책**:

  | 계정명 | 역할 | 소속 그룹 |
  | :--- | :--- | :--- |
  | `agent-admin` | 운영/관리, 앱 구동 및 `cron` 실행자 | `agent-common`, `agent-core` |
  | `agent-dev` | 개발/운영, `monitor.sh` 작성 및 소유자 | `agent-common`, `agent-core` |
  | `agent-test` | QA/테스트 (공유 영역만 접근, 보안 영역 차단) | `agent-common` |

* **수행 명령어**:
  ```bash
  sudo groupadd agent-common
  sudo groupadd agent-core

  sudo useradd -m -s /bin/bash agent-admin
  sudo useradd -m -s /bin/bash agent-dev
  sudo useradd -m -s /bin/bash agent-test

  sudo usermod -aG agent-common,agent-core agent-admin
  sudo usermod -aG agent-common,agent-core agent-dev
  sudo usermod -aG agent-common agent-test

  id agent-admin
  id agent-dev
  id agent-test
  ```
* **확인 결과**:
  ```text
  uid=1000(agent-admin) gid=1002(agent-admin) groups=1002(agent-admin),1000(agent-common),1001(agent-core)
  uid=1001(agent-dev)   gid=1003(agent-dev)   groups=1003(agent-dev),1000(agent-common),1001(agent-core)
  uid=1002(agent-test)  gid=1004(agent-test)  groups=1004(agent-test),1000(agent-common)
  ```
* **증거 스크린샷**:

![필수 증거 자료 3 - 계정 및 그룹 생성 확인](./screenshots/%5B%ED%95%84%EC%88%98%20%EC%A6%9D%EA%B1%B0%20%EC%9E%90%EB%A3%8C%203%5D%20%EA%B3%84%EC%A0%95%20%EB%B0%8F%20%EA%B7%B8%EB%A3%B9%20%EC%83%9D%EC%84%B1%20%ED%99%95%EC%9D%B8.png)

---

### 2-2. 디렉터리 구조 및 접근 권한(POSIX + SetGID + ACL) 설정

* **권한 설계 포인트**:
  * **상위 경로 통과 권한**: `agent-dev`, `agent-test`가 하위 공유 디렉터리에 접근할 수 있도록 `/home/agent-admin`(`755`) 및 `$AGENT_HOME`(`750`, 그룹 `agent-common`)에 디렉터리 진입(`x`) 권한을 부여했습니다.
  * **SetGID(`2770`) + Default ACL(`setfacl -d`)**: 협업 폴더 안에서 어떤 계정이 새 파일/하위 폴더를 생성하더라도 **소유 그룹과 그룹 쓰기 권한(`rwx`)이 자동 상속**되도록 구성하고, 기타 사용자 권한을 `0`(`---`)으로 막아 `agent-test`의 보안 디렉터리 접근을 원천 차단했습니다.
* **수행 명령어**:
  ```bash
  # 디렉터리 생성
  sudo mkdir -p /home/agent-admin/agent-app/{upload_files,api_keys,bin} /var/log/agent-app

  # 상위 디렉터리 통과 권한
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
  ```
* **권한 및 ACL 검증 결과**:
  ```text
  drwxr-x---  1 agent-admin agent-common 46 Nov 20 16:55 /home/agent-admin/agent-app
  drwxrws---+ 1 agent-admin agent-core    0 Nov 20 16:55 /home/agent-admin/agent-app/api_keys
  drwxrws---  1 agent-dev   agent-core    0 Nov 20 16:55 /home/agent-admin/agent-app/bin
  drwxrws---+ 1 agent-admin agent-common  0 Nov 20 16:55 /home/agent-admin/agent-app/upload_files
  drwxrws---+ 1 agent-admin agent-core    0 Nov 20 17:12 /var/log/agent-app
  ```
* **최소 권한 실전 검증 (`agent-test` 계정으로 직접 테스트)**:
  * `upload_files` 파일 생성/삭제 → **허용 (`OK`)**
  * `api_keys` 접근 → **`Permission denied` (차단 확인)**
  * `/var/log/agent-app` 접근 → **`Permission denied` (차단 확인)**
* **증거 스크린샷**:

![필수 증거 자료 4-1 - 디렉터리 구조 및 권한 확인](./screenshots/%5B%ED%95%84%EC%88%98%20%EC%A6%9D%EA%B1%B0%20%EC%9E%90%EB%A3%8C%204%5D%20%EB%94%94%EB%A0%89%ED%86%A0%EB%A6%AC%20%EA%B5%AC%EC%A1%B0%20%EB%B0%8F%20%EA%B6%8C%ED%95%9C%28ACL%20%ED%8F%AC%ED%95%A8%29%20%ED%99%95%EC%9D%B81.png)

![필수 증거 자료 4-2 - getfacl ACL 상세 확인](./screenshots/%5B%ED%95%84%EC%88%98%20%EC%A6%9D%EA%B1%B0%20%EC%9E%90%EB%A3%8C%204%5D%20%EB%94%94%EB%A0%89%ED%86%A0%EB%A6%AC%20%EA%B5%AC%EC%A1%B0%20%EB%B0%8F%20%EA%B6%8C%ED%95%9C%28ACL%20%ED%8F%AC%ED%95%A8%29%20%ED%99%95%EC%9D%B82.png)

---

## 3. 애플리케이션 실행 환경 구성 및 구동

### 3-1. 바이너리 배치, 키 파일 생성 및 환경 변수 설정

> **⚠️ 특이사항 (제공 바이너리 검증 로직과의 차이점 대응)**  
> 미션 명세서에는 `AGENT_KEY_PATH`가 `$AGENT_HOME/api_keys/t_secret.key` 및 파일명 `t_secret.key`로 기재되어 있으나, 실제 제공된 실행 바이너리(`agent-app-linux-x86`) 내부의 `BootValidator` 검증 로직을 확인한 결과 다음과 같이 동작함을 확인했습니다.
> 1. `[2/5] Verifying Environment Variables`: `AGENT_KEY_PATH`가 디렉터리 경로인 **`$AGENT_HOME/api_keys`**와 일치하는지 검사합니다.
> 2. `[3/5] Checking Required Files`: `$AGENT_HOME/api_keys/` 하위에서 **`secret.key`** 파일의 내용(`agent_api_key_test`)을 검사합니다.
>
> 이에 따라 실제 앱의 부트 시퀀스를 정상 통과할 수 있도록 키 파일은 **`$AGENT_HOME/api_keys/secret.key`**(`640`, `agent-admin:agent-core`), 환경 변수는 **`AGENT_KEY_PATH="$AGENT_HOME/api_keys"`**로 구성했습니다.

* **수행 명령어**:
  ```bash
  # 1) 아키텍처(x86_64)에 맞는 실행 파일 배치 및 권한 설정
  sudo cp ./etc/agent-app/agent-app-linux-x86 /home/agent-admin/agent-app/agent_app.py
  sudo chown agent-admin:agent-core /home/agent-admin/agent-app/agent_app.py
  sudo chmod 750 /home/agent-admin/agent-app/agent_app.py

  # 2) 키 파일 생성 및 권한 설정 (640)
  echo "agent_api_key_test" | sudo tee /home/agent-admin/agent-app/api_keys/secret.key > /dev/null
  sudo chown agent-admin:agent-core /home/agent-admin/agent-app/api_keys/secret.key
  sudo chmod 640 /home/agent-admin/agent-app/api_keys/secret.key

  # 3) agent-admin 계정 전환 후 ~/.bashrc에 5개 환경 변수 영구 등록
  sudo su - agent-admin
  cat << 'EOF' >> ~/.bashrc
  export AGENT_HOME="/home/agent-admin/agent-app"
  export AGENT_PORT="15034"
  export AGENT_UPLOAD_DIR="$AGENT_HOME/upload_files"
  export AGENT_KEY_PATH="$AGENT_HOME/api_keys"
  export AGENT_LOG_DIR="/var/log/agent-app"
  EOF
  source ~/.bashrc
  env | grep AGENT_
  ```

### 3-2. 앱 실행, Boot Sequence 5단계 `[OK]` 및 `15034` 포트 LISTEN 확인

* **실행 결과 (`agent-admin` 일반 계정으로 실행)**:
  ```text
  >>> Starting Agent Boot Sequence...
  [1/5] Checking User Account               [OK]
     ... Running as service user 'agent-admin' (uid=1000)
  [2/5] Verifying Environment Variables     [OK]
     ... All required Envs correct
  [3/5] Checking Required Files             [OK]
     ... Verified 'secret.key' with correct key string.
  [4/5] Checking Port Availability          [OK]
     ... Port 15034 is available.
  [5/5] Verifying Log Permission            [OK]
     ... Log directory is writable: /var/log/agent-app
  ------------------------------------------------------------
  All Boot Checks Passed!
  Agent READY
  2026-11-25 17:14:46,531 [INFO] Agent listening at port 15034
  ```
* **포트 리슨 확인 (`ss -tulnp | grep 15034`)**:
  ```text
  tcp   LISTEN 0      1                   0.0.0.0:15034      0.0.0.0:*    users:(("agent_app.py",pid=690,fd=4))
  ```
* **증거 스크린샷**:

![필수 증거 자료 5 - 앱 실행 및 Boot Sequence 5단계 OK 확인](./screenshots/%5B%ED%95%84%EC%88%98%20%EC%A6%9D%EA%B1%B0%20%EC%9E%90%EB%A3%8C%205%5D%20%EC%95%B1%20%EC%8B%A4%ED%96%89%20%EB%B0%8F%20Boot%20Sequence%205%EB%8B%A8%EA%B3%84%20%5BOK%5D%20%ED%99%95%EC%9D%B8.png)

---

## 4. 시스템 관제 자동화 스크립트(`monitor.sh`) 구현

### 4-1. 파일 정책 및 구현 기능 요약

* **소스코드 파일**: [`./monitor.sh`](./monitor.sh) (서버 배치 경로: `$AGENT_HOME/bin/monitor.sh`)
* **소유권 및 권한**: `agent-dev:agent-core`, `750` (`-rwxr-x---`) → `agent-dev`가 작성·관리하고, `agent-core` 그룹 소속인 `agent-admin`이 실행 가능

| 점검 항목 | 구현 방식 | 비정상/임계치 초과 시 동작 |
| :--- | :--- | :--- |
| **프로세스 Health Check** | `pgrep -f "agent_app.py"`로 PID 확인 | 미실행 시 `[FAIL]` 출력 후 **`exit 1` 즉시 종료** |
| **포트 Health Check** | `ss -tuln`으로 TCP `15034` LISTEN 확인 | 미오픈 시 `[FAIL]` 출력 후 **`exit 1` 즉시 종료** |
| **방화벽 상태 점검** | `ufw status` 또는 `/etc/ufw/ufw.conf` 확인 | 비활성 시 **`[WARNING]`만 출력**하고 계속 진행 |
| **자원 수집 (CPU/MEM/DISK)** | `/proc/stat`(0.5초 차분), `free`, `df -P /` | 소수점 첫째 자리 CPU/MEM(%) 및 루트 디스크(%) 수집 |
| **임계값 경고** | `CPU > 20%`, `MEM > 10%`, `DISK_USED > 80%` | 기준 초과 시 **`[WARNING]`만 출력**하고 계속 진행 |
| **로그 기록 및 용량 관리** | `/var/log/agent-app/monitor.log` 누적 | **`10MB` 초과 시 자동 로테이션(최대 10개 파일 유지)** |

### 4-2. 권한 확인 및 수동 실행 결과

* **수행 명령어**:
  ```bash
  # agent-dev 계정에서 권한 설정 및 문법 검증
  chmod 750 /home/agent-admin/agent-app/bin/monitor.sh
  bash -n /home/agent-admin/agent-app/bin/monitor.sh

  # agent-admin 계정에서 앱 구동 후 monitor.sh 실행 검증
  sudo su - agent-admin
  ls -l /home/agent-admin/agent-app/bin/monitor.sh
  /home/agent-admin/agent-app/bin/monitor.sh
  ```
* **확인 결과**:
  ```text
  -rwxr-x--- 1 agent-dev agent-core 5719 Nov 25 18:08 /home/agent-admin/agent-app/bin/monitor.sh

  ===== SYSTEM MONITOR RESULT =====

  [HEALTH CHECK]
  Checking process 'agent_app.py'... [OK] (PID: 688)
  Checking port 15034... [OK]

  [RESOURCE MONITORING]
  CPU Usage : 5.0%
  MEM Usage : 2.5%
  DISK Used : 1%

  ====== STATISTICS REPORT ======
  [CPU]
  Average : 5.0%
  Maximum : 5.0% at 2026-11-25 18:09:18
  Minimum : 5.0% at 2026-11-25 18:09:18
  [Memory]
  Average : 2.5%
  Maximum : 2.5% at 2026-11-25 18:09:18
  Minimum : 2.5% at 2026-11-25 18:09:18
  [Samples]
  Data Points: 1 samples

  [INFO] Log appended: /var/log/agent-app/monitor.log
  ```
* **증거 스크린샷**:

![필수 증거 자료 6 - monitor.sh 수동 실행 및 권한 확인](./screenshots/%5B%ED%95%84%EC%88%98%20%EC%A6%9D%EA%B1%B0%20%EC%9E%90%EB%A3%8C%206%5D%20monitor.sh%20%EC%88%98%EB%8F%99%20%EC%8B%A4%ED%96%89%20%EB%B0%8F%20%EA%B6%8C%ED%95%9C%20%ED%99%95%EC%9D%B8.png)

---

## 5. 자동 실행(`cron`) 설정 및 로그 누적 검증

### 5-1. `agent-admin` 계정 `crontab` 매분 실행 등록

* **수행 명령어**:
  ```bash
  sudo su - agent-admin
  (crontab -l 2>/dev/null | grep -v "monitor.sh"; echo "* * * * * /home/agent-admin/agent-app/bin/monitor.sh >/dev/null 2>&1") | crontab -
  crontab -l
  ```
* **등록 확인 결과**:
  ```text
  * * * * * /home/agent-admin/agent-app/bin/monitor.sh >/dev/null 2>&1
  ```

### 5-2. `/var/log/agent-app/monitor.log` 누적 기록 확인

* **확인 명령어**: `tail -n 15 /var/log/agent-app/monitor.log`
* **실제 누적 결과** (1분 간격으로 자동 실행되며 새 라인이 누적됨을 확인):
  ```text
  [2026-11-25 18:09:18] PID:688 CPU:5.0% MEM:2.5% DISK_USED:1%
  [2026-11-25 19:15:02] PID:688 CPU:3.1% MEM:3.5% DISK_USED:1%
  [2026-11-25 19:16:01] PID:688 CPU:3.7% MEM:3.5% DISK_USED:1%
  [2026-11-25 19:17:02] PID:688 CPU:6.0% MEM:3.5% DISK_USED:1%
  [2026-11-25 19:18:02] PID:688 CPU:5.6% MEM:3.5% DISK_USED:1%
  [2026-11-25 19:19:01] PID:688 CPU:0.0% MEM:3.5% DISK_USED:1%
  [2026-11-25 19:20:02] PID:688 CPU:5.3% MEM:3.6% DISK_USED:1%
  [2026-11-25 19:21:01] PID:688 CPU:3.4% MEM:3.7% DISK_USED:1%
  [2026-11-25 19:22:02] PID:688 CPU:1.4% MEM:3.7% DISK_USED:1%
  [2026-11-25 19:23:01] PID:688 CPU:4.4% MEM:3.6% DISK_USED:1%
  [2026-11-25 19:24:02] PID:688 CPU:4.7% MEM:3.7% DISK_USED:1%
  [2026-11-25 19:25:01] PID:688 CPU:5.0% MEM:3.7% DISK_USED:1%
  [2026-11-25 19:26:02] PID:688 CPU:0.0% MEM:3.6% DISK_USED:1%
  ```
* **증거 스크린샷**:

![필수 증거 자료 7 - crontab 등록 내역 및 로그 자동 누적 확인](./screenshots/%5B%ED%95%84%EC%88%98%20%EC%A6%9D%EA%B1%B0%20%EC%9E%90%EB%A3%8C%207%5D%20crontab%20%EB%93%B1%EB%A1%9D%20%EB%82%B4%EC%97%AD%20%EB%B0%8F%201~2%EB%B6%84%20%ED%9B%84%20%EB%A1%9C%EA%B7%B8%20%EC%9E%90%EB%8F%99%20%EB%88%84%EC%A0%81%20%ED%99%95%EC%9D%B8.png)

---

## 6. 트러블슈팅 및 핵심 개념 정리

### 🔧 실습 중 해결한 주요 트러블슈팅
1. **외부 HTTP(80) 차단으로 인한 `apt` 패키지 설치 지연 해결**
   * 초기 Ubuntu 설정 및 `apt install` 시 기본 저장소(`http://archive.ubuntu.com:80`) 연결이 거부되는 현상이 발생했습니다.
   * `/etc/apt/sources.list`를 HTTPS(443) 카카오 미러(`https://mirror.kakao.com/ubuntu`)로 전환하여 필수 패키지(`openssh-server`, `ufw`, `acl`, `cron` 등)를 정상 설치했습니다.
2. **제공 바이너리 내부 검증 로직 불일치 파악**
   * 미션 문서의 `t_secret.key` 대신 제공된 바이너리가 `AGENT_KEY_PATH="$AGENT_HOME/api_keys"`와 `secret.key`를 검증함을 확인하고, 실행 환경에 정확히 맞춰 Boot Sequence 5단계를 모두 통과시켰습니다.
3. **`cron` 환경 호환성 확보 (`#!/usr/bin/env bash` 및 `PATH` 고정)**
   * `cron`은 최소화된 환경 변수와 `/bin/sh` 기반으로 동작할 수 있으므로, `monitor.sh` 첫 줄에 `#!/usr/bin/env bash` 쉐뱅과 표준 `PATH`를 명시하고 `bash -n`으로 문법 오류를 사전 검증했습니다.

### 💡 과제 목표 핵심 정리
* **SSH 포트 변경 & Root 차단**: 잘 알려진 기본 포트(`22`)와 `root` 대상 자동화 무차별 대입 공격을 줄이고, 일반 계정 접속 후 필요 시에만 `sudo`를 사용하는 감사 가능한 보안 체계를 구축합니다.
* **방화벽 화이트리스트 정책 (`UFW`)**: 기본 인바운드를 모두 차단하고 서비스에 필수적인 `20022/tcp`, `15034/tcp`만 개방해 공격 표면(Attack Surface)을 최소화합니다.
* **역할 기반 권한 분리 & ACL**: 최소 권한의 원칙에 따라 공유 디렉터리(`upload_files`)와 민감 디렉터리(`api_keys`, `/var/log/agent-app`)를 그룹과 SetGID(`2770`)/Default ACL로 분리하여 QA 계정(`agent-test`)의 민감 정보 접근을 차단합니다.
* **환경 변수로 실행 환경 고정**: 경로·포트·키 위치를 코드에 하드코딩하지 않고 환경 변수(`AGENT_*`)로 주입하여 배포 환경 일관성과 유지보수성을 높입니다.
* **관제 스크립트 + `cron` + 로그 로테이션**: 프로세스·포트·자원을 매분 자동 수집·기록하여 장애 원인을 데이터로 추적하고, 로그 용량 제한(`10MB/10개`)으로 디스크 고갈(Disk Full) 장애를 예방합니다.
