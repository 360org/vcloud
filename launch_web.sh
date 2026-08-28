#!/usr/bin/env bash

# ==============================================================================
# 🚀 VCLOUD FLUTTER WEB — UNIFIED LOCAL DEVELOPMENT LAUNCHER
# ==============================================================================
#
# Mục đích:
#   Menu chọn khởi động Odoo Backend 17 hoặc 19 và chạy Flutter Web kết nối đồng bộ.
#
# Cách dùng:
#   bash launch_web.sh          -> Hiển thị MENU tương tác chọn Odoo 17 hoặc 19
#   bash launch_web.sh 17       -> Khởi chạy ngay với Odoo 17 (demo-17)
#   bash launch_web.sh 19       -> Khởi chạy ngay với Odoo 19 (demo-19)
#
# ==============================================================================

set -Eeuo pipefail

export PATH="$HOME/flutter/bin:$PATH:/usr/local/bin"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PORT="${PORT:-8088}"
CHROME_PROFILE="${CHROME_PROFILE:-/tmp/flutter_chrome_dev}"
API_URL="${API_URL:-http://127.0.0.1:8069}"

# ------------------------------------------------------------------------------
# 1. Menu Tương Tác Chọn Phiên Bản Odoo
# ------------------------------------------------------------------------------

INPUT_ARG="${1:-}"

if [[ -z "$INPUT_ARG" ]]; then
    # Kiểm tra trạng thái các container hiện tại
    STATUS_17="⚪ STOPPED"
    STATUS_19="⚪ STOPPED"
    if docker ps --format '{{.Names}}' | grep -q "^demo-17$"; then
        STATUS_17="🟢 RUNNING"
    fi
    if docker ps --format '{{.Names}}' | grep -q "^demo-19$"; then
        STATUS_19="🟢 RUNNING"
    fi

    echo "=============================================================================="
    echo "🚀 VCLOUD FLUTTER WEB — LOCAL DEVELOPMENT LAUNCHER"
    echo "=============================================================================="
    echo "📊 Trạng thái Odoo Docker hiện tại:"
    echo "   • Odoo 17 (demo-17) : $STATUS_17"
    echo "   • Odoo 19 (demo-19) : $STATUS_19"
    echo "------------------------------------------------------------------------------"
    echo "👉 Vui lòng chọn phiên bản Backend muốn chạy cùng Flutter Web:"
    echo "   [1] hoặc 17   ➔ Khởi động Odoo 17 & Mở Flutter Web [Mặc định]"
    echo "   [2] hoặc 19   ➔ Khởi động Odoo 19 & Mở Flutter Web"
    echo "   [3] hoặc auto ➔ Tự động nhận diện bản đang chạy để mở Web"
    echo "   [0] hoặc q    ➔ Thoát"
    echo "------------------------------------------------------------------------------"
    DEFAULT_CHOICE="17"
    if [[ "$STATUS_19" == "🟢 RUNNING" && "$STATUS_17" != "🟢 RUNNING" ]]; then
        DEFAULT_CHOICE="19"
    elif [[ "$STATUS_17" == "🟢 RUNNING" ]]; then
        DEFAULT_CHOICE="17"
    fi

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
        OPPOSING_CONTAINER="demo-19"
        BACKEND_DIR="$MOBILE_ROOT/v_mobile_17"
        ;;
    2|19|"19.0")
        ODOO_VERSION="19.0"
        CONTAINER="demo-19"
        DB_NAME="demo-19"
        MODULE_NAME="v_mobile"
        OPPOSING_CONTAINER="demo-17"
        BACKEND_DIR="$MOBILE_ROOT/v_mobile_19"
        ;;
    3|auto|"AUTO")
        if docker ps --format '{{.Names}}' | grep -q "^demo-19$"; then
            ODOO_VERSION="19.0"
            CONTAINER="demo-19"
            DB_NAME="demo-19"
            MODULE_NAME="v_mobile"
            OPPOSING_CONTAINER="demo-17"
            BACKEND_DIR="$MOBILE_ROOT/v_mobile_19"
        else
            ODOO_VERSION="17.0"
            CONTAINER="demo-17"
            DB_NAME="demo-17"
            MODULE_NAME="mobile_api"
            OPPOSING_CONTAINER="demo-19"
            BACKEND_DIR="$MOBILE_ROOT/v_mobile_17"
        fi
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
        OPPOSING_CONTAINER="demo-19"
        BACKEND_DIR="$MOBILE_ROOT/v_mobile_17"
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
echo "🎯 ĐÃ CHỌN: ODOO $ODOO_VERSION"
echo "=============================================================================="
echo "📂 Frontend   : $SCRIPT_DIR"
echo "📂 Backend    : $BACKEND_DIR"
echo "🐳 Container  : $CONTAINER (DB: $DB_NAME)"
echo "🔌 Web Port   : $PORT (Backend API: $API_URL)"
echo "👤 Profile    : $CHROME_PROFILE"
echo "=============================================================================="
echo

# ------------------------------------------------------------------------------
# 3. Kiểm tra symlink và giải phóng port 8069
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

# Tự động giải phóng port 8069 nếu container bản kia đang chạy
if command -v docker >/dev/null 2>&1; then
    if docker ps --format '{{.Names}}' | grep -q "^${OPPOSING_CONTAINER}$"; then
        echo "   🛑 Phát hiện $OPPOSING_CONTAINER đang chiếm port 8069. Đang dọn dẹp sạch sẽ để chuyển sang $ODOO_VERSION..."
        if [[ "$OPPOSING_CONTAINER" == "demo-19" ]]; then
            (cd "/media/tanma/DATA/save/dev_env/19.0" && ./prod down) >/dev/null 2>&1 || true
        else
            (cd "/media/tanma/DATA/save/dev_env/17.0" && ./prod down) >/dev/null 2>&1 || true
        fi
        docker stop "$OPPOSING_CONTAINER" "${OPPOSING_CONTAINER}-db" >/dev/null 2>&1 || true
        sleep 1
        if command -v fuser >/dev/null 2>&1; then
            fuser -k -9 8069/tcp 2>/dev/null || true
        fi
        sleep 1
    fi
fi


# ------------------------------------------------------------------------------
# 4. Khởi động Odoo Docker & Nâng cấp module
# ------------------------------------------------------------------------------

echo
echo "🔄 [2/3] Đang khởi động Odoo $ODOO_VERSION trên Máy Laptop (Local)..."

if [[ -n "$LOCAL_DEV_DIR" && -d "$LOCAL_DEV_DIR" ]]; then
    echo "   🐳 Khởi động Odoo $ODOO_VERSION Docker stack..."
    (cd "$LOCAL_DEV_DIR" && ./prod up -d) >/dev/null 2>&1 || true
    
    # Chờ Postgres Database sẵn sàng
    echo "   ⏳ Đang kiểm tra Postgres Database (${CONTAINER}-db)..."
    for i in {1..10}; do
        if docker inspect "${CONTAINER}-db" 2>/dev/null | grep -q '"Status": "healthy"'; then
            echo "   ✅ Postgres Database đã sẵn sàng!"
            break
        fi
        sleep 1
    done

    echo "   🔄 Nạp code mới nhất và khởi động Odoo $CONTAINER..."
    (cd "$LOCAL_DEV_DIR" && ./prod restart odoo) >/dev/null 2>&1 || true
    
    # Nâng cấp module trong database
    if command -v docker >/dev/null 2>&1; then
        echo "   ⚡ Đang nâng cấp module $MODULE_NAME trên DB $DB_NAME..."
        docker exec "$CONTAINER" python3 -c "import odoo
from odoo import api, SUPERUSER_ID
try:
    try:
        from odoo.orm.registry import Registry
        reg = Registry('$DB_NAME')
    except (ImportError, AttributeError):
        try:
            from odoo.modules.registry import Registry
            reg = Registry('$DB_NAME')
        except (ImportError, AttributeError):
            reg = odoo.registry('$DB_NAME')
    with reg.cursor() as cr:
        env = api.Environment(cr, SUPERUSER_ID, {})
        mod = env['ir.module.module'].search([('name', 'in', ['mobile_api', 'v_mobile'])])
        for m in mod:
            if m.state == 'installed':
                m.button_immediate_upgrade()
except Exception:
    pass
" >/dev/null 2>&1 || true
        echo "   ✅ Đã nạp code Backend local vào Odoo $ODOO_VERSION thành công!"
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

# Giải phóng port 8088
if command -v fuser >/dev/null 2>&1; then
    fuser -k -9 "${PORT}/tcp" 2>/dev/null || true
fi

if command -v lsof >/dev/null 2>&1; then
    lsof -ti "tcp:${PORT}" 2>/dev/null | xargs -r kill -9 2>/dev/null || true
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
echo
echo "Hotkeys:"
echo "  r → Hot Reload (0.5s)"
echo "  R → Hot Restart (1.5s)"
echo "  h → Help"
echo "  q → Quit"
echo
echo "⚠️  Chrome Web Security DISABLED (Cho phép gọi Odoo API trực tiếp)."
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
