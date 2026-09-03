#!/usr/bin/env bash

# ==============================================================================
# 🚀 VCLOUD FLUTTER WEB — ODOO 19.0 DEDICATED LAUNCHER (PARALLEL MODE)
# ==============================================================================
#
# Mục đích:
#   Khởi chạy trực tiếp Flutter Web kết nối Odoo 19 Backend (demo-19).
#   - Web Port     : 8089
#   - Odoo API     : http://127.0.0.1:8079 (DB: demo-19)
#   - Chrome Data  : /tmp/flutter_chrome_dev_19 (Cô lập session với Odoo 17)
#
# Cách dùng:
#   bash launch_web_19.sh
#   bash launch_web_19.sh --release
#
# ==============================================================================

set -Eeuo pipefail

export PATH="$HOME/flutter/bin:$PATH:/usr/local/bin"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ODOO_VERSION="19.0"
CONTAINER="demo-19"
DB_NAME="demo-19"
MODULE_NAME="v_mobile"
BACKEND_DIR="$MOBILE_ROOT/v_mobile_19"
PORT="${PORT:-8089}"
API_URL="${API_URL:-http://127.0.0.1:8079}"
CHROME_PROFILE="${CHROME_PROFILE:-/tmp/flutter_chrome_dev_19}"

if [[ -d "$MOBILE_ROOT/../dev_env/19.0" ]]; then
    LOCAL_DEV_DIR="$(cd "$MOBILE_ROOT/../dev_env/19.0" && pwd)"
elif [[ -d "/media/tanma/DATA/save/dev_env/19.0" ]]; then
    LOCAL_DEV_DIR="/media/tanma/DATA/save/dev_env/19.0"
else
    LOCAL_DEV_DIR=""
fi

echo "=============================================================================="
echo "🚀 VCLOUD FLUTTER WEB — ODOO 19.0 (CHẾ ĐỘ SONG SONG)"
echo "=============================================================================="
echo "📂 Frontend   : $SCRIPT_DIR"
echo "📂 Backend    : $BACKEND_DIR"
echo "🐳 Container  : $CONTAINER (DB: $DB_NAME)"
echo "🔌 Web Port   : $PORT ➔ Backend API: $API_URL"
echo "👤 Profile    : $CHROME_PROFILE"
echo "=============================================================================="
echo

# 1. Gắn kết symlink code local
echo "💻 [1/3] Đang kiểm tra mã nguồn Backend Local ($BACKEND_DIR)..."
if [[ -d "$BACKEND_DIR" ]]; then
    if [[ -n "$LOCAL_DEV_DIR" && -d "$LOCAL_DEV_DIR/modules/default" ]]; then
        ln -sfn "$BACKEND_DIR" "$LOCAL_DEV_DIR/modules/default/v_mobile" 2>/dev/null || true
    fi
    echo "   ✅ Symlink code local Odoo 19 đã sẵn sàng."
else
    echo "   ⚠️ Cảnh báo: Không tìm thấy thư mục Backend tại $BACKEND_DIR"
fi

# 2. Khởi động Odoo 19 Docker stack nếu chưa chạy
echo
echo "🔄 [2/3] Đang kiểm tra Odoo 19 Docker stack ($CONTAINER)..."
if [[ -n "$LOCAL_DEV_DIR" && -d "$LOCAL_DEV_DIR" ]]; then
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        echo "   🐳 Khởi động Odoo 19 Docker stack..."
        (cd "$LOCAL_DEV_DIR" && ./dev up -d) >/dev/null 2>&1 || true

        echo "   ⏳ Đang kiểm tra Postgres Database (${CONTAINER}-db)..."
        for i in {1..10}; do
            if docker inspect "${CONTAINER}-db" 2>/dev/null | grep -q '"Status": "healthy"'; then
                echo "   ✅ Postgres Database Odoo 19 đã sẵn sàng!"
                break
            fi
            sleep 1
        done

        echo "   🔄 Nạp code và khởi động Odoo $CONTAINER..."
        (cd "$LOCAL_DEV_DIR" && ./dev restart odoo) >/dev/null 2>&1 || true
    else
        echo "   🟢 Container $CONTAINER đã đang chạy sẵn sàng."
    fi
fi

echo "   ⏳ Đang kiểm tra Odoo 19 HTTP tại $API_URL/web/login..."
ODOO_READY=false
for i in {1..15}; do
    if curl -s -m 2 "$API_URL/web/login" >/dev/null 2>&1; then
        ODOO_READY=true
        break
    fi
    sleep 1
done

if [[ "$ODOO_READY" == true ]]; then
    echo "   ✅ Odoo 19 Backend đã sẵn sàng (HTTP 200 OK) tại $API_URL!"
else
    echo "   ⚠️ Cảnh báo: Odoo 19 Backend chưa phản hồi HTTP sau 15s. Tiếp tục mở Flutter..."
fi

# 3. Chuẩn bị Flutter Web & Khởi chạy Chrome
echo
echo "🌐 [3/3] Đang chuẩn bị Flutter Web Odoo 19 trên Port $PORT..."

if ! command -v flutter >/dev/null 2>&1; then
    echo "❌ Flutter không được tìm thấy trên hệ thống."
    exit 1
fi

if command -v fuser >/dev/null 2>&1; then
    fuser -k -9 "${PORT}/tcp" 2>/dev/null || true
fi

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
echo "🌐 STARTING FLUTTER WEB — CONNECTING ODOO 19.0"
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
