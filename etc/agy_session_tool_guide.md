# Antigravity 채팅 세션 백업 및 복구 가이드 (`agy_session_tool.sh`)

컴퓨터 초기화 또는 자리 이동 시, Antigravity 왼쪽 채팅 목록(UI)에 **기존 대화방을 그대로 복원**하기 위한 원클릭 스크립트(`etc/agy_session_tool.sh`) 사용 설명서입니다.

---

## 1. 파일 구성

| 파일명 | 설명 | 보관 위치 권장 |
| :--- | :--- | :--- |
| `etc/agy_session_tool.sh` | 세션을 추출(`export`)하고 복구(`restore`)하는 실행 스크립트 | 프로젝트 폴더 또는 개인 드라이브 |
| `etc/agy_session_backup.tar.gz` | 추출 시 생성되는 채팅 세션 본체(`conversations/`, `brain/`) 압축 파일 | **개인 드라이브** (⚠️ 공개 GitHub 업로드 비권장) |

---

## 2. 초기화 전: 현재 컴퓨터에서 세션 추출하기 (Export)

1. **맥 기본 터미널**(우분투 내부가 아닌 macOS 터미널)을 열고 프로젝트 루트 폴더(`Codyssey-B4-1`)로 이동합니다.
2. 아래 명령어를 실행합니다.
   ```bash
   bash etc/agy_session_tool.sh export
   ```
   *(또는 인자 없이 `bash etc/agy_session_tool.sh` 실행 후 `1`번 입력)*
3. `etc/agy_session_backup.tar.gz` 파일이 생성되었는지 확인합니다.
   ```bash
   ls -lh etc/agy_session_backup.tar.gz
   ```
4. 생성된 **`etc/agy_session_backup.tar.gz`** 파일과 **`etc/agy_session_tool.sh`** 파일을 개인 드라이브(구글 드라이브, USB 등)에 업로드해 백업합니다.
   > ⚠️ **주의**: `git add .`로 GitHub에 코드를 올리기 전에 `etc/agy_session_backup.tar.gz`와 `etc/chat_backup.jsonl`은 삭제하거나 `.gitignore`에 등록해 공개 저장소에 올라가지 않도록 주의하세요.

---

## 3. 초기화 후: 새 환경에서 세션 복구하기 (Restore)

1. 초기화가 끝난 컴퓨터에서 먼저 **Antigravity 앱을 완전히 종료(`Cmd + Q`)**합니다.
   * *앱이 켜져 있는 상태에서 복구하면 메모리에 있던 빈 목록이 복구된 파일을 덮어쓸 수 있으므로 반드시 먼저 종료해야 합니다.*
2. GitHub에서 프로젝트 저장소를 클론(`git clone`) 받습니다.
3. 개인 드라이브에 백업해 둔 **`agy_session_backup.tar.gz`** 파일을 다운로드하여 프로젝트의 **`etc/` 폴더 안**(`etc/agy_session_backup.tar.gz`)에 넣습니다.
4. 맥 기본 터미널에서 프로젝트 루트 폴더로 이동한 뒤 아래 명령어를 실행합니다.
   ```bash
   bash etc/agy_session_tool.sh restore
   ```
   *(또는 인자 없이 `bash etc/agy_session_tool.sh` 실행 후 `2`번 입력)*
5. `✅ 복구 완료!` 메시지가 출력되면 **Antigravity 앱을 다시 실행**합니다.
6. 왼쪽 채팅 목록(History)에서 기존 대화방을 클릭해 그대로 이어서 진행합니다.

---

## 4. (함께 진행) 우분투 실습 환경(Step 0 ~ Step 2-2) 20초 복구 요약

채팅방 복구와 함께 OrbStack 우분투 가상머신의 실습 상태도 복구하려면 아래 3줄만 순서대로 실행하면 됩니다.

```bash
# 1) OrbStack 앱에서 Ubuntu 22.04 머신(이름: cody-ubuntu) 생성 후 맥 터미널에서 접속
orb -m cody-ubuntu -u root

# 2) 우분투 터미널 안에서 Step 0 ~ Step 2-2 자동 복구 스크립트 실행
sudo bash etc/restore_up_to_step2.sh
```
이후 `etc/B4-1-Practice-Guide.md`의 **Step 3**부터 실습을 이어가시면 됩니다.
