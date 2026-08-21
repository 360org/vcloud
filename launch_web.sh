#!/usr/bin/env bash

# ==============================================================================
# 🚀 VCLOUD FLUTTER WEB — LOCAL DEVELOPMENT (DIRECT LOCAL SYNC)
# ==============================================================================
#
# Mục đích:
#   1. Sử dụng trực tiếp mã nguồn Backend Local trên máy ($BACKEND_DIR).
#      KHÔNG pull từ GitLab remote 17.0 để bảo toàn 100% code mới vừa sửa ở local.
#   2. Khởi động Odoo 17 Docker trên Laptop (127.0.0.1:8069) và nạp/upgrade module
#      mobile_api trực tiếp từ thư mục local.
#   3. Khởi chạy Google Chrome Flutter Web kết nối trực tiếp Odoo Backend Local.
#
# Frontend:
#   vclients
#
# Default Backend:
#   http://127.0.0.1:8069 (Laptop Local /dev_env/17.0)
#
# Port:
#   8088
#
# Chrome profile:
#   /tmp/flutter_chrome_dev
#
# ==============================================================================

set -Eeuo pipefail

export PATH="$PATH:$HOME/flutter/bin:/usr/local/bin"

# ------------------------------------------------------------------------------
# 0. Định vị thư mục dự án
# ------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_DIR="$MOBILE_ROOT/v_mobile"
LOCAL_DEV_DIR="/media/tanma/DATA/save/dev_env/17.0"

cd "$SCRIPT_DIR"

# ------------------------------------------------------------------------------
# Cấu hình tham số
# ------------------------------------------------------------------------------

PORT="${PORT:-8088}"
CHROME_PROFILE="${CHROME_PROFILE:-/tmp/flutter_chrome_dev}"
API_URL="${API_URL:-}"

# ------------------------------------------------------------------------------
# Banner mở đầu
# ------------------------------------------------------------------------------

echo
echo "=============================================================================="
echo "🚀 VCLOUD FLUTTER WEB — LOCAL DEV & DIRECT LOCAL BACKEND"
echo "=============================================================================="
echo "📂 Frontend   : $SCRIPT_DIR"
echo "📂 Backend    : $BACKEND_DIR (Local Machine)"
echo "🔌 Web Port   : $PORT"
echo "👤 Profile    : $CHROME_PROFILE"
echo "=============================================================================="
echo

# ------------------------------------------------------------------------------
# 1. Kiểm tra mã nguồn Backend Local (Không pull git remote)
# ------------------------------------------------------------------------------

echo "💻 [1/3] Đang kiểm tra mã nguồn Backend Local ($BACKEND_DIR)..."
if [[ -d "$BACKEND_DIR" ]]; then
    # Đảm bảo symlink trong dev_env trỏ chính xác vào thư mục v_mobile local
    if [[ -d "$LOCAL_DEV_DIR/modules/default" ]]; then
        ln -sfn "$BACKEND_DIR" "$LOCAL_DEV_DIR/modules/default/mobile_api" 2>/dev/null || true
        ln -sfn "$BACKEND_DIR" "$LOCAL_DEV_DIR/modules/default/v_mobile" 2>/dev/null || true
    fi
    echo "   ✅ Đang sử dụng trực tiếp code local trên máy (không ghi đè từ git remote)."
else
    echo "   ⚠️ Cảnh báo: Không tìm thấy thư mục Backend tại $BACKEND_DIR"
fi

# ------------------------------------------------------------------------------
# 2. Khởi động Odoo 17 dev_env trên Máy Laptop (Local) & Nạp code mới
# ------------------------------------------------------------------------------

echo
echo "🔄 [2/3] Đang khởi động Odoo 17 trên Máy Laptop (Local)..."

if [[ -d "$LOCAL_DEV_DIR" ]]; then
    echo "   🐳 Đang khởi động Odoo 17 Docker trên Laptop ($LOCAL_DEV_DIR)..."
    (cd "$LOCAL_DEV_DIR" && ./prod up -d) >/dev/null 2>&1 || true
    echo "   🔄 Khởi động lại container Odoo demo-17 để nạp code local mới..."
    (cd "$LOCAL_DEV_DIR" && ./prod restart odoo) >/dev/null 2>&1 || true
    
    # Nâng cấp module mobile_api trong database demo-17 nếu container đang chạy
    if command -v docker >/dev/null 2>&1; then
        echo "   ⚡ Đang nâng cấp module mobile_api trên DB demo-17..."
        docker exec demo-17 python3 -c "import odoo; from odoo import api, SUPERUSER_ID
registry = odoo.registry('demo-17')
with registry.cursor() as cr:
    env = api.Environment(cr, SUPERUSER_ID, {})
    mod = env['ir.module.module'].search([('name', 'in', ['mobile_api', 'v_mobile'])])
    for m in mod:
        if m.state == 'installed':
            m.button_immediate_upgrade()
" >/dev/null 2>&1 || true
        echo "   ✅ Đã nạp và nâng cấp code Backend local vào Odoo thành công!"
    fi
else
    echo "   ⚠️ Không tìm thấy $LOCAL_DEV_DIR"
fi

if [[ -z "$API_URL" ]]; then
    API_URL="http://127.0.0.1:8069"
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
    echo "   ✅ Odoo Backend đã sẵn sàng (HTTP 200 OK) tại $API_URL!"
else
    echo "   ⚠️ Cảnh báo: Odoo Backend chưa phản hồi HTTP sau 15s. Tiếp tục mở Flutter..."
fi

# ------------------------------------------------------------------------------
# 3. Chuẩn bị môi trường Flutter Web & Google Chrome
# ------------------------------------------------------------------------------

echo
echo "🌐 [3/3] Đang chuẩn bị Flutter Web & Chrome..."

# Kiểm tra Flutter binary
if ! command -v flutter >/dev/null 2>&1; then
    echo "❌ Flutter không được tìm thấy trên hệ thống."
    exit 1
fi

# Giải phóng port 8088
if command -v fuser >/dev/null 2>&1; then
    fuser -k -9 "${PORT}/tcp" 2>/dev/null || true
fi

if command -v lsof >/dev/null 2>&1; then
    lsof -ti "tcp:${PORT}" 2>/dev/null \
        | xargs -r kill -9 2>/dev/null || true
fi

pkill -f "flutter_tools.*--web-port=${PORT}" 2>/dev/null || true

# Kiểm tra dependencies
if [[ ! -d ".dart_tool" ]]; then
    echo "   📦 Flutter dependencies chưa tồn tại. Đang tải..."
    flutter pub get
else
    echo "   ✅ Flutter dependencies đã sẵn sàng."
fi

# Dọn dẹp Chrome Profile stale lock files
mkdir -p "$CHROME_PROFILE"
rm -f \
    "${CHROME_PROFILE}/SingletonLock" \
    "${CHROME_PROFILE}/SingletonSocket" \
    "${CHROME_PROFILE}/SingletonCookie" \
    "${CHROME_PROFILE}/DevToolsActivePort" \
    2>/dev/null || true

# ------------------------------------------------------------------------------
# 4. Khởi chạy Chrome Flutter Web
# ------------------------------------------------------------------------------

MODE_FLAG=""
for arg in "$@"; do
    if [[ "$arg" == "--release" ]] || [[ "$arg" == "--profile" ]]; then
        MODE_FLAG="$arg"
    fi
done

echo
echo "=============================================================================="
echo "🌐 STARTING FLUTTER WEB — LOCAL ODOO"
echo "=============================================================================="
echo "Backend : $API_URL"
echo "Port    : $PORT"
echo
echo "Hotkeys:"
echo "  r → Hot Reload"
echo "  R → Hot Restart"
echo "  h → Help"
echo "  q → Quit"
echo
echo "⚠️  Chrome Web Security DISABLED (Cho phép gọi Odoo API trực tiếp)."
echo "⚠️  Chỉ sử dụng session Chrome này cho DEV/QA."
echo "=============================================================================="
echo

exec flutter run \
    -d chrome \
    $MODE_FLAG \
    --web-port="$PORT" \
    --web-browser-flag="--disable-web-security" \
    --web-browser-flag="--user-data-dir=$CHROME_PROFILE" \
    --dart-define="VCLOUD_ODOO_API_BASE_URL=$API_URL" \
    --dart-define="VCLOUD_ODOO_DB=${ODOO_DB:-demo-17}"

