# B4-1 미션 실습 완벽 가이드라인 (OrbStack 초기 설정부터 최종 제출까지)

이 문서는 **초급 개발자**가 아무것도 설정되지 않은 초기 **OrbStack(macOS)** 환경에서 시작하여, [B4-1-Mission.md](file:///Users/[ID_Masking]/Codyssey-B4-1/etc/B4-1-Mission.md)의 모든 필수 요구사항과 보너스 과제까지 스스로 이해하며 완수할 수 있도록 작성된 단계별 실습 가이드입니다. 각 단계마다 **사용된 명령어와 옵션(`-m`, `-i`, `-tulnp`, `-aG` 등)의 정확한 의미**를 함께 정리했습니다.

---

## 0. 시작 전 전체 흐름 및 쉘 기본 기호 파악하기

### 실습 로드맵
1. **Step 0. 실습 환경 구축**: OrbStack에 Ubuntu 22.04 리눅스 가상머신(Machine) 생성 및 필수 패키지 설치
2. **Step 1. 기본 보안 및 네트워크 설정**: SSH 포트(`20022`) 변경, `root` 원격 로그인 차단, 방화벽(`UFW`) 설정
3. **Step 2. 계정·그룹·권한 체계 구축**: 3개 계정(`agent-admin`, `agent-dev`, `agent-test`), 2개 그룹(`agent-common`, `agent-core`), 폴더 권한 및 ACL 설정
4. **Step 3. 애플리케이션 실행 환경 구성**: 맥에 있는 `agent-app`을 우분투로 복사, 환경 변수 및 키 파일 설정 후 앱 구동(`Agent READY`)
5. **Step 4. 관제 스크립트(`monitor.sh`) 작성**: 프로세스/포트 헬스체크, 리소스(CPU/MEM/DISK) 수집, 임계치 경고, 로그 기록 및 용량 관리(10MB/10개)
6. **Step 5. 스케줄러(`cron`) 자동화**: `agent-admin`의 `crontab`에 매분(`* * * * *`) 실행 등록 및 누적 확인
7. **Step 6. (선택) 보너스 과제 1 & 2**: 통계 리포트(`report.sh`) 및 시간 기반 로그 아카이브/삭제
8. **Step 7. 최종 산출물 정리**: `요구사항 수행 내역서` 문서 + `monitor.sh` 소스코드 제출

### 자주 등장하는 리눅스 쉘(Shell) 특수 기호 사전
실습 명령어에 공통으로 등장하는 기호들의 정석 의미입니다.
* **`sudo` (Superuser Do)**: 일반 사용자가 최고 관리자(`root`) 권한을 빌려 명령어를 실행할 때 맨 앞에 붙입니다.
* **`|` (Pipe, 파이프)**: 왼쪽 명령어의 **표준 출력 결과(stdout)**를 오른쪽 명령어의 **표준 입력(stdin)**으로 넘겨줍니다. (예: `A | grep B` → A의 결과 중에서 B가 포함된 줄만 필터링)
* **`>` (덮어쓰기 리다이렉션)**: 명령어의 출력 결과를 화면 대신 파일에 저장합니다. (기존 파일 내용은 지워짐)
* **`>>` (이어쓰기 리다이렉션, Append)**: 명령어의 출력 결과를 기존 파일의 **맨 끝에 덧붙여** 저장합니다.
* **`2>/dev/null`**: 에러 메시지(표준 에러, 번호 `2`)를 리눅스의 블랙홀 장치인 `/dev/null`로 버려서 화면에 에러가 출력되지 않게 숨깁니다.
* **`>/dev/null 2>&1`**: 일반 출력(`1`)과 에러 출력(`2`)을 모두 `/dev/null`로 버려 아무 메시지도 출력하지 않게 합니다.
* **`||` (논리 OR)**: 왼쪽 명령어가 **실패(종료 코드 ≠ 0)했을 때만** 오른쪽 명령어를 실행합니다.
* **`&&` (논리 AND)**: 왼쪽 명령어가 **성공(종료 코드 = 0)했을 때만** 오른쪽 명령어를 실행합니다.

---

## Step 0. OrbStack 초기 설정 및 Ubuntu 22.04 환경 만들기

OrbStack이 처음 설치된 상태라면, 실습을 진행할 **Ubuntu 22.04 LTS 가상머신(Machine)**을 하나 만들어야 합니다.

### 0-1. OrbStack에서 Ubuntu 22.04 머신 생성하기 (GUI 방법)
1. 맥의 응용 프로그램(Applications)에서 **OrbStack** 앱을 실행합니다.
2. 왼쪽 사이드바에서 **Machines** 탭을 클릭합니다.
3. 화면 중앙(또는 우측 상단 `+` 버튼)의 **New Machine**을 클릭합니다.
4. 아래와 같이 입력하고 **Create**를 누릅니다.
   - **Name**: `ubuntu` (원하는 이름으로 지정 가능)
   - **Distro**: `Ubuntu`
   - **Version**: `22.04 (Jammy)`
   - **Architecture**: 기본값 그대로 유지 (현재 사용 중인 맥이 Intel CPU라면 `amd64 / x86_64`, Apple Silicon이라면 `arm64`가 자동 선택됩니다)

### 0-2. 생성한 우분투 터미널에 접속하기
* **방법 A (OrbStack 앱 사용)**: OrbStack의 **Machines** 목록에 생성된 `ubuntu`를 더블클릭하거나 우측의 **터미널 아이콘(`>_`)**을 누르면 곧바로 우분투 터미널 창이 열립니다.
* **방법 B (맥 기본 터미널 / VS Code 터미널 사용)**: 터미널에서 아래 명령어를 입력하면 우분투 안으로 들어갑니다.
  ```bash
  orb -m ubuntu
  ```
  > 💡 **우분투 안에 들어왔는지 확인하는 법**: 프롬프트(명령어 입력줄 맨 앞)가 `계정명@ubuntu:~$` 형태로 바뀌고, `lsb_release -a`를 입력했을 때 `Ubuntu 22.04`가 나오면 성공입니다! 이제부터 아래의 모든 실습 명령어는 **이 우분투 터미널 안에서** 입력합니다.

#### 🔍 명령어 및 옵션 상세 해설
* **`orb -m ubuntu`**
  * `orb`: OrbStack을 터미널에서 제어하는 CLI 명령어입니다.
  * `-m ubuntu` (`--machine`): 여러 가상머신 중 접속할 대상 머신의 이름(`ubuntu`)을 지정합니다.
* **`lsb_release -a`**
  * `lsb_release`: 현재 리눅스 배포판(Linux Standard Base) 정보를 확인하는 명령어입니다.
  * `-a` (`--all`): 배포판 이름(Ubuntu), 버전(22.04), 코드네임(jammy) 등 모든 정보를 한 번에 출력합니다.

### 0-3. 실습에 필요한 리눅스 기본 도구(패키지) 설치
OrbStack의 기본 우분투 이미지는 가볍게 만들어져 있어서 SSH 서버(`openssh-server`), 방화벽(`ufw`), ACL 도구(`acl`), 스케줄러(`cron`) 등이 설치되어 있지 않거나 꺼져 있을 수 있습니다. 아래 명령어로 한 번에 설치하고 서비스를 켭니다.

```bash
# 패키지 목록 업데이트 및 필수 패키지 설치
sudo apt update
sudo apt install -y openssh-server ufw acl cron iproute2 procps logrotate bc

# cron 서비스 시작 및 부팅 시 자동 시작 활성화
sudo systemctl enable --now cron
```

#### 🔍 명령어 및 옵션 상세 해설
* **`sudo apt update`**
  * `apt`: 우분투의 패키지 관리자(Advanced Package Tool)입니다.
  * `update`: 인터넷의 우분투 공식 저장소에서 "어떤 프로그램들의 어떤 버전이 있는지" 최신 목록을 받아옵니다. (`install` 전에 반드시 먼저 실행해야 합니다.)
* **`sudo apt install -y ...`**
  * `install`: 지정한 패키지들을 다운로드하여 설치합니다.
    * `openssh-server`: 원격 접속을 받아주는 SSH 데몬(`sshd`)
    * `ufw`: 우분투 표준 방화벽 도구(Uncomplicated Firewall)
    * `acl`: 확장 권한 설정 도구(`setfacl`, `getfacl` 명령어 제공)
    * `cron`: 주기적 자동 실행 스케줄러 데몬
    * `iproute2`: 네트워크 및 포트 확인 도구(`ss` 명령어 제공)
    * `procps`: 프로세스 및 메모리 상태 확인 도구(`ps`, `pgrep`, `free` 명령어 제공)
  * `-y` (`--yes`): 설치 도중 *"계속 설치하시겠습니까? [Y/n]"*라고 물어볼 때 자동으로 `Y`(예)를 입력해 멈추지 않고 설치를 끝냅니다.
* **`sudo systemctl enable --now cron`**
  * `systemctl`: 리눅스의 백그라운드 서비스(Systemd 데몬)를 켜고 끄는 관리 명령어입니다.
  * `enable`: 서버가 재부팅될 때 `cron` 서비스가 자동으로 켜지도록 등록합니다.
  * `--now`: 자동 시작 등록(`enable`)과 동시에 **지금 즉시 서비스를 시작(`start`)**하라는 옵션입니다. (`systemctl enable cron`과 `systemctl start cron` 두 줄을 한 줄로 합친 정석 옵션입니다.)

---

## Step 1. 기본 보안 및 네트워크 설정 (기능 요구사항 1)

### 1-1. SSH 포트 변경(`20022`) 및 Root 원격 로그인 차단

#### 개념 이해
* SSH 데몬(`sshd`)의 설정 파일은 `/etc/ssh/sshd_config`입니다.
* 기본 포트 `22`를 `20022`로 바꾸고, `PermitRootLogin no`로 설정해 `root` 계정의 직접 원격 로그인을 차단합니다.

#### 실행 명령어
```bash
# 1) sshd_config 백업 (설정 파일 수정 전 백업은 엔지니어의 기본 습관입니다)
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# 2) 설정 파일에서 Port와 PermitRootLogin 값을 치환
sudo sed -i 's/^#*Port .*/Port 20022/' /etc/ssh/sshd_config
sudo sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config

# 3) 만약 파일 안에 해당 설정 줄이 아예 없었다면 파일 끝에 추가
grep -q "^Port 20022" /etc/ssh/sshd_config || echo "Port 20022" | sudo tee -a /etc/ssh/sshd_config
grep -q "^PermitRootLogin no" /etc/ssh/sshd_config || echo "PermitRootLogin no" | sudo tee -a /etc/ssh/sshd_config
```

#### ⚠️ Ubuntu 22.04+ 중요 주의사항 (`ssh.socket` 비활성화)
최신 우분투에서는 `systemd`의 소켓 활성화(`ssh.socket`) 기능이 켜져 있으면 `sshd_config`의 `Port 20022` 설정을 무시하고 계속 `22`번 포트로 열리는 현상이 발생할 수 있습니다. 아래 명령어로 `ssh.socket`을 끄고 정석대로 `ssh.service`를 재시작합니다.

```bash
sudo systemctl stop ssh.socket 2>/dev/null || true
sudo systemctl disable ssh.socket 2>/dev/null || true
sudo systemctl enable --now ssh.service
sudo systemctl restart ssh
```

#### ✅ [필수 증거 자료 1] SSH 설정 및 포트 LISTEN 확인
아래 두 명령어의 출력 결과를 복사(또는 캡처)해 두세요.
```bash
# 설정 파일에서 Port와 PermitRootLogin 확인
grep -E "^(Port|PermitRootLogin)" /etc/ssh/sshd_config

# 20022 포트로 sshd가 LISTEN 중인지 확인
sudo ss -tulnp | grep sshd
```
> **기대 결과**: `Port 20022`, `PermitRootLogin no`가 출력되고, `ss -tulnp` 결과에 `0.0.0.0:20022` (및 `[::]:20022`) `users:(("sshd",...))`가 보이면 성공입니다.

#### 🔍 명령어 및 옵션 상세 해설
* **`sudo sed -i 's/^#*Port .*/Port 20022/' /etc/ssh/sshd_config`**
  * `sed`: 텍스트 파일을 줄 단위로 읽어서 문자열을 치환·편집하는 **스트림 에디터(Stream Editor)**입니다.
  * `-i` (`--in-place`): 바뀐 결과를 화면에만 보여주고 끝내는 것이 아니라, **원본 파일에 직접 저장(덮어쓰기)**하라는 옵션입니다.
  * `'s/찾을패턴/바꿀문자열/'`: `s`는 Substitute(치환)를 뜻합니다.
    * `^#*Port .*`: 정규표현식으로, 줄의 맨 앞(`^`)에 주석 기호 `#`이 0개 이상(`#*`) 붙어 있고 `Port `로 시작하는 줄 전체(`.*`)를 찾아서 `Port 20022`로 바꾸라는 뜻입니다. (즉, `#Port 22`처럼 주석 처리되어 있던 줄도 주석을 풀면서 `Port 20022`로 바꿔줍니다.)
* **`grep -q "^Port 20022" /etc/ssh/sshd_config`**
  * `grep`: 파일 안에서 특정 문자열 패턴이 있는 줄을 찾는 명령어입니다.
  * `-q` (`--quiet` 또는 `--silent`): 찾은 줄을 화면에 출력하지 않고 조용히 **성공(있으면 종료 코드 `0`) 또는 실패(없으면 종료 코드 `1`) 결과만 반환**합니다. 뒤의 `||`와 결합해 *"해당 줄이 파일에 없을 때만 추가하라"*는 조건문을 만들 때 씁니다.
* **`sudo tee -a /etc/ssh/sshd_config`**
  * `tee`: 파이프(`|`)로 넘어온 텍스트를 화면에도 보여주고 파일에도 동시에 저장하는 명령어입니다. (`sudo echo ... >> 파일`로 쓰면 `>>` 기호에는 `sudo` 권한이 적용되지 않아 `Permission denied`가 나기 때문에, 관리자 권한으로 파일 끝에 한 줄을 추가할 때는 `sudo tee -a`를 쓰는 것이 정석입니다.)
  * `-a` (`--append`): 기존 파일 내용을 덮어쓰지 않고 **파일 맨 끝에 덧붙여서 저장**합니다.
* **`grep -E "^(Port|PermitRootLogin)" /etc/ssh/sshd_config`**
  * `-E` (`--extended-regexp`): **확장 정규표현식**을 사용하겠다는 옵션입니다. 이 옵션을 켜야 `(Port|PermitRootLogin)`처럼 `|`(OR) 기호를 써서 "`Port` 또는 `PermitRootLogin`으로 시작하는 줄"을 한 번에 검색할 수 있습니다.
* **`sudo ss -tulnp`**
  * `ss` (Socket Statistics): 현재 서버의 네트워크 연결과 열린 포트 상태를 확인하는 표준 도구입니다. 각 알파벳 옵션의 의미는 매우 중요하므로 꼭 알아두세요!
  * `-t` (`--tcp`): **TCP** 프로토콜 소켓을 표시합니다.
  * `-u` (`--udp`): **UDP** 프로토콜 소켓을 표시합니다.
  * `-l` (`--listening`): 현재 포트를 열어두고 외부 접속을 대기 중인(**`LISTEN` 상태**) 소켓만 추려서 보여줍니다.
  * `-n` (`--numeric`): 포트 번호를 서비스 별명(예: `ssh`, `http`)으로 바꾸지 않고 **순수 숫자 포트 번호(`20022`, `15034`)** 그대로 보여줍니다.
  * `-p` (`--processes`): 그 포트를 **어떤 프로그램(프로세스 이름과 PID)이 열고 있는지** 함께 보여줍니다. (시스템 프로세스 이름을 보려면 앞에 `sudo`가 필요합니다.)

---

### 1-2. 방화벽(UFW) 활성화 및 허용 포트 설정

#### 개념 이해
* 외부에서 들어오는 모든 연결(Inbound)은 기본적으로 차단(`deny incoming`)하고, 나가는 연결(Outbound)은 허용(`allow outgoing`)합니다.
* 그 위에서 SSH 포트(`20022/tcp`)와 애플리케이션 포트(`15034/tcp`) 두 개만 명시적으로 허용합니다.

#### 실행 명령어
```bash
# 1) 기본 정책 설정 (인바운드 차단, 아웃바운드 허용)
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 2) 필수 포트 2개만 허용 (TCP 20022, TCP 15034)
sudo ufw allow 20022/tcp
sudo ufw allow 15034/tcp

# 3) 방화벽 활성화
sudo ufw --force enable
```

#### ✅ [필수 증거 자료 2] 방화벽 상태 확인
```bash
sudo ufw status verbose
```
> **기대 결과**: `Status: active`와 함께 `20022/tcp ALLOW IN`, `15034/tcp ALLOW IN`만 목록에 표시되면 성공입니다.

#### 🔍 명령어 및 옵션 상세 해설
* **`sudo ufw default deny incoming` / `allow outgoing`**
  * `default`: 특별한 허용 규칙이 없는 포트들에 적용할 **기본 정책**을 설정합니다.
  * `deny incoming`: 외부에서 서버로 들어오는(Inbound) 모든 트래픽을 기본 차단합니다.
  * `allow outgoing`: 서버 안에서 외부 인터넷으로 나가는(Outbound) 트래픽은 기본 허용합니다.
* **`sudo ufw allow 20022/tcp`**
  * `allow [포트]/[프로토콜]`: 지정한 포트와 프로토콜(TCP)로 들어오는 인바운드 접속을 허용 규칙(Whitelist)에 추가합니다.
* **`sudo ufw --force enable`**
  * `enable`: 방화벽을 켜고 부팅 시에도 자동으로 켜지도록 활성화합니다.
  * `--force`: 방화벽을 켤 때 *"Command may disrupt existing ssh connections. Proceed with operation (y|n)?"*라고 묻는 확인 질문을 건너뛰고 즉시 활성화합니다.
* **`sudo ufw status verbose`**
  * `status`: 현재 방화벽 활성화 여부와 허용된 포트 목록을 출력합니다.
  * `verbose`: 상세 출력 옵션입니다. 기본 정책(`Default: deny (incoming), allow (outgoing)`)과 로깅 상태까지 자세하게 보여줍니다.

---

## Step 2. 계정 / 그룹 / 권한 체계 구축 (기능 요구사항 2)

### 2-1. 그룹 및 계정 생성

#### 요구사항 구조
* **계정 3개**:
  * `agent-admin` (운영/관리, 앱 및 cron 실행자)
  * `agent-dev` (개발/운영, `monitor.sh` 작성자)
  * `agent-test` (QA/테스트)
* **그룹 2개**:
  * `agent-common`: `agent-admin`, `agent-dev`, `agent-test` (3명 모두 포함)
  * `agent-core`: `agent-admin`, `agent-dev` (보안 그룹, `agent-test` 제외)

#### 실행 명령어
```bash
# 1) 그룹 2개 생성
sudo groupadd agent-common
sudo groupadd agent-core

# 2) 계정 3개 생성
sudo useradd -m -s /bin/bash agent-admin
sudo useradd -m -s /bin/bash agent-dev
sudo useradd -m -s /bin/bash agent-test

# 3) 각 계정을 요구사항에 맞게 그룹에 추가
sudo usermod -aG agent-common,agent-core agent-admin
sudo usermod -aG agent-common,agent-core agent-dev
sudo usermod -aG agent-common agent-test
```

#### ✅ [필수 증거 자료 3] 계정 및 그룹 생성 확인
```bash
id agent-admin
id agent-dev
id agent-test
```
> **기대 결과**:
> - `agent-admin`: `groups=... agent-common,agent-core`
> - `agent-dev`: `groups=... agent-common,agent-core`
> - `agent-test`: `groups=... agent-common` (`agent-core`가 없어야 함!)

#### 🔍 명령어 및 옵션 상세 해설
* **`sudo groupadd [그룹명]`**: 새로운 사용자 그룹을 생성합니다.
* **`sudo useradd -m -s /bin/bash [계정명]`**
  * `useradd`: 새로운 사용자 계정을 생성하는 저수준(표준) 명령어입니다.
  * `-m` (`--create-home`): 사용자의 개인 홈 디렉토리(`/home/agent-admin` 등)를 자동으로 만들어 줍니다. (**주의**: `useradd`에서 `-m`을 빼먹으면 홈 폴더가 없는 계정이 만들어져서 환경 변수 파일 `~/.bashrc`를 만들 수 없습니다!)
  * `-s /bin/bash` (`--shell`): 사용자가 로그인했을 때 실행할 기본 쉘 프로그램을 `/bin/bash`로 지정합니다. (미지정 시 우분투에서는 기능이 축소된 `/bin/sh`가 할당되어 방향키나 탭 자동완성이 작동하지 않습니다.)
* **`sudo usermod -aG agent-common,agent-core agent-admin`**
  * `usermod` (User Modify): 이미 생성된 사용자의 속성이나 소속 그룹을 변경합니다.
  * `-a` (`--append`): 기존에 소속되어 있던 그룹을 지우지 않고 **유지한 상태에서 새 그룹을 추가**합니다.
  * `-G` (`--groups`): 사용자가 속할 보조 그룹(Supplementary Groups) 목록을 콤마(`,`)로 구분해 지정합니다. (**주의**: `-a` 없이 `-G`만 쓰면 기존 보조 그룹에서 모두 탈퇴되고 새로 적은 그룹만 남게 되므로 항상 `-aG`로 붙여 쓰는 것이 정석입니다!)
* **`id [계정명]`**: 해당 사용자의 고유 번호(`uid`), 기본 그룹 번호(`gid`), 그리고 소속된 모든 그룹(`groups`)을 출력합니다.

---

### 2-2. 디렉토리 구조 및 접근 권한(ACL 포함) 설정

#### 요구사항 구조 (`AGENT_HOME=/home/agent-admin/agent-app` 기준)
| 경로 | 소유 그룹 | 접근 권한 정책 |
| :--- | :--- | :--- |
| `/home/agent-admin/agent-app` (`$AGENT_HOME`) | `agent-common` | 하위 폴더에 접근할 수 있도록 읽기/실행(`750`) 허용 |
| `$AGENT_HOME/upload_files` | `agent-common` | `agent-common` 그룹(admin, dev, test) R/W 가능 (`2770` + ACL) |
| `$AGENT_HOME/api_keys` | `agent-core` | `agent-core` 그룹(admin, dev) **ONLY** R/W 가능 (`2770` + ACL) |
| `$AGENT_HOME/bin` | `agent-core` | `monitor.sh`가 위치할 디렉토리 (`2770`) |
| `/var/log/agent-app` | `agent-core` | `agent-core` 그룹(admin, dev) **ONLY** R/W 가능 (`2770` + ACL) |

> 💡 **초급 개발자가 가장 많이 겪는 함정 (상위 디렉토리 통과 권한 `x`)**
> 리눅스에서 `/home/agent-admin/agent-app/upload_files`에 다른 계정(`agent-dev`, `agent-test`)이 접근하려면, 그 상위 폴더인 `/home/agent-admin`과 `/home/agent-admin/agent-app`에 **디렉토리 진입(통과) 권한인 실행 권한(`x`)**이 열려 있어야 합니다. Ubuntu 22.04에서는 기본적으로 홈 디렉토리가 `750`(`drwxr-x---`)으로 생성되므로 `/home/agent-admin`에 `755` 권한을 부여해야 `agent-dev`와 `agent-test`가 하위 폴더에 들어갈 수 있습니다.

#### 실행 명령어
```bash
# 1) 디렉토리 일괄 생성
sudo mkdir -p /home/agent-admin/agent-app/upload_files
sudo mkdir -p /home/agent-admin/agent-app/api_keys
sudo mkdir -p /home/agent-admin/agent-app/bin
sudo mkdir -p /var/log/agent-app

# 2) 상위 디렉토리 통과 권한 설정
sudo chmod 755 /home/agent-admin
sudo chown agent-admin:agent-common /home/agent-admin/agent-app
sudo chmod 750 /home/agent-admin/agent-app

# 3) upload_files: agent-common 그룹 R/W 가능
sudo chown agent-admin:agent-common /home/agent-admin/agent-app/upload_files
sudo chmod 2770 /home/agent-admin/agent-app/upload_files
sudo setfacl -m g:agent-common:rwx /home/agent-admin/agent-app/upload_files
sudo setfacl -d -m g:agent-common:rwx /home/agent-admin/agent-app/upload_files

# 4) api_keys: agent-core 그룹 ONLY R/W 가능 (agent-test 접근 차단)
sudo chown agent-admin:agent-core /home/agent-admin/agent-app/api_keys
sudo chmod 2770 /home/agent-admin/agent-app/api_keys
sudo setfacl -m g:agent-core:rwx /home/agent-admin/agent-app/api_keys
sudo setfacl -d -m g:agent-core:rwx /home/agent-admin/agent-app/api_keys

# 5) bin 디렉토리 (monitor.sh 위치): agent-dev가 파일을 작성하고 agent-core가 실행 가능하도록 설정
sudo chown agent-dev:agent-core /home/agent-admin/agent-app/bin
sudo chmod 2770 /home/agent-admin/agent-app/bin

# 6) /var/log/agent-app: agent-core 그룹 ONLY R/W 가능
sudo chown agent-admin:agent-core /var/log/agent-app
sudo chmod 2770 /var/log/agent-app
sudo setfacl -m g:agent-core:rwx /var/log/agent-app
sudo setfacl -d -m g:agent-core:rwx /var/log/agent-app
```

#### ✅ [필수 증거 자료 4] 디렉토리 구조 및 권한(ACL 포함) 확인
```bash
# 디렉토리 권한 확인
ls -ld /home/agent-admin/agent-app \
       /home/agent-admin/agent-app/upload_files \
       /home/agent-admin/agent-app/api_keys \
       /home/agent-admin/agent-app/bin \
       /var/log/agent-app

# ACL 설정 확인
getfacl /home/agent-admin/agent-app/upload_files \
        /home/agent-admin/agent-app/api_keys \
        /var/log/agent-app
```

#### 🔍 명령어 및 옵션 상세 해설
* **`sudo mkdir -p [경로]`**
  * `mkdir` (Make Directory): 새 폴더를 만듭니다.
  * `-p` (`--parents`): 중간 경로에 아직 없는 상위 폴더(예: `agent-app`)까지 한 번에 연쇄적으로 만들어 주며, 이미 폴더가 존재해도 에러를 내지 않습니다.
* **`sudo chown [소유자]:[소유그룹] [경로]`**
  * `chown` (Change Owner): 파일이나 디렉토리의 소유자(콜론 앞)와 소유 그룹(콜론 뒤)을 변경합니다.
* **`sudo chmod 2770 [경로]`**
  * `chmod` (Change Mode): 파일이나 디렉토리의 읽기(`r=4`), 쓰기(`w=2`), 실행(`x=1`) 권한을 변경합니다.
  * **왜 `770` 앞에 `2`를 붙여 `2770`으로 쓰나요? (SetGID 비트)**:
    * 뒤의 세 자리 `770`은 **소유자 `7`(`rwx`), 그룹 `7`(`rwx`), 기타 사용자 `0`(`---`)**을 뜻합니다.
    * 맨 앞의 `2`는 **SetGID(Set Group ID) 특수 권한**입니다. 디렉토리에 SetGID(`2`)를 설정하면, 그 폴더 안에서 어떤 사용자가 새 파일을 만들더라도 **새 파일의 소유 그룹이 그 디렉토리의 소유 그룹(`agent-common` 또는 `agent-core`)으로 자동 지정**됩니다. 협업 폴더에서 권한이 꼬이지 않게 하는 실무 정석 설정입니다.
* **`sudo setfacl -m g:agent-common:rwx [경로]`**
  * `setfacl` (Set File Access Control List): 확장 접근 제어 목록(ACL)을 설정합니다.
  * `-m` (`--modify`): ACL 규칙을 추가하거나 수정합니다.
  * `g:agent-common:rwx`: 그룹(`g`) `agent-common`에 읽기·쓰기·실행(`rwx`) 권한을 부여하라는 뜻입니다. (특정 사용자에게 줄 때는 `u:계정명:rwx`로 씁니다.)
* **`sudo setfacl -d -m g:agent-common:rwx [경로]`**
  * `-d` (`--default`): **기본(Default) ACL** 옵션입니다. 이 옵션을 주면 현재 디렉토리뿐만 아니라, **앞으로 이 디렉토리 안에 새로 만들어질 모든 하위 파일과 폴더에도 해당 ACL 권한이 자동으로 상속**됩니다.
* **`ls -ld [경로...]`**
  * `-l` (Long format): 파일/폴더의 권한(`drwxrws---+`), 소유자, 그룹, 크기, 날짜를 상세히 출력합니다. (권한 맨 끝의 `+` 기호는 해당 폴더에 **ACL이 적용되어 있음**을 뜻합니다!)
  * `-d` (`--directory`): 원래 `ls -l 폴더명`을 치면 폴더 **안의 내용물**을 보여주지만, `-d`를 붙이면 내용물이 아니라 **그 폴더 자체의 권한과 소유자 정보**를 보여줍니다.
* **`getfacl [경로...]`**: 해당 디렉토리에 적용된 소유자, 그룹, 그리고 `setfacl`로 설정한 상세 ACL 규칙을 모두 출력합니다.

---

## Step 3. 애플리케이션 실행 환경 구성 및 구동 (기능 요구사항 3)

### 3-1. 맥(Host)에 있는 `agent-app`을 우분투로 복사하기

OrbStack으로 만든 우분투 가상머신 안에서는 맥의 폴더(`/Users/[ID_Masking]/...`)가 그대로 연결(마운트)되어 있어서 `cp` 명령어로 바로 복사할 수 있습니다.

1. 먼저 우분투 터미널에서 내 리눅스의 CPU 아키텍처를 확인합니다.
   ```bash
   uname -m
   ```
   * 결과가 **`x86_64`**라면 → `agent-app-linux-x86` 파일을 사용합니다. (현재 사용 중인 Intel 맥 환경)
   * 결과가 **`aarch64`**(또는 `arm64`)라면 → `agent-app-linux-arm64` 파일을 사용합니다. (Apple Silicon 맥 환경)

2. 아키텍처에 맞는 파일을 `/home/agent-admin/agent-app/agent_app.py`로 복사하고 실행 권한을 부여합니다.
   > 💡 미션 요구사항 4번에서 프로세스 이름을 `agent_app.py`(또는 제공 앱 파일명)로 확인하라고 되어 있으므로, 파일 이름을 `agent_app.py`로 맞춰 두면 관리가 매우 깔끔해집니다.

   ```bash
   ARCH=$(uname -m)
   if [ "$ARCH" = "x86_64" ]; then
       sudo cp /Users/[ID_Masking]/Codyssey-B4-1/etc/agent-app/agent-app-linux-x86 /home/agent-admin/agent-app/agent_app.py
   else
       sudo cp /Users/[ID_Masking]/Codyssey-B4-1/etc/agent-app/agent-app-linux-arm64 /home/agent-admin/agent-app/agent_app.py
   fi

   sudo chown agent-admin:agent-core /home/agent-admin/agent-app/agent_app.py
   sudo chmod 750 /home/agent-admin/agent-app/agent_app.py
   ```

#### 🔍 명령어 및 옵션 상세 해설
* **`uname -m`**
  * `uname` (Unix Name): 현재 운영체제와 하드웨어 정보를 출력합니다.
  * `-m` (`--machine`): 컴퓨터의 **CPU 하드웨어 아키텍처**(`x86_64` 또는 `aarch64`)만 정확히 출력합니다.
* **`ARCH=$(uname -m)`**
  * `$(명령어)` (**명령어 치환, Command Substitution**): 괄호 안의 명령어를 먼저 실행한 뒤, 그 출력 결과를 `ARCH`라는 변수에 저장합니다.

---

### 3-2. ⚠️ [핵심 주의] 제공된 앱의 실제 동작 코드와 미션 문서 간의 차이점 해결

> **[중요 발견 사항]**
> 미션 문서([B4-1-Mission.md](file:///Users/[ID_Masking]/Codyssey-B4-1/etc/B4-1-Mission.md#L89-L93))에는 아래와 같이 적혀 있습니다.
> - `AGENT_KEY_PATH`: `$AGENT_HOME/api_keys/t_secret.key`
> - 키 파일 경로: `$AGENT_HOME/api_keys/t_secret.key`
>
> **하지만 제공된 실행 바이너리(`agent-app-linux-x86` / `arm64`) 내부의 검증 코드(`BootValidator`)를 실제로 분석해 보면:**
> 1. **`[2/5] Verifying Environment Variables` 단계**: 환경 변수 `AGENT_KEY_PATH`의 값이 **`$AGENT_HOME/api_keys` (디렉토리 경로)**와 정확히 일치하는지 검사합니다. 만약 `.../api_keys/t_secret.key`로 넣으면 `Key Path Mismatch. Expected: /home/agent-admin/agent-app/api_keys` 에러가 발생하며 부팅에 실패합니다!
> 2. **`[3/5] Checking Required Files` 단계**: `$AGENT_HOME/api_keys/` 폴더 안에서 **`secret.key`**라는 이름의 파일을 찾아 그 내용이 `agent_api_key_test`인지 검사합니다. 만약 `t_secret.key`만 있으면 `Missing File: secret.key` 에러가 발생합니다!
>
> **해결책**:
> - 미션 문서의 체크리스트 요구사항(`t_secret.key`)과 실제 바이너리가 검사하는 파일(`secret.key`)을 **둘 다 생성**해 둡니다.
> - 앱을 실행할 때 `AGENT_KEY_PATH`는 바이너리가 요구하는 `$AGENT_HOME/api_keys`로 설정합니다. (보고서에는 이 검증 사실을 한 줄 적어주면 훨씬 높은 평가를 받을 수 있습니다!)

#### 키 파일 생성 명령어
```bash
# 미션 문서용(t_secret.key)과 실제 앱 검증용(secret.key) 두 파일을 모두 생성
echo "agent_api_key_test" | sudo tee /home/agent-admin/agent-app/api_keys/t_secret.key > /dev/null
echo "agent_api_key_test" | sudo tee /home/agent-admin/agent-app/api_keys/secret.key > /dev/null

# 소유권 및 권한 설정 (agent-core 그룹만 읽을 수 있도록 640 설정)
sudo chown agent-admin:agent-core /home/agent-admin/agent-app/api_keys/t_secret.key /home/agent-admin/agent-app/api_keys/secret.key
sudo chmod 640 /home/agent-admin/agent-app/api_keys/t_secret.key /home/agent-admin/agent-app/api_keys/secret.key
```

---

### 3-3. 환경 변수 설정 및 앱 실행 (`agent-admin` 계정)

앱은 반드시 **일반 계정(`agent-admin`)**으로 실행해야 합니다(`root`로 실행하면 1단계에서 차단됨).

```bash
# 1) agent-admin 계정으로 전환
sudo su - agent-admin

# 2) 로그인 시마다 환경 변수가 자동 적용되도록 ~/.bashrc에 등록
cat << 'EOF' >> ~/.bashrc
export AGENT_HOME="/home/agent-admin/agent-app"
export AGENT_PORT="15034"
export AGENT_UPLOAD_DIR="$AGENT_HOME/upload_files"
export AGENT_KEY_PATH="$AGENT_HOME/api_keys"
export AGENT_LOG_DIR="/var/log/agent-app"
EOF

# 3) 현재 터미널에 환경 변수 즉시 반영 및 확인
source ~/.bashrc
env | grep AGENT_
```

#### 🔍 명령어 및 옵션 상세 해설
* **`sudo su - agent-admin`**
  * `su` (Switch User): 현재 터미널의 사용자 계정을 다른 계정(`agent-admin`)으로 전환합니다.
  * **`-` 옵션 (`-l` 또는 `--login`)**: 매우 중요한 옵션입니다. `-`를 빼고 `su agent-admin`만 치면 이전 계정의 폴더 위치와 환경 변수가 섞인 채로 계정 이름만 바뀌지만, **`-`를 붙이면 `agent-admin`이 처음부터 새로 로그인한 것처럼 홈 디렉토리(`/home/agent-admin`)로 이동하고 환경 설정 파일(`~/.bashrc`)도 깨끗하게 불러옵니다.**
* **`cat << 'EOF' >> ~/.bashrc ... EOF`**
  * `<< 'EOF'` (**Here Document**): 여러 줄의 텍스트 블록을 마지막에 `EOF`(End Of File)가 나올 때까지 한꺼번에 입력으로 전달하는 문법입니다.
  * **왜 `EOF`에 작은따옴표(`'EOF'`)를 붙이나요?**: 따옴표 없이 `<< EOF`라고 쓰면 파일에 저장되기 전에 현재 쉘이 `$AGENT_HOME`을 지금 시점의 값(빈칸)으로 미리 치환해 버립니다. `'EOF'`처럼 작은따옴표를 붙이면 내부의 `$AGENT_HOME`을 치환하지 않고 **글자 그대로** `~/.bashrc`에 적어 줍니다.
* **`export 변수명="값"`**
  * 일반 쉘 변수를 **환경 변수(Environment Variable)**로 승격시켜, 이 쉘에서 실행되는 자식 프로세스(`agent_app.py`)가 해당 변수 값을 읽을 수 있게 해줍니다.
* **`source ~/.bashrc`**
  * 수정한 `~/.bashrc` 설정 파일을 재로그인할 필요 없이 **현재 열려 있는 터미널에 즉시 실행하여 적용**합니다. (`. ~/.bashrc`와 동일합니다.)
* **`env | grep AGENT_`**
  * `env`: 현재 설정된 모든 환경 변수 목록을 출력합니다. 그중 `AGENT_`가 들어간 줄만 `grep`으로 걸러서 잘 등록되었는지 확인합니다.

#### ✅ [필수 증거 자료 5] 앱 실행 및 Boot Sequence 5단계 `[OK]` 확인
이제 `agent-admin` 계정 상태에서 앱을 실행합니다.

```bash
$AGENT_HOME/agent_app.py
```

아래와 같이 5단계가 모두 `[OK]`로 통과하고 `Agent READY`가 출력되면 성공입니다!
```text
>>> Starting Agent Boot Sequence...
[1/5] Checking User Account        [OK]
   ... Running as service user 'agent-admin' (uid=1001)
[2/5] Verifying Environment Variables [OK]
   ... PORT=15034
   ... UPLOAD_DIR=/home/agent-admin/agent-app/upload_files
   ... KEY_PATH=/home/agent-admin/agent-app/api_keys
[3/5] Checking Required Files      [OK]
   ... Verified 'secret.key' with correct key string.
[4/5] Checking Port Availability   [OK]
   ... Port 15034 is available.
[5/5] Verifying Log Permission     [OK]
   ... Log directory is writable: /var/log/agent-app
------------------------------------------------------------
All Boot Checks Passed!
Agent READY
```

> ⚠️ **주의**: 이 앱은 실행된 상태에서 `Ctrl+C`를 누르기 전까지 계속 돌아가면서 스스로 CPU와 메모리를 오르내리게 만드는 테스트용 서버 프로그램입니다.
> **따라서 이 터미널 창은 끄지 말고 그대로 켜 둔 상태에서, 새로운 우분투 터미널 창을 하나 더 열어서(`orb -m ubuntu`) Step 4를 진행하세요!**
> (또는 백그라운드로 계속 켜두고 싶다면 `nohup $AGENT_HOME/agent_app.py >/dev/null 2>&1 &`로 실행해도 됩니다.)

---

## Step 4. 시스템 관제 자동화 스크립트 (`monitor.sh`) 구현 (기능 요구사항 4)

새로운 우분투 터미널 창(`orb -m ubuntu`)을 열고 진행합니다.

### 4-1. 요구사항 요약
1. **파일 위치 및 권한**: 경로 `/home/agent-admin/agent-app/bin/monitor.sh`, 소유자 `agent-dev`, 그룹 `agent-core`, 권한 `750` (`rwxr-x---`)
2. **Health Check (실패 시 즉시 `exit 1`로 종료)**: 프로세스(`agent_app.py`) 실행 여부 및 TCP `15034` 포트 `LISTEN` 상태 확인
3. **상태 점검 (경고만 출력, 종료하지 않음)**: 방화벽(`UFW` 또는 `firewalld`) 비활성 시 `[WARNING]` 출력
4. **자원 수집 및 임계값 경고**: `CPU > 20%`, `MEM > 10%`, `DISK_USED(/) > 80%` 초과 시 `[WARNING]` 출력
5. **로그 기록 및 용량 관리**: `/var/log/agent-app/monitor.log`에 지정된 포맷으로 기록하고, 최대 `10MB` / `10개` 파일 유지

### 4-2. `agent-dev` 계정으로 `monitor.sh` 작성하기

```bash
# 1) 작성자 요구사항에 맞게 agent-dev 계정으로 전환
sudo su - agent-dev

# 2) monitor.sh 파일 생성
cat << 'EOF' > /home/agent-admin/agent-app/bin/monitor.sh
#!/usr/bin/env bash
# ==============================================================================
# monitor.sh - 시스템 상태 수집 및 로깅 자동화 스크립트
# 소유자: agent-dev / 그룹: agent-core / 권한: 750
# ==============================================================================

# cron 실행 시에도 표준 명령어 경로를 찾을 수 있도록 PATH 및 로케일 고정
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export LC_ALL=C

APP_NAME="agent_app.py"
APP_PORT="15034"
LOG_DIR="/var/log/agent-app"
LOG_FILE="${LOG_DIR}/monitor.log"
MAX_LOG_SIZE=$((10 * 1024 * 1024)) # 10MB (10,485,760 bytes)
MAX_LOG_FILES=10

echo "====== SYSTEM MONITOR RESULT ======"
echo ""
echo "[HEALTH CHECK]"

# ------------------------------------------------------------------------------
# 1. Health Check - 프로세스 실행 확인 (실패 시 exit 1)
# ------------------------------------------------------------------------------
APP_PID=$(pgrep -f "${APP_NAME}" | head -n 1)
if [ -z "${APP_PID}" ]; then
    echo "Checking process '${APP_NAME}'... [FAIL] (Process not running)"
    exit 1
fi
echo "Checking process '${APP_NAME}'... [OK] (PID: ${APP_PID})"

# ------------------------------------------------------------------------------
# 2. Health Check - TCP 15034 포트 LISTEN 상태 확인 (실패 시 exit 1)
# ------------------------------------------------------------------------------
if ! ss -tuln | awk '{print $5}' | grep -Eq "(^|:)${APP_PORT}$"; then
    echo "Checking port ${APP_PORT}... [FAIL] (Port ${APP_PORT} is not LISTENING)"
    exit 1
fi
echo "Checking port ${APP_PORT}... [OK]"

# ------------------------------------------------------------------------------
# 3. 방화벽(UFW 또는 firewalld) 활성화 상태 점검 (비활성 시 WARNING만 출력)
# ------------------------------------------------------------------------------
FW_ACTIVE=0
if command -v ufw >/dev/null 2>&1; then
    if sudo -n ufw status 2>/dev/null | grep -q "Status: active"; then
        FW_ACTIVE=1
    elif [ -r /etc/ufw/ufw.conf ] && grep -q "^ENABLED=yes" /etc/ufw/ufw.conf; then
        FW_ACTIVE=1
    fi
elif command -v firewall-cmd >/dev/null 2>&1; then
    if firewall-cmd --state 2>/dev/null | grep -q "running"; then
        FW_ACTIVE=1
    fi
fi

if [ "${FW_ACTIVE}" -ne 1 ]; then
    echo "[WARNING] Firewall (UFW/firewalld) is inactive!"
fi

# ------------------------------------------------------------------------------
# 4. 시스템 자원 수집 (CPU, MEM, DISK)
# ------------------------------------------------------------------------------
# (1) CPU 사용률(%): /proc/stat을 0.5초 간격으로 두 번 읽어 실제 사용률 계산
read -r _ u1 n1 s1 i1 w1 irq1 sirq1 st1 _ < /proc/stat
sleep 0.5
read -r _ u2 n2 s2 i2 w2 irq2 sirq2 st2 _ < /proc/stat

TOTAL1=$((u1 + n1 + s1 + i1 + w1 + irq1 + sirq1 + st1))
TOTAL2=$((u2 + n2 + s2 + i2 + w2 + irq2 + sirq2 + st2))
IDLE1=$((i1 + w1))
IDLE2=$((i2 + w2))

DIFF_TOTAL=$((TOTAL2 - TOTAL1))
DIFF_IDLE=$((IDLE2 - IDLE1))

if [ "${DIFF_TOTAL}" -gt 0 ]; then
    CPU_USAGE=$(awk -v dt="${DIFF_TOTAL}" -v di="${DIFF_IDLE}" 'BEGIN { printf "%.1f", ((dt - di) / dt) * 100 }')
else
    CPU_USAGE="0.0"
fi

# (2) 메모리 사용률(%): free 명령어에서 total 대비 used 비율 계산
MEM_USAGE=$(free | awk '/^Mem:/ { printf "%.1f", ($3 / $2) * 100 }')

# (3) 디스크 사용률(Root partition '/', Used %): 정수형 % 추출
DISK_USED=$(df -P / | awk 'NR==2 { gsub(/%/, "", $5); print $5 }')

echo ""
echo "[RESOURCE MONITORING]"
echo "CPU Usage : ${CPU_USAGE}%"
echo "MEM Usage : ${MEM_USAGE}%"
echo "DISK Used : ${DISK_USED}%"
echo ""

# ------------------------------------------------------------------------------
# 5. 임계값 경고 (CPU > 20%, MEM > 10%, DISK_USED > 80%)
# ------------------------------------------------------------------------------
if awk -v cpu="${CPU_USAGE}" 'BEGIN { exit !(cpu > 20.0) }'; then
    echo "[WARNING] CPU threshold exceeded (${CPU_USAGE}% > 20%)"
fi

if awk -v mem="${MEM_USAGE}" 'BEGIN { exit !(mem > 10.0) }'; then
    echo "[WARNING] MEM threshold exceeded (${MEM_USAGE}% > 10%)"
fi

if [ "${DISK_USED}" -gt 80 ]; then
    echo "[WARNING] DISK_USED threshold exceeded (${DISK_USED}% > 80%)"
fi

# ------------------------------------------------------------------------------
# 6. 로그 파일 용량 관리 (최대 10MB / 최대 10개 파일 유지)
#    monitor.log + monitor.log.1 ~ monitor.log.9 (총 10개 유지)
# ------------------------------------------------------------------------------
rotate_logs() {
    if [ -f "${LOG_FILE}" ]; then
        CURRENT_SIZE=$(stat -c%s "${LOG_FILE}" 2>/dev/null || wc -c < "${LOG_FILE}")
        if [ "${CURRENT_SIZE}" -ge "${MAX_LOG_SIZE}" ]; then
            MAX_ROTATE=$((MAX_LOG_FILES - 1))
            # 가장 오래된 파일 삭제
            [ -f "${LOG_FILE}.${MAX_ROTATE}" ] && rm -f "${LOG_FILE}.${MAX_ROTATE}"
            # 기존 백업 파일 번호를 1씩 증가 (.8 -> .9, ..., .1 -> .2)
            for ((i = MAX_ROTATE - 1; i >= 1; i--)); do
                if [ -f "${LOG_FILE}.${i}" ]; then
                    mv "${LOG_FILE}.${i}" "${LOG_FILE}.$((i + 1))"
                fi
            done
            # 현재 monitor.log를 monitor.log.1로 이동
            mv "${LOG_FILE}" "${LOG_FILE}.1"
        fi
    fi
}

rotate_logs

# ------------------------------------------------------------------------------
# 7. 로그 기록 ([YYYY-MM-DD HH:MM:SS] PID:... CPU:..% MEM:..% DISK_USED:..%)
# ------------------------------------------------------------------------------
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
LOG_LINE="[${TIMESTAMP}] PID:${APP_PID} CPU:${CPU_USAGE}% MEM:${MEM_USAGE}% DISK_USED:${DISK_USED}%"

echo "${LOG_LINE}" >> "${LOG_FILE}"
chmod 660 "${LOG_FILE}" 2>/dev/null || true

# ------------------------------------------------------------------------------
# 8. 누적 로그 기반 통계 출력 (콘솔 출력 예시와 동일한 리포트)
# ------------------------------------------------------------------------------
if [ -f "${LOG_FILE}" ]; then
    echo ""
    awk '
    {
        ts = substr($1, 2) " " substr($2, 1, 8)
        cpu = $4; sub(/CPU:/, "", cpu); sub(/%/, "", cpu); cpu += 0
        mem = $5; sub(/MEM:/, "", mem); sub(/%/, "", mem); mem += 0

        count++
        cpu_sum += cpu
        mem_sum += mem

        if (count == 1 || cpu > cpu_max) { cpu_max = cpu; cpu_max_ts = ts }
        if (count == 1 || cpu < cpu_min) { cpu_min = cpu; cpu_min_ts = ts }
        if (count == 1 || mem > mem_max) { mem_max = mem; mem_max_ts = ts }
        if (count == 1 || mem < mem_min) { mem_min = mem; mem_min_ts = ts }
    }
    END {
        if (count > 0) {
            printf "====== STATISTICS REPORT ======\n"
            printf "[CPU]\n"
            printf "Average : %.1f%%\n", cpu_sum / count
            printf "Maximum : %.1f%% at %s\n", cpu_max, cpu_max_ts
            printf "Minimum : %.1f%% at %s\n", cpu_min, cpu_min_ts
            printf "[Memory]\n"
            printf "Average : %.1f%%\n", mem_sum / count
            printf "Maximum : %.1f%% at %s\n", mem_max, mem_max_ts
            printf "Minimum : %.1f%% at %s\n", mem_min, mem_min_ts
            printf "[Samples]\n"
            printf "Data Points: %d samples\n", count
        }
    }' "${LOG_FILE}"
fi

echo ""
echo "[INFO] Log appended: ${LOG_FILE}"
EOF

# 3) 소유권(agent-dev:agent-core) 및 권한(750: rwxr-x---) 설정
chmod 750 /home/agent-admin/agent-app/bin/monitor.sh
ls -l /home/agent-admin/agent-app/bin/monitor.sh

# 4) agent-dev 계정에서 빠져나오기
exit
```

### 4-3. 🔍 `monitor.sh` 내부에 사용된 핵심 명령어 및 옵션 상세 해설

스크립트를 스스로 설명할 수 있도록 내부 명령어와 옵션들을 정리했습니다.

* **`pgrep -f "${APP_NAME}" | head -n 1`**
  * `pgrep` (Process Grep): 현재 실행 중인 프로세스 중에서 이름이 일치하는 프로세스의 **PID(프로세스 번호)**만 찾아 출력합니다.
  * `-f` (`--full`): 단순 실행 파일 이름뿐만 아니라 **실행된 전체 명령어 경로**(예: `/home/agent-admin/agent-app/agent_app.py`) 전체를 대상으로 검색합니다.
  * `head -n 1`: 출력 결과 중 **맨 첫 번째 1줄(`-n 1`)**만 가져옵니다.
* **`ss -tuln | awk '{print $5}' | grep -Eq "(^|:)${APP_PORT}$"`**
  * `ss -tuln`: 현재 `LISTEN`(`-l`) 중인 TCP(`-t`)/UDP(`-u`) 소켓을 숫자 포트 번호(`-n`)로 출력합니다.
  * `awk '{print $5}'`: 공백으로 구분된 열 중에서 **5번째 열(`Local Address:Port`, 예: `0.0.0.0:15034`)**만 추출합니다.
  * `grep -Eq`: 확장 정규표현식(`-E`)을 사용해 조용히(`-q`) `:15034`로 끝나는 줄이 있는지 검사합니다.
* **`command -v ufw`**
  * `command -v [명령어]`: 해당 프로그램(`ufw`)이 시스템에 설치되어 있는지 확인하는 Bash 내장 명령입니다.
* **`sudo -n ufw status`**
  * `-n` (`--non-interactive`): **비대화형 모드** 옵션입니다. 만약 `sudo`가 비밀번호를 물어봐야 하는 상황이라면, 비밀번호 입력을 기다리며 스크립트가 멈추지(Hang) 않고 즉시 실패 처리하여 다음 `elif`(`/etc/ufw/ufw.conf` 파일 확인)로 넘어가게 해줍니다. `cron` 자동화 스크립트에서 매우 중요한 옵션입니다.
* **`read -r _ u1 n1 ... < /proc/stat`**
  * `/proc/stat`: 리눅스 커널이 부팅 이후 CPU가 일한 시간(User, Nice, System)과 쉰 시간(Idle, I/O Wait)을 실시간으로 기록해 두는 가상 파일입니다.
  * `read -r`: 파일의 첫 줄을 읽어서 공백 단위로 각 변수에 나누어 담습니다. `-r` 옵션은 백슬래시(`\`) 문자를 특수 문자로 해석하지 않고 있는 그대로 읽으라는 정석 옵션입니다.
* **`awk -v dt="${DIFF_TOTAL}" -v di="${DIFF_IDLE}" 'BEGIN { ... }'`**
  * `awk`: 텍스트 데이터를 열(Column) 단위로 가공하고 **소수점 실수 연산**을 수행하는 리눅스 기본 데이터 처리 언어입니다. (Bash의 기본 연산 `$(( ))`은 정수만 계산할 수 있어서, 소수점 첫째 자리 `%.1f` 퍼센트 계산에는 `awk`를 사용합니다.)
  * `-v 변수명="값"`: Bash 스크립트의 변수를 `awk` 내부 변수로 안전하게 전달하는 옵션입니다.
* **`free | awk '/^Mem:/ { printf "%.1f", ($3 / $2) * 100 }'`**
  * `free`: 시스템의 전체 메모리(RAM)와 사용 중인 메모리 용량을 출력합니다.
  * `/^Mem:/`: `Mem:`으로 시작하는 줄에서 3번째 열(`$3`, 사용량 used)을 2번째 열(`$2`, 전체 용량 total)로 나누어 `100`을 곱해 메모리 사용률(%)을 구합니다.
* **`df -P /`**
  * `df` (Disk Free): 디스크 파티션별 남은 용량과 사용률(%)을 출력합니다.
  * `-P` (`--portability`): 디스크 장치 이름이 길더라도 줄바꿈을 하지 않고 **무조건 한 줄에 출력하도록(POSIX 표준 포맷)** 강제하는 옵션입니다. 스크립트에서 `awk`로 5번째 열(`$5`, `Use%`)을 흔들림 없이 정확하게 뽑아내기 위해 반드시 `-P`를 붙입니다.
  * `/`: 루트 파티션(Root partition)의 디스크 용량을 조회하겠다는 대상 경로입니다.
* **`stat -c%s "${LOG_FILE}"`**
  * `stat`: 파일의 상세 메타데이터(크기, 권한, 생성/수정 시각 등)를 조회합니다.
  * `-c%s` (`--format=%s`): 다른 정보 없이 **파일의 크기(Byte 단위 숫자)**만 딱 출력하라는 포맷 옵션입니다. 이를 통해 `10MB`(`10485760` 바이트)가 넘었는지 비교합니다.
* **`date "+%Y-%m-%d %H:%M:%S"`**
  * `+포맷`: 현재 날짜와 시간을 원하는 형식으로 출력합니다.
  * `%Y`(4자리 연도), `%m`(2자리 월), `%d`(2자리 일), `%H`(24시간제 시), `%M`(분), `%S`(초) → 예: `2026-11-19 16:05:01`
* **Bash 조건문(`[ ... ]`) 안의 테스트 옵션 총정리**
  | 옵션 | 의미 | 사용 예시 |
  | :--- | :--- | :--- |
  | `-z "문자열"` | 문자열이 **비어 있으면(Zero length)** 참(True) | `[ -z "${APP_PID}" ]` (PID가 없으면) |
  | `-f "경로"` | 해당 경로에 **일반 파일(File)이 존재하면** 참 | `[ -f "${LOG_FILE}" ]` |
  | `-d "경로"` | 해당 경로에 **디렉토리(Directory)가 존재하면** 참 | `[ -d "${LOG_DIR}" ]` |
  | `-r "경로"` | 해당 파일/폴더를 **읽을 수 있는(Readable) 권한이 있으면** 참 | `[ -r /etc/ufw/ufw.conf ]` |
  | `-w "경로"` | 해당 파일/폴더에 **쓸 수 있는(Writable) 권한이 있으면** 참 | `[ -w "${LOG_DIR}" ]` |
  | `-s "경로"` | 파일이 존재하고 **크기가 0보다 크면(비어 있지 않으면)** 참 | `[ -s "${LOG_FILE}" ]` |
  | `A -gt B` | 숫자 A가 B보다 **크면(Greater Than, `>`)** 참 | `[ "${DISK_USED}" -gt 80 ]` |
  | `A -ge B` | 숫자 A가 B보다 **크거나 같으면(Greater or Equal, `>=`)** 참 | `[ "${CURRENT_SIZE}" -ge "${MAX_LOG_SIZE}" ]` |
  | `A -ne B` | 숫자 A가 B와 **다르면(Not Equal, `!=`)** 참 | `[ "${FW_ACTIVE}" -ne 1 ]` |
  | `A -eq B` | 숫자 A가 B와 **같으면(Equal, `==`)** 참 | `[ "${#OLD_LOGS[@]}" -eq 0 ]` |

---

### 4-4. ✅ [필수 증거 자료 6] `monitor.sh` 수동 실행 및 권한 확인
`agent-admin` 계정으로 전환하여 스크립트가 정상 실행되는지 확인합니다.

```bash
sudo su - agent-admin

# 1) 파일 소유자/그룹/권한(750) 확인
ls -l /home/agent-admin/agent-app/bin/monitor.sh

# 2) monitor.sh 실행 테스트
/home/agent-admin/agent-app/bin/monitor.sh
```

---

## Step 5. 자동 실행 (`cron`) 설정 및 검증 (기능 요구사항 5)

이제 `agent-admin` 계정에서 1분마다 `monitor.sh`가 자동으로 실행되도록 `crontab`에 등록합니다.

### 5-1. `agent-admin` 계정의 `crontab` 등록
(`agent-admin` 로그인 상태에서 실행)

```bash
# 기존 crontab에 매분 실행 규칙 등록
(crontab -l 2>/dev/null | grep -v "monitor.sh"; echo "* * * * * /home/agent-admin/agent-app/bin/monitor.sh >/dev/null 2>&1") | crontab -
```

### 5-2. ✅ [필수 증거 자료 7 & 8] `crontab` 등록 내역 및 1~2분 후 로그 자동 누적 확인
```bash
# 1) crontab 등록 확인
crontab -l

# 2) 현재 로그 확인
cat /var/log/agent-app/monitor.log

# 3) 1~2분 동안 실시간으로 새 로그가 1분마다 찍히는지 확인 (확인 후 Ctrl+C로 종료)
tail -f /var/log/agent-app/monitor.log
```
> **기대 결과**: 1분이 지날 때마다 `[2026-..-.. HH:MM:01] PID:... CPU:..% MEM:..% DISK_USED:..%` 라인이 자동으로 한 줄씩 추가됩니다!

#### 🔍 명령어 및 옵션 상세 해설
* **`crontab -l`**
  * `-l` (`--list`): 현재 로그인한 사용자(`agent-admin`)의 예약 작업(`crontab`) 목록을 화면에 출력합니다. (직접 편집기로 열 때는 `crontab -e`를 사용합니다.)
* **`grep -v "monitor.sh"`**
  * `-v` (`--invert-match`): 지정한 단어(`monitor.sh`)가 **포함되지 않은 줄만** 출력합니다. (기존에 등록된 `monitor.sh` 줄이 있다면 중복 등록되지 않게 걸러내는 역할을 합니다.)
* **`| crontab -`**
  * 맨 끝의 `-`는 파이프(`|`)로 전달받은 표준 입력(stdin) 텍스트를 새로운 `crontab` 시간표로 덮어써서 등록하라는 의미입니다.
* **`tail -f /var/log/agent-app/monitor.log`**
  * `tail`: 파일의 맨 마지막 부분(기본 마지막 10줄)을 출력합니다. (줄 수를 지정할 때는 `tail -n 20`처럼 `-n` 옵션을 씁니다.)
  * `-f` (`--follow`): 파일의 끝을 출력한 뒤 명령어를 종료하지 않고, **파일에 새로운 줄이 추가될 때마다 실시간으로 화면에 계속 찍어주는** 모니터링 필수 옵션입니다. (종료할 때는 `Ctrl+C`를 누릅니다.)

---

## Step 6. (선택) 보너스 과제 1 & 2 구현하기

필수 과제를 모두 마쳤다면, 아래 두 스크립트를 추가하여 보너스 과제까지 챙길 수 있습니다.

### 6-1. 보너스 1 – `report.sh` (요약 리포트 자동 생성 + 시작/종료 시간 구간 분석)

`agent-dev` 계정으로 `/home/agent-admin/agent-app/bin/report.sh`를 생성합니다.
* 인자 없이 실행하면: 전체 로그 분석 (`/home/agent-admin/agent-app/bin/report.sh`)
* 시작/종료 시간을 인자로 주면: 해당 구간만 분석 (`/home/agent-admin/agent-app/bin/report.sh "2026-11-19 15:00:00" "2026-11-19 16:00:00"`)

```bash
sudo su - agent-dev

cat << 'EOF' > /home/agent-admin/agent-app/bin/report.sh
#!/usr/bin/env bash
# ==============================================================================
# report.sh - monitor.log 분석 및 CPU/MEM/DISK 요약 통계 리포트 생성
# 사용법:
#   전체 분석: ./report.sh
#   구간 분석: ./report.sh "YYYY-MM-DD HH:MM:SS" "YYYY-MM-DD HH:MM:SS"
# ==============================================================================

export LC_ALL=C
LOG_FILE="/var/log/agent-app/monitor.log"
START_TIME="${1:-}"
END_TIME="${2:-}"

if [ ! -f "${LOG_FILE}" ] || [ ! -s "${LOG_FILE}" ]; then
    echo "[ERROR] Log file not found or empty: ${LOG_FILE}"
    exit 1
fi

awk -v start="${START_TIME}" -v end="${END_TIME}" '
{
    ts = substr($1, 2) " " substr($2, 1, 8)
    if (start != "" && ts < start) next
    if (end != "" && ts > end) next

    cpu = $4; sub(/CPU:/, "", cpu); sub(/%/, "", cpu); cpu += 0
    mem = $5; sub(/MEM:/, "", mem); sub(/%/, "", mem); mem += 0
    disk = $6; sub(/DISK_USED:/, "", disk); sub(/%/, "", disk); disk += 0

    count++
    cpu_sum += cpu
    mem_sum += mem
    disk_sum += disk

    if (count == 1 || cpu > cpu_max) { cpu_max = cpu; cpu_max_ts = ts }
    if (count == 1 || cpu < cpu_min) { cpu_min = cpu; cpu_min_ts = ts }
    if (count == 1 || mem > mem_max) { mem_max = mem; mem_max_ts = ts }
    if (count == 1 || mem < mem_min) { mem_min = mem; mem_min_ts = ts }
    if (count == 1 || disk > disk_max) { disk_max = disk; disk_max_ts = ts }
    if (count == 1 || disk < disk_min) { disk_min = disk; disk_min_ts = ts }
}
END {
    if (count == 0) {
        print "[WARNING] No log samples found in the specified range."
        exit 0
    }
    printf "====== STATISTICS REPORT ======\n"
    if (start != "" || end != "") {
        printf "Period  : %s ~ %s\n", (start != "" ? start : "BEGIN"), (end != "" ? end : "END")
    }
    printf "[CPU]\n"
    printf "Average : %.1f%%\n", cpu_sum / count
    printf "Maximum : %.1f%% at %s\n", cpu_max, cpu_max_ts
    printf "Minimum : %.1f%% at %s\n", cpu_min, cpu_min_ts
    printf "[Memory]\n"
    printf "Average : %.1f%%\n", mem_sum / count
    printf "Maximum : %.1f%% at %s\n", mem_max, mem_max_ts
    printf "Minimum : %.1f%% at %s\n", mem_min, mem_min_ts
    printf "[Disk]\n"
    printf "Average : %.1f%%\n", disk_sum / count
    printf "Maximum : %d%% at %s\n", disk_max, disk_max_ts
    printf "Minimum : %d%% at %s\n", disk_min, disk_min_ts
    printf "[Samples]\n"
    printf "Data Points: %d samples\n", count
}' "${LOG_FILE}"
EOF

chmod 750 /home/agent-admin/agent-app/bin/report.sh
exit
```

---

### 6-2. 보너스 2 – 시간 기반 로그 보존 정책 (`archive_logs.sh`)

* **기능**:
  1. `/var/log/agent-app/*.log` 중 7일 이상 경과(`-mtime +6`)한 파일을 `gzip`으로 압축(`.gz`)
  2. 압축된 파일을 `/var/log/monitor/agent-app/archive/`로 이동
  3. `/var/log/monitor/agent-app/archive/*.gz` 중 30일 이상 경과(`-mtime +29`)한 파일 삭제
  4. 디렉토리 미존재, 권한 부족, 대상 파일 0개 등의 예외 처리 포함

```bash
# 1) 아카이브 디렉토리 생성 및 agent-core 권한 부여
sudo mkdir -p /var/log/monitor/agent-app/archive
sudo chown -R agent-admin:agent-core /var/log/monitor
sudo chmod -R 2770 /var/log/monitor

# 2) agent-dev 계정으로 archive_logs.sh 작성
sudo su - agent-dev

cat << 'EOF' > /home/agent-admin/agent-app/bin/archive_logs.sh
#!/usr/bin/env bash
# ==============================================================================
# archive_logs.sh - 시간 기반 로그 보존 정책 (7일 경과 압축/이동, 30일 경과 삭제)
# ==============================================================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
LOG_DIR="/var/log/agent-app"
ARCHIVE_DIR="/var/log/monitor/agent-app/archive"

# 예외 처리 1: 원본 로그 디렉토리 존재 및 권한 확인
if [ ! -d "${LOG_DIR}" ]; then
    echo "[WARNING] Log directory does not exist: ${LOG_DIR}. Exiting safely."
    exit 0
fi

if [ ! -r "${LOG_DIR}" ] || [ ! -w "${LOG_DIR}" ]; then
    echo "[WARNING] Insufficient permissions on ${LOG_DIR}. Exiting safely."
    exit 0
fi

# 예외 처리 2: 아카이브 디렉토리 존재 확인 (없으면 생성 시도, 실패 시 안전 종료)
if [ ! -d "${ARCHIVE_DIR}" ]; then
    mkdir -p "${ARCHIVE_DIR}" 2>/dev/null || {
        echo "[WARNING] Cannot create archive directory: ${ARCHIVE_DIR}. Exiting safely."
        exit 0
    }
fi

if [ ! -w "${ARCHIVE_DIR}" ]; then
    echo "[WARNING] Insufficient write permissions on ${ARCHIVE_DIR}. Exiting safely."
    exit 0
fi

# 1. 7일 이상 경과한 *.log 파일 압축 및 아카이브 이동
mapfile -t OLD_LOGS < <(find "${LOG_DIR}" -maxdepth 1 -type f -name "*.log" -mtime +6 2>/dev/null)

if [ "${#OLD_LOGS[@]}" -eq 0 ]; then
    echo "[INFO] No log files older than 7 days found in ${LOG_DIR}."
else
    for f in "${OLD_LOGS[@]}"; do
        BASENAME=$(basename "${f}")
        STAMP=$(date "+%Y%m%d_%H%M%S")
        GZ_TARGET="${ARCHIVE_DIR}/${BASENAME}.${STAMP}.gz"
        if gzip -c "${f}" > "${GZ_TARGET}"; then
            rm -f "${f}"
            echo "[INFO] Archived and compressed: ${f} -> ${GZ_TARGET}"
        else
            echo "[WARNING] Failed to compress: ${f}"
        fi
    done
fi

# 2. 30일 이상 경과한 아카이브(*.gz) 삭제
mapfile -t EXPIRED_ARCHIVES < <(find "${ARCHIVE_DIR}" -maxdepth 1 -type f -name "*.gz" -mtime +29 2>/dev/null)

if [ "${#EXPIRED_ARCHIVES[@]}" -eq 0 ]; then
    echo "[INFO] No archived .gz files older than 30 days found in ${ARCHIVE_DIR}."
else
    for gz in "${EXPIRED_ARCHIVES[@]}"; do
        rm -f "${gz}" && echo "[INFO] Deleted expired archive (>30d): ${gz}"
    done
fi
EOF

chmod 750 /home/agent-admin/agent-app/bin/archive_logs.sh
exit
```

#### 🔍 보너스 과제(`archive_logs.sh`) 명령어 및 옵션 상세 해설
* **`sudo chown -R` / `sudo chmod -R`**
  * `-R` (`--recursive`, 재귀 적용): 지정한 폴더(`/var/log/monitor`)뿐만 아니라 그 안에 들어 있는 모든 하위 폴더(`agent-app/archive`)와 파일들까지 한꺼번에 소유권과 권한을 변경합니다.
* **`find "${LOG_DIR}" -maxdepth 1 -type f -name "*.log" -mtime +6`**
  * `find`: 지정한 디렉토리에서 조건에 맞는 파일을 검색하는 강력한 명령어입니다.
  * `-maxdepth 1`: 하위 디렉토리까지 깊숙이 파고들지 않고, **현재 지정한 폴더 바로 아래(깊이 1단계)**에서만 파일을 찾습니다.
  * `-type f`: 폴더(`d`)나 심볼릭 링크(`l`)는 제외하고 **일반 파일(`f`, File)**만 찾습니다.
  * `-name "*.log"`: 파일 이름이 `.log`로 끝나는 파일만 찾습니다.
  * `-mtime +6`: 파일 내용이 마지막으로 수정된 시각(Modification Time)이 **24시간 × 7일(즉, 6일 초과 = 7일 이상)** 경과한 파일만 찾습니다. (마찬가지로 `-mtime +29`는 29일 초과 = **30일 이상 경과**한 파일을 의미합니다.)
* **`mapfile -t OLD_LOGS < <( ... )`**
  * `mapfile -t 배열변수명`: 여러 줄의 출력 결과를 줄바꿈 문자(`-t`로 제거) 기준으로 나누어 Bash 배열(`OLD_LOGS`)에 안전하게 저장합니다. 파일 이름에 공백이 있어도 깨지지 않는 정석 문법입니다.
* **`gzip -c "${f}" > "${GZ_TARGET}"`**
  * `gzip`: 리눅스 표준 압축 도구입니다.
  * `-c` (`--stdout`): 원래 `gzip 파일명`을 실행하면 원본 파일을 그 자리에서 `.gz`로 바꿔버리지만, `-c` 옵션을 주면 압축된 데이터를 표준 출력으로 내보내어 리다이렉션(`>`)을 통해 **아카이브 폴더(`ARCHIVE_DIR`)에 원하는 파일명으로 바로 압축 저장**할 수 있습니다.
* **`rm -f "${f}"`**
  * `rm` (Remove): 파일을 삭제합니다.
  * `-f` (`--force`): 삭제 확인 질문을 묻지 않고, 파일이 없더라도 에러를 내지 않고 강제로 삭제합니다.

---

## Step 7. 최종 산출물 맥(Host)으로 가져와서 제출 준비하기

실습이 모두 끝났다면 최종 제출해야 할 산출물은 **2가지**입니다.

1. **자동화 스크립트 소스코드 (`monitor.sh`)**
   * 우분투 안에서 작성한 `monitor.sh`를 맥의 프로젝트 폴더(`/Users/[ID_Masking]/Codyssey-B4-1/`)로 복사해 옵니다.
   ```bash
   # 우분투 터미널 안에서 실행
   cp /home/agent-admin/agent-app/bin/monitor.sh /Users/[ID_Masking]/Codyssey-B4-1/monitor.sh
   ```
2. **요구사항 수행 내역서 (문서 1개)**
   * 아래 **8가지 필수 증거 자료 체크리스트**의 명령어와 실행 결과를 하나의 마크다운(또는 PDF/워드) 문서로 정리합니다.
   * [ ] ① SSH 포트 변경(`20022`) 및 Root 원격 접속 차단 설정 확인 내역 (`grep -E "^(Port|PermitRootLogin)" /etc/ssh/sshd_config`, `sudo ss -tulnp | grep sshd`)
   * [ ] ② 방화벽(`UFW`) 활성화 및 `20022/tcp`, `15034/tcp`만 허용 내역 (`sudo ufw status verbose`)
   * [ ] ③ 계정/그룹(`agent-admin/dev/test`, `agent-common/core`) 생성 확인 내역 (`id agent-admin`, `id agent-dev`, `id agent-test`)
   * [ ] ④ 디렉토리 구조 및 권한(ACL 포함) 확인 내역 (`ls -ld ...`, `getfacl ...`)
   * [ ] ⑤ 앱 Boot Sequence 5단계 `[OK]` 및 `"Agent READY"` 확인 내역 (`$AGENT_HOME/agent_app.py` 실행 출력 및 `ss -tulnp | grep 15034`)
   * [ ] ⑥ `monitor.sh` 실행 결과(프로세스/포트/리소스/경고) 내역
   * [ ] ⑦ `/var/log/agent-app/monitor.log` 누적 기록 확인(최근 라인) 내역 (`tail -n 20 /var/log/agent-app/monitor.log`)
   * [ ] ⑧ `crontab` 매분 실행 등록 및 자동 실행 확인(1분 후 로그 증가) 내역 (`crontab -l` 및 1분 간격 로그 타임스탬프)
