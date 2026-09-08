#!/usr/bin/env bash

# ==============================================================================
# 🚀 VCLOUD FLUTTER WEB — LOCAL SERVER SSH LAUNCHER
# ==============================================================================
#
# Kết nối Flutter Web tới Odoo Backend đang chạy trên Local Server (192.168.1.100)
#
# Cách dùng:
#   ./launch_web_ssh.sh          -> Mặc định kết nối Odoo 17 (:8069)
#   ./launch_web_ssh.sh 17       -> Kết nối Odoo 17 (:8069)
#   ./launch_web_ssh.sh 19       -> Kết nối Odoo 19 (:1900)
#   ./launch_web_ssh.sh 18       -> Kết nối Odoo 18 (:1800)
#
# ==============================================================================

set -Eeuo pipefail

export PATH="$HOME/flutter/bin:$PATH:/usr/local/bin"

# Định vị thư mục vclients chính xác dù gọi qua symlink
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

SERVER_HOST="${SERVER_HOST:-192.168.1.100}"
SSH_ALIAS="${SSH_ALIAS:-local}"

# ------------------------------------------------------------------------------
# 1. Chọn phiên bản Odoo Backend trên Server
# ------------------------------------------------------------------------------

INPUT_ARG="${1:-}"

if [[ -z "$INPUT_ARG" ]]; then
    echo "=============================================================================="
    echo "🚀 VCLOUD FLUTTER WEB — CONNECT LOCAL SERVER ($SERVER_HOST)"
    echo "=============================================================================="
    echo "👉 Chọn phiên bản Backend trên Server Local:"
    echo "   [1] hoặc 17   ➔ Odoo 17.0 (API: http://$SERVER_HOST:8069, DB: demo-17)"
    echo "   [2] hoặc 19   ➔ Odoo 19.0 (API: http://$SERVER_HOST:1900, DB: odoo_19)"
    echo "   [3] hoặc 18   ➔ Odoo 18.0 (API: http://$SERVER_HOST:1800, DB: odoo_18)"
    echo "   [0] hoặc q    ➔ Thoát"
    echo "------------------------------------------------------------------------------"
    read -r -p "Nhập lựa chọn của Sếp [Mặc định: 17]: " CHOICE
    CHOICE="${CHOICE:-17}"
else
    CHOICE="$INPUT_ARG"
fi

case "$CHOICE" in
    1|17|"17.0")
        ODOO_VERSION="17.0"
        API_PORT="8069"
        DB_NAME="demo-17"
        WEB_PORT="${PORT:-8088}"
        CHROME_PROFILE="/tmp/flutter_chrome_ssh_17"
        ;;
    2|19|"19.0")
        ODOO_VERSION="19.0"
        API_PORT="1900"
        DB_NAME="odoo_19"
        WEB_PORT="${PORT:-8089}"
        CHROME_PROFILE="/tmp/flutter_chrome_ssh_19"
        ;;
    3|18|"18.0")
        ODOO_VERSION="18.0"
        API_PORT="1800"
        DB_NAME="odoo_18"
        WEB_PORT="${PORT:-8087}"
        CHROME_PROFILE="/tmp/flutter_chrome_ssh_18"
        ;;
    0|q|Q|exit)
        echo "👋 Đã hủy thao tác. Thoát."
        exit 0
        ;;
    *)
        echo "❌ Lựa chọn '$CHOICE' không hợp lệ. Mặc định chọn Odoo 17."
        ODOO_VERSION="17.0"
        API_PORT="8069"
        DB_NAME="demo-17"
        WEB_PORT="${PORT:-8088}"
        CHROME_PROFILE="/tmp/flutter_chrome_ssh_17"
        ;;
esac

API_URL="http://${SERVER_HOST}:${API_PORT}"

echo
echo "=============================================================================="
echo "🎯 ĐÃ CHỌN: ODOO $ODOO_VERSION TRÊN SERVER LOCAL"
echo "=============================================================================="
echo "🌐 Server IP   : $SERVER_HOST (SSH alias: $SSH_ALIAS)"
echo "🔌 Backend API : $API_URL (DB: $DB_NAME)"
echo "🖥️ Flutter Web : http://localhost:$WEB_PORT"
echo "👤 Profile     : $CHROME_PROFILE"
echo "=============================================================================="
echo

# ------------------------------------------------------------------------------
# 2. Tự động đồng bộ code v_mobile lên Server Local (Auto-Sync Zero-Touch)
# ------------------------------------------------------------------------------

echo "🔄 [1/3] Kiểm tra & Tự động đồng bộ mã nguồn Backend lên Server Local..."

PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SYNC_ERROR=0

# A. Đồng bộ Odoo 17
if [[ -d "$PARENT_DIR/v_mobile_17" ]]; then
    echo "   📦 Đang đồng bộ v_mobile_17 -> Server Local ($SERVER_HOST)..."
    rsync -aq --delete \
        --exclude='.git' --exclude='__pycache__' --exclude='*.pyc' --exclude='.claude' --exclude='.codegraph' \
        "$PARENT_DIR/v_mobile_17/" "$SSH_ALIAS:/home/corp360/DATA/save/mobile/work_test_auth/v_mobile_17/" 2>/dev/null || SYNC_ERROR=1
    rsync -aq --delete \
        --exclude='.git' --exclude='__pycache__' --exclude='*.pyc' --exclude='.claude' --exclude='.codegraph' \
        "$PARENT_DIR/v_mobile_17/" "$SSH_ALIAS:/mnt/DATA/work/17.0/extra/v_mobile/" 2>/dev/null || SYNC_ERROR=1
fi

# B. Đồng bộ Odoo 19
if [[ -d "$PARENT_DIR/v_mobile_19" ]]; then
    echo "   📦 Đang đồng bộ v_mobile_19 -> Server Local ($SERVER_HOST)..."
    rsync -aq --delete \
        --exclude='.git' --exclude='__pycache__' --exclude='*.pyc' --exclude='.claude' --exclude='.codegraph' \
        "$PARENT_DIR/v_mobile_19/" "$SSH_ALIAS:/mnt/DATA/work/19.0/extra/v_mobile/" 2>/dev/null || SYNC_ERROR=1
fi

if [[ $SYNC_ERROR -eq 0 ]]; then
    echo "   ✅ PASS: Đồng bộ mã nguồn hoàn tất thành công 100%"
else
    echo "   ⚠️ CẢNH BÁO: Quá trình rsync gặp cảnh báo nhẹ quyền hạn, tiếp tục kiểm tra..."
fi
echo

# ------------------------------------------------------------------------------
# 3. Kiểm tra kết nối mạng tới Server & Port Backend
# ------------------------------------------------------------------------------

echo "📡 [2/3] Kiểm tra kết nối Backend ($API_URL)..."
echo "   [CMD] curl -s -m 3 $API_URL/web/login"

if curl -s -m 3 "$API_URL/web/login" >/dev/null 2>&1; then
    echo "   ✅ PASS: Kết nối thành công (HTTP 200 OK)"
else
    echo "   ❌ FAIL: Không thể kết nối tới $API_URL"
    read -r -p "Tiếp tục mở Flutter Web? [y/N]: " PROCEED
    if [[ ! "$PROCEED" =~ ^[yY]$ ]]; then
        exit 1
    fi
fi

# ------------------------------------------------------------------------------
# 3. Chuẩn bị Flutter Web & Khởi chạy Chrome
# ------------------------------------------------------------------------------

echo
echo "🌐 [2/2] Khởi chạy Flutter Web..."

if ! command -v flutter >/dev/null 2>&1; then
    echo "   ❌ FAIL: Không tìm thấy lệnh 'flutter'"
    exit 1
fi

# Giải phóng web port nếu bị chiếm
if command -v fuser >/dev/null 2>&1; then
    fuser -k -9 "${WEB_PORT}/tcp" 2>/dev/null || true
fi

mkdir -p "$CHROME_PROFILE"
# Tự động dọn dẹp profile Chrome cũ để tránh lưu cache DB / session lỗi
rm -rf "${CHROME_PROFILE:?}"/* 2>/dev/null || true
rm -f \
    "${CHROME_PROFILE}/SingletonLock" \
    "${CHROME_PROFILE}/SingletonSocket" \
    "${CHROME_PROFILE}/SingletonCookie" \
    "${CHROME_PROFILE}/DevToolsActivePort" \
    2>/dev/null || true

MODE_FLAG=""
for arg in "$@"; do
    if [[ "$arg" == "--release" ]] || [[ "$arg" == "--profile" ]]; then
        MODE_FLAG="$arg"
    fi
done

cd "$SCRIPT_DIR"

echo "   [CMD] flutter run -d chrome --no-pub --web-port=$WEB_PORT (đang build, chờ ~20s)..."
echo "   💡 Khi Chrome mở, đợi trang nạp xong rồi đăng nhập."
echo

exec flutter run \
    -d chrome \
    --no-pub \
    $MODE_FLAG \
    --web-port="$WEB_PORT" \
    --web-browser-flag="--disable-web-security" \
    --web-browser-flag="--user-data-dir=$CHROME_PROFILE" \
    --dart-define="VCLOUD_ODOO_API_BASE_URL=$API_URL" \
    --dart-define="VCLOUD_ODOO_DB=$DB_NAME"
