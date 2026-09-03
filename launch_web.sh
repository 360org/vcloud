#!/usr/bin/env bash

# ==============================================================================
# 🚀 VCLOUD FLUTTER WEB — UNIFIED LOCAL DEVELOPMENT LAUNCHER (PARALLEL MODE)
# ==============================================================================
#
# Mục đích:
#   Menu chọn kết nối Odoo Backend 17 (Port 8069) hoặc 19 (Port 8079).
#   Hỗ trợ chạy SONG SONG cả 2 Odoo cùng lúc, không tự động tắt instance kia!
#
# Cách dùng:
#   bash launch_web.sh          -> Hiển thị MENU tương tác chọn Odoo 17 hoặc 19
#   bash launch_web.sh 17       -> Khởi chạy Flutter Web kết nối Odoo 17 (:8088 -> :8069)
#   bash launch_web.sh 19       -> Khởi chạy Flutter Web kết nối Odoo 19 (:8089 -> :8079)
#
# ==============================================================================

set -Eeuo pipefail

export PATH="$HOME/flutter/bin:$PATH:/usr/local/bin"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ------------------------------------------------------------------------------
# 1. Menu Tương Tác Chọn Phiên Bản Odoo
# ------------------------------------------------------------------------------

INPUT_ARG="${1:-}"

if [[ -z "$INPUT_ARG" ]]; then
    STATUS_17="⚪ STOPPED"
    STATUS_19="⚪ STOPPED"
    if docker ps --format '{{.Names}}' | grep -q "^demo-17$"; then
        STATUS_17="🟢 RUNNING (:8069)"
    fi
    if docker ps --format '{{.Names}}' | grep -q "^demo-19$"; then
        STATUS_19="🟢 RUNNING (:8079)"
    fi

    echo "=============================================================================="
    echo "🚀 VCLOUD FLUTTER WEB — LOCAL DEVELOPMENT LAUNCHER"
    echo "=============================================================================="
    echo "📊 Trạng thái Odoo Docker hiện tại (Chạy song song):"
    echo "   • Odoo 17 (demo-17) : $STATUS_17"
    echo "   • Odoo 19 (demo-19) : $STATUS_19"
    echo "------------------------------------------------------------------------------"
    echo "👉 Vui lòng chọn phiên bản Backend muốn chạy cùng Flutter Web:"
    echo "   [1] hoặc 17   ➔ Mở Flutter Web kết nối Odoo 17 (Web Port: 8088 ➔ API: 8069)"
    echo "   [2] hoặc 19   ➔ Mở Flutter Web kết nối Odoo 19 (Web Port: 8089 ➔ API: 8079)"
    echo "   [0] hoặc q    ➔ Thoát"
    echo "------------------------------------------------------------------------------"
    DEFAULT_CHOICE="17"

    read -r -p "Nhập lựa chọn của anh [Mặc định: $DEFAULT_CHOICE]: " CHOICE
    CHOICE="${CHOICE:-$DEFAULT_CHOICE}"
else
    CHOICE="$INPUT_ARG"
fi

# ------------------------------------------------------------------------------
# 2. Thiết lập cấu hình theo phiên bản được chọn
# ------------------------------------------------------------------------------

case "$CHOICE" in
    1|17|"17.0")
        ODOO_VERSION="17.0"
        CONTAINER="demo-17"
        DB_NAME="demo-17"
        MODULE_NAME="mobile_api"
        BACKEND_DIR="$MOBILE_ROOT/v_mobile_17"
        PORT="${PORT:-8088}"
        API_URL="${API_URL:-http://127.0.0.1:8069}"
        CHROME_PROFILE="${CHROME_PROFILE:-/tmp/flutter_chrome_dev_17}"
        ;;
    2|19|"19.0")
        ODOO_VERSION="19.0"
        CONTAINER="demo-19"
        DB_NAME="demo-19"
        MODULE_NAME="v_mobile"
        BACKEND_DIR="$MOBILE_ROOT/v_mobile_19"
        PORT="${PORT:-8089}"
        API_URL="${API_URL:-http://127.0.0.1:8079}"
        CHROME_PROFILE="${CHROME_PROFILE:-/tmp/flutter_chrome_dev_19}"
        ;;
    0|q|Q|exit)
        echo "👋 Đã hủy thao tác. Thoát."
        exit 0
        ;;
    *)
        echo "❌ Lựa chọn '$CHOICE' không hợp lệ. Mặc định chọn Odoo 17."
        ODOO_VERSION="17.0"
        CONTAINER="demo-17"
        DB_NAME="demo-17"
        MODULE_NAME="mobile_api"
        BACKEND_DIR="$MOBILE_ROOT/v_mobile_17"
        PORT="${PORT:-8088}"
        API_URL="${API_URL:-http://127.0.0.1:8069}"
        CHROME_PROFILE="${CHROME_PROFILE:-/tmp/flutter_chrome_dev_17}"
        ;;
esac

# Tự động nhận diện thư mục Odoo local dev_env
if [[ -d "$MOBILE_ROOT/../dev_env/$ODOO_VERSION" ]]; then
    LOCAL_DEV_DIR="$(cd "$MOBILE_ROOT/../dev_env/$ODOO_VERSION" && pwd)"
elif [[ -d "/media/tanma/DATA/save/dev_env/$ODOO_VERSION" ]]; then
    LOCAL_DEV_DIR="/media/tanma/DATA/save/dev_env/$ODOO_VERSION"
else
    LOCAL_DEV_DIR=""
fi

echo
echo "=============================================================================="
echo "🎯 ĐÃ CHỌN: ODOO $ODOO_VERSION (CHẾ ĐỘ SONG SONG)"
echo "=============================================================================="
echo "📂 Frontend   : $SCRIPT_DIR"
echo "📂 Backend    : $BACKEND_DIR"
echo "🐳 Container  : $CONTAINER (DB: $DB_NAME)"
echo "🔌 Web Port   : $PORT ➔ Backend API: $API_URL"
echo "👤 Profile    : $CHROME_PROFILE"
echo "=============================================================================="
echo

# ------------------------------------------------------------------------------
# 3. Kiểm tra symlink mã nguồn Backend Local
# ------------------------------------------------------------------------------

echo "💻 [1/3] Đang kiểm tra mã nguồn Backend Local ($BACKEND_DIR)..."
if [[ -d "$BACKEND_DIR" ]]; then
    if [[ -n "$LOCAL_DEV_DIR" && -d "$LOCAL_DEV_DIR/modules/default" ]]; then
        ln -sfn "$BACKEND_DIR" "$LOCAL_DEV_DIR/modules/default/mobile_api" 2>/dev/null || true
        ln -sfn "$BACKEND_DIR" "$LOCAL_DEV_DIR/modules/default/v_mobile" 2>/dev/null || true
    fi
    echo "   ✅ Symlink code local đã gắn kết vào dev_env."
else
    echo "   ⚠️ Cảnh báo: Không tìm thấy thư mục Backend tại $BACKEND_DIR"
fi

# ------------------------------------------------------------------------------
# 4. Khởi động Odoo Docker tương ứng nếu chưa chạy
# ------------------------------------------------------------------------------

echo
echo "🔄 [2/3] Đang kiểm tra Odoo $ODOO_VERSION Docker stack..."

if [[ -n "$LOCAL_DEV_DIR" && -d "$LOCAL_DEV_DIR" ]]; then
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        echo "   🐳 Khởi động Odoo $ODOO_VERSION Docker stack..."
        (cd "$LOCAL_DEV_DIR" && ./dev up -d) >/dev/null 2>&1 || true

        echo "   ⏳ Đang kiểm tra Postgres Database (${CONTAINER}-db)..."
        for i in {1..10}; do
            if docker inspect "${CONTAINER}-db" 2>/dev/null | grep -q '"Status": "healthy"'; then
                echo "   ✅ Postgres Database đã sẵn sàng!"
                break
            fi
            sleep 1
        done

        echo "   🔄 Nạp code mới nhất và khởi động Odoo $CONTAINER..."
        (cd "$LOCAL_DEV_DIR" && ./dev restart odoo) >/dev/null 2>&1 || true
    else
        echo "   🟢 Container $CONTAINER đã đang chạy sẵn sàng."
    fi
fi

# Chờ Backend Odoo phản hồi HTTP
echo "   ⏳ Đang kiểm tra Odoo HTTP tại $API_URL/web/login..."
ODOO_READY=false
for i in {1..15}; do
    if curl -s -m 2 "$API_URL/web/login" >/dev/null 2>&1; then
        ODOO_READY=true
        break
    fi
    sleep 1
done

if [[ "$ODOO_READY" == true ]]; then
    echo "   ✅ Odoo $ODOO_VERSION Backend đã sẵn sàng (HTTP 200 OK) tại $API_URL!"
else
    echo "   ⚠️ Cảnh báo: Odoo Backend chưa phản hồi HTTP sau 15s. Tiếp tục mở Flutter..."
fi

# ------------------------------------------------------------------------------
# 5. Chuẩn bị Flutter Web & Khởi chạy Chrome
# ------------------------------------------------------------------------------

echo
echo "🌐 [3/3] Đang chuẩn bị Flutter Web & Chrome..."

if ! command -v flutter >/dev/null 2>&1; then
    echo "❌ Flutter không được tìm thấy trên hệ thống."
    exit 1
fi

# Giải phóng riêng web port của phiên bản được chọn
if command -v fuser >/dev/null 2>&1; then
    fuser -k -9 "${PORT}/tcp" 2>/dev/null || true
fi

# Dọn dẹp Chrome Profile stale lock files
mkdir -p "$CHROME_PROFILE"
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

echo
echo "=============================================================================="
echo "🌐 STARTING FLUTTER WEB — CONNECTING ODOO $ODOO_VERSION"
echo "=============================================================================="
echo "Backend : $API_URL (DB: $DB_NAME)"
echo "Web Port: $PORT"
echo "Profile : $CHROME_PROFILE"
echo
echo "Hotkeys:"
echo "  r → Hot Reload (0.5s)"
echo "  R → Hot Restart (1.5s)"
echo "  h → Help"
echo "  q → Quit"
echo "=============================================================================="
echo

exec flutter run \
    -d chrome \
    $MODE_FLAG \
    --web-port="$PORT" \
    --web-browser-flag="--disable-web-security" \
    --web-browser-flag="--user-data-dir=$CHROME_PROFILE" \
    --dart-define="VCLOUD_ODOO_API_BASE_URL=$API_URL" \
    --dart-define="VCLOUD_ODOO_DB=$DB_NAME"
