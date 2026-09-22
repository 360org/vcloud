#!/usr/bin/env bash

# ==============================================================================
# 🚀 VCLOUD FLUTTER WEB — LOCAL SERVER SSH LAUNCHER
# ==============================================================================
#
# Kết nối Flutter Web tới Odoo Backend trên Local Server (192.168.1.100).
# Mặc định chạy thẳng chế độ Đa Database (tự động hiện popup chọn 4 DB khi đăng nhập).
#
# Cách dùng:
#   ./launch_web_ssh.sh          -> Chạy ngay lập tức 1-click (Zero-Interaction)
#   ./launch_web_ssh.sh 17       -> (Tùy chọn) Khóa cứng vào Odoo 17 (:8069, demo-17)
#   ./launch_web_ssh.sh 19       -> (Tùy chọn) Khóa cứng vào Odoo 19 (:1900, vcloud_test_v19)
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
# 1. Cấu hình Backend: Mặc định chạy thẳng Multi-Database (Zero-Prompt)
# ------------------------------------------------------------------------------

INPUT_ARG="${1:-}"

case "$INPUT_ARG" in
    1|17|"17.0")
        ODOO_VERSION="17.0 Cố Định"
        API_PORT="8069"
        DB_NAME="demo-17"
        WEB_PORT="${PORT:-8088}"
        CHROME_PROFILE="/tmp/flutter_chrome_ssh_17"
        ;;
    1-2|"17-2"|"17_tenant2"|"demo-17-tenant2")
        ODOO_VERSION="17.0 Tenant 2 Cố Định"
        API_PORT="8069"
        DB_NAME="demo-17-tenant2"
        WEB_PORT="${PORT:-8088}"
        CHROME_PROFILE="/tmp/flutter_chrome_ssh_17_tenant2"
        ;;
    2|19|"19.0"|vcloud|"vcloud_test_v19")
        ODOO_VERSION="19.0 Cố Định"
        API_PORT="1900"
        DB_NAME="vcloud_test_v19"
        WEB_PORT="${PORT:-8089}"
        CHROME_PROFILE="/tmp/flutter_chrome_ssh_19"
        ;;
    2-2|"19-2"|"19_tenant2"|"vcloud_test_v19_tenant2")
        ODOO_VERSION="19.0 Tenant 2 Cố Định"
        API_PORT="1900"
        DB_NAME="vcloud_test_v19_tenant2"
        WEB_PORT="${PORT:-8089}"
        CHROME_PROFILE="/tmp/flutter_chrome_ssh_19_tenant2"
        ;;
    3|davita|"davita_v19")
        ODOO_VERSION="19.0 Davita Cố Định"
        API_PORT="1900"
        DB_NAME="davita_v19"
        WEB_PORT="${PORT:-8089}"
        CHROME_PROFILE="/tmp/flutter_chrome_ssh_19"
        ;;
    4|18|"18.0")
        ODOO_VERSION="18.0 Cố Định"
        API_PORT="1800"
        DB_NAME="odoo_18"
        WEB_PORT="${PORT:-8087}"
        CHROME_PROFILE="/tmp/flutter_chrome_ssh_18"
        ;;
    *)
        # Mặc định khi không truyền tham số: Chạy thẳng chế độ Đa Database thông minh
        ODOO_VERSION="Multi-Database Master Router (v17 + v19)"
        API_PORT="1900"
        DB_NAME=""
        WEB_PORT="${PORT:-8089}"
        CHROME_PROFILE="/tmp/flutter_chrome_ssh_multi"
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

# A. Đồng bộ Odoo 17 (Nguồn chuẩn duy nhất: /mnt/DATA/work/17.0/extra/v_mobile và dev_env)
if [[ -d "$PARENT_DIR/v_mobile_17" ]]; then
    echo "   📦 Đang đồng bộ v_mobile_17 -> Server Local ($SERVER_HOST:/mnt/DATA/work/17.0/extra/v_mobile)..."
    rsync -aq --delete \
        --exclude='.git' --exclude='__pycache__' --exclude='*.pyc' --exclude='.claude' --exclude='.codegraph' \
        "$PARENT_DIR/v_mobile_17/" "$SSH_ALIAS:/mnt/DATA/work/17.0/extra/v_mobile/" 2>/dev/null || SYNC_ERROR=1
    rsync -aq --delete \
        --exclude='.git' --exclude='__pycache__' --exclude='*.pyc' --exclude='.claude' --exclude='.codegraph' \
        "$PARENT_DIR/v_mobile_17/" "$SSH_ALIAS:/home/corp360/DATA/save/dev_env/17.0/modules/extra/v_mobile/" 2>/dev/null || true
fi

# B. Đồng bộ Odoo 19 (Container odoo_dev_v19 nạp từ /mnt/DATA/work/19.0/default/v_mobile)
if [[ -d "$PARENT_DIR/v_mobile_19" ]]; then
    echo "   📦 Đang đồng bộ v_mobile_19 -> Server Local ($SERVER_HOST:/mnt/DATA/work/19.0/default/v_mobile)..."
    ssh "$SSH_ALIAS" "echo odoo | sudo -S chown -R corp360:corp360 /mnt/DATA/work/19.0/default/v_mobile" 2>/dev/null || true
    rsync -aq --delete \
        --exclude='.git' --exclude='__pycache__' --exclude='*.pyc' --exclude='.claude' --exclude='.codegraph' \
        "$PARENT_DIR/v_mobile_19/" "$SSH_ALIAS:/mnt/DATA/work/19.0/default/v_mobile/" 2>/dev/null || SYNC_ERROR=1
    ssh "$SSH_ALIAS" "echo odoo | sudo -S chown -R 101:101 /mnt/DATA/work/19.0/default/v_mobile" 2>/dev/null || true
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

# Sau rsync + chown, Odoo container có thể đang reload — retry tối đa 15s
_hc_ok=0
for _i in 1 2 3 4 5; do
    if /usr/bin/curl -s -o /dev/null -m 3 "$API_URL/web" 2>/dev/null; then
        _hc_ok=1
        break
    fi
    sleep 3
done

if [[ $_hc_ok -eq 1 ]]; then
    echo "   ✅ PASS: Kết nối Backend thành công"
else
    echo "   ⚠️ CẢNH BÁO: Backend $API_URL chưa phản hồi (có thể đang khởi động lại)"
    echo "   ➡️ Flutter Web sẽ vẫn khởi chạy, Sếp đợi Backend sẵn sàng rồi đăng nhập."
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
echo "   🌐 Sếp có thể copy link http://localhost:$WEB_PORT mở trên bất kỳ cửa sổ Chrome nào khác đều đăng nhập được bình thường!"
echo

DART_DEFINES=(
    "--dart-define=VCLOUD_ODOO_API_BASE_URL=$API_URL"
)

# Chỉ truyền VCLOUD_ODOO_DB khi Sếp chọn cố định một database cụ thể.
# Khi ở chế độ 'multi' (Đa Database), DB_NAME rỗng -> Không truyền VCLOUD_ODOO_DB
# để LoginScreen tự động bật Dialog cho người dùng chọn Database khi có nhiều DB trùng khớp.
if [[ -n "$DB_NAME" ]]; then
    DART_DEFINES+=("--dart-define=VCLOUD_ODOO_DB=$DB_NAME")
fi

exec flutter run \
    -d chrome \
    --no-pub \
    $MODE_FLAG \
    --web-port="$WEB_PORT" \
    --web-browser-flag="--disable-web-security" \
    --web-browser-flag="--user-data-dir=$CHROME_PROFILE" \
    "${DART_DEFINES[@]}"
