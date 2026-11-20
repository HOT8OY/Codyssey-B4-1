#!/usr/bin/env bash
# ==============================================================================
# agy_session_tool.sh
# Antigravity 채팅방(UI 세션 및 브레인 로그) 원클릭 추출(Export) & 복구(Restore) 도구
#
# [사용 방법 (맥 기본 터미널에서 실행)]
#   1) 대화형 실행 : bash etc/agy_session_tool.sh
#   2) 바로 추출   : bash etc/agy_session_tool.sh export
#   3) 바로 복구   : bash etc/agy_session_tool.sh restore
# ==============================================================================

set -euo pipefail

AGY_DIR="${HOME}/.gemini/antigravity"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_FILE="${SCRIPT_DIR}/agy_session_backup.tar.gz"
MAIN_CONV_ID="5efa96b0-fd06-43e7-96fd-63cb3955deda"

do_export() {
    echo "============================================================"
    echo "📦 Antigravity 채팅 세션 추출(Export)을 시작합니다..."
    echo "============================================================"

    if [ ! -d "${AGY_DIR}" ]; then
        echo "[ERROR] Antigravity 데이터 폴더를 찾을 수 없습니다: ${AGY_DIR}"
        exit 1
    fi

    # 현재 메인 대화방을 포함하여 conversations/ 와 brain/ 폴더를 안전하게 압축
    TARGETS=()
    [ -d "${AGY_DIR}/conversations" ] && TARGETS+=("conversations")
    [ -d "${AGY_DIR}/brain" ] && TARGETS+=("brain")

    if [ "${#TARGETS[@]}" -eq 0 ]; then
        echo "[ERROR] 백업할 conversations 또는 brain 폴더가 없습니다."
        exit 1
    fi

    tar -czf "${BACKUP_FILE}" -C "${AGY_DIR}" "${TARGETS[@]}"

    FILE_SIZE=$(du -h "${BACKUP_FILE}" | awk '{print $1}')
    echo ""
    echo "✅ 추출 완료!"
    echo "   - 백업 파일 위치 : ${BACKUP_FILE}"
    echo "   - 백업 파일 크기 : ${FILE_SIZE}"
    echo "   - 메인 대화방 ID : ${MAIN_CONV_ID}"
    echo ""
    echo "💡 이제 위 백업 파일(agy_session_backup.tar.gz)과 이 스크립트(agy_session_tool.sh)를"
    echo "   개인 드라이브에 업로드해 두세요."
}

do_restore() {
    echo "============================================================"
    echo "♻️  Antigravity 채팅 세션 복구(Restore)를 시작합니다..."
    echo "============================================================"

    if [ ! -f "${BACKUP_FILE}" ]; then
        echo "[ERROR] 백업 파일을 찾을 수 없습니다: ${BACKUP_FILE}"
        echo "        개인 드라이브에서 받은 agy_session_backup.tar.gz 파일을"
        echo "        ${SCRIPT_DIR}/ 폴더 안에 넣은 뒤 다시 실행해 주세요."
        exit 1
    fi

    mkdir -p "${AGY_DIR}"
    tar -xzf "${BACKUP_FILE}" -C "${AGY_DIR}"

    echo ""
    echo "✅ 복구 완료!"
    echo "   - 복구된 경로 : ${AGY_DIR}/conversations 및 ${AGY_DIR}/brain"
    echo ""
    echo "⚠️ 중요: Antigravity 앱이 현재 켜져 있다면 완전히 종료(Cmd + Q)한 뒤"
    echo "   다시 실행해야 왼쪽 채팅 목록(UI)에 복구된 대화방이 정상 표시됩니다."
}

MODE="${1:-}"

if [ -z "${MODE}" ]; then
    echo "============================================================"
    echo " Antigravity 세션 백업 / 복구 도구"
    echo "============================================================"
    echo "  1) 세션 추출하기 (Export -> etc/agy_session_backup.tar.gz 생성)"
    echo "  2) 세션 복구하기 (Restore -> ~/.gemini/antigravity 로 복원)"
    echo "------------------------------------------------------------"
    read -rp "번호를 선택하세요 (1 또는 2): " CHOICE
    case "${CHOICE}" in
        1) MODE="export" ;;
        2) MODE="restore" ;;
        *) echo "[ERROR] 1 또는 2를 입력해 주세요."; exit 1 ;;
    esac
fi

case "${MODE}" in
    export)  do_export ;;
    restore) do_restore ;;
    *)
        echo "사용법: bash $0 [export|restore]"
        exit 1
        ;;
esac
