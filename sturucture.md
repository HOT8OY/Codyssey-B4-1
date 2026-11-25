

### 1. 전체 파일 및 디렉터리 트리 구조

```text
/ (리눅스 최상위 루트)
│
├── etc/
│   ├── ssh/
│   │   └── sshd_config                  # [필수] SSH 포트 20022, PermitRootLogin no 설정
│   └── ufw/                             # [필수] 방화벽(UFW) 20022/tcp, 15034/tcp만 허용
│
├── home/
│   └── agent-admin/                     # (755, agent-admin:agent-admin) 하위 공유 폴더 진입(통과)용
│       ├── .bashrc                      # [필수] AGENT_HOME 등 5개 환경 변수 등록
│       └── agent-app/                   # [$AGENT_HOME] (750, agent-admin:agent-common)
│           ├── agent_app.py             # [필수] 제공된 실행 앱 (agent-app-linux-x86/arm64 복사본, 750)
│           │
│           ├── upload_files/            # [$AGENT_UPLOAD_DIR] (2770+ACL, agent-admin:agent-common)
│           │                            #   └─ 공유 폴더: admin, dev, test 모두 R/W 가능
│           │
│           ├── api_keys/                # [$AGENT_KEY_PATH] (2770+ACL, agent-admin:agent-core)
│           │   ├── t_secret.key         # [필수-문서] 내용: agent_api_key_test (640)
│           │   └── secret.key           # [필수-앱실행] 실제 바이너리가 검사하는 키 파일 (640)
│           │                            #   └─ 보안 폴더: admin, dev만 R/W 가능 (test 차단)
│           │
│           └── bin/                     # (2770, agent-dev:agent-core) 자동화 스크립트 폴더
│               ├── monitor.sh           # [필수] 관제·로깅 스크립트 (750, agent-dev:agent-core)
│               ├── report.sh            # [보너스 1] monitor.log 통계 요약 리포트 스크립트 (750)
│               └── archive_logs.sh      # [보너스 2] 로그 압축/아카이브/삭제 스크립트 (750)
│
└── var/
    └── log/
        ├── agent-app/                   # [$AGENT_LOG_DIR] (2770+ACL, agent-admin:agent-core)
        │   ├── monitor.log              # [필수] monitor.sh가 매분 누적 기록 (최대 10MB / 10개 유지)
        │   ├── monitor.log.1 ~ .9       # [필수] 10MB 초과 시 로테이션된 백업 로그 파일들
        │   └── agent_app.log            # (자동 생성) 제공된 앱이 실행되며 남기는 자체 로그
        │                                #   └─ 보안 폴더: admin, dev만 R/W 가능 (test 차단)
        │
        └── monitor/
            └── agent-app/
                └── archive/             # [보너스 2] 7일 경과 로그(.gz) 보관소 (30일 경과 시 삭제)
                    └── *.gz
```

---

### 2. 핵심 디렉터리·파일별 권한 정책 요약표

| 경로 | 소유자 : 그룹 | 권한 | 접근 가능 계정 | 역할 |
| :--- | :---: | :---: | :--- | :--- |
| `$AGENT_HOME/upload_files` | `agent-admin:agent-common` | `2770` + ACL | `admin`, `dev`, `test` | 3개 계정 모두 사용하는 **공유 디렉터리** |
| `$AGENT_HOME/api_keys` | `agent-admin:agent-core` | `2770` + ACL | `admin`, `dev` (**`test` 차단**) | 비밀키(`t_secret.key`, `secret.key`) 보관 **보안 디렉터리** |
| `/var/log/agent-app` | `agent-admin:agent-core` | `2770` + ACL | `admin`, `dev` (**`test` 차단**) | `monitor.log` 저장 **보안 디렉터리** |
| `$AGENT_HOME/bin/monitor.sh` | `agent-dev:agent-core` | `750` | 작성: `dev` / 실행: `admin`, `dev` | `agent-dev`가 작성하고 `agent-admin`의 `cron`이 매분 실행 |
| `/var/log/monitor/agent-app/archive` | `agent-admin:agent-core` | `2770` | `admin`, `dev` | *(보너스 2)* 7일 경과 압축 로그(`.gz`) 보관 및 30일 후 삭제 |