#!/usr/bin/env bash

# ==============================================================================
# 🚀 VCLOUD FLUTTER ANDROID (WAYDROID) DEV LAUNCHER — HOT RELOAD 1 GIÂY
# ==============================================================================
#
# Mục đích:
#   Chạy Flutter trực tiếp lên giả lập Waydroid qua ADB kết nối sẵn.
#   KHÔNG CẦN CHỜ BUILD APK!
#   Hỗ trợ:
#     - Bấm 'r' ➔ Hot Reload tức thì (1 giây)!
#     - Bấm 'R' ➔ Hot Restart (2 giây)!
#     - Bấm 'q' ➔ Thoát phiên chạy!
#
# Cách dùng:
#   bash launch_waydroid.sh            -> (MẶC ĐỊNH) Odoo 19 (:1900, DB: vcloud_test_v19)
#   bash launch_waydroid.sh 19         -> Odoo 19 Local Server (:1900, vcloud_test_v19)
#   bash launch_waydroid.sh 17         -> Odoo 17 Local Server (:8069, demo-17)
#   bash launch_waydroid.sh prod       -> Production (https://vuahethong.net)
#
# ==============================================================================

set -Eeuo pipefail

export PATH="$HOME/flutter/bin:$PATH:/usr/local/bin"

ADB_BIN="/media/tanma/DATA/Android_SDK/Android/Sdk/platform-tools/adb"
[ ! -x "$ADB_BIN" ] && ADB_BIN="adb"

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
cd "$SCRIPT_DIR"

echo "=============================================================================="
echo "🚀 VCLOUD FLUTTER — WAYDROID DEV LAUNCHER (HOT RELOAD MODE)"
echo "=============================================================================="

# 0. Dọn dẹp tiến trình Flutter cũ mồ côi nếu có để tránh lag máy và giải phóng RAM
echo "🧹 Kiểm tra & giải phóng RAM từ các phiên Flutter cũ..."
pkill -f "frontend_server" 2>/dev/null || true
sleep 0.5

# 1. Kiểm tra thiết bị Waydroid qua ADB
find_device() {
    "$ADB_BIN" devices 2>/dev/null | grep -E "(192\.168\.|device$)" | grep -v "List of" | awk '{print $1}' | head -n 1 || true
}

DEVICE_ID=$(find_device)

if [[ -z "$DEVICE_ID" ]]; then
    echo "⚠️ Chưa tìm thấy thiết bị ADB Android. Đang kích hoạt kết nối Waydroid..."
    if [ -x "/media/tanma/DATA/auto_tool_android/start_waydroid_all_in_one.sh" ]; then
        /media/tanma/DATA/auto_tool_android/start_waydroid_all_in_one.sh
    fi
    sleep 2
    DEVICE_ID=$(find_device)
fi

if [[ -z "$DEVICE_ID" ]]; then
    echo "❌ Không thể phát hiện thiết bị Waydroid qua ADB!"
    echo "👉 Vui lòng mở tool Android Auto Tool và bấm 'Bật Giả Lập Android' trước."
    exit 1
fi

echo "✅ Đã nhận diện thiết bị ADB: $DEVICE_ID"

# 2. Cấu hình Backend: MẶC ĐỊNH ƯU TIÊN ODOO 19 (vcloud_test_v19 :1900)
BACKEND_ARG="${1:-}"
ODOO19_URL="http://192.168.1.100:1900"
ODOO19_DB="vcloud_test_v19"

ODOO17_URL="http://192.168.1.100:8069"
ODOO17_DB="demo-17"

PROD_URL="https://vuahethong.net"
PROD_DB="vuahethong"

case "$BACKEND_ARG" in
    17|"17.0"|"demo-17")
        API_URL="$ODOO17_URL"
        DB_NAME="$ODOO17_DB"
        ENV_NAME="Odoo 17 Local Server ($ODOO17_URL - DB: $ODOO17_DB)"
        ;;
    prod|"2"|"production")
        API_URL="$PROD_URL"
        DB_NAME="$PROD_DB"
        ENV_NAME="Production ($PROD_URL)"
        ;;
    19|"19.0"|"local"|"1"|vcloud|"vcloud_test_v19"|*)
        # MẶC ĐỊNH TUYỆT ĐỐI: Odoo 19 Local Server
        API_URL="$ODOO19_URL"
        DB_NAME="$ODOO19_DB"
        ENV_NAME="Odoo 19 Local Server Ưu Tiên ($ODOO19_URL - DB: $ODOO19_DB)"
        ;;
esac

echo "=============================================================================="
echo "🎯 Đang khởi chạy ứng dụng lên Waydroid:"
echo "   • Thiết bị ADB : $DEVICE_ID"
echo "   • Backend API  : $API_URL"
echo "   • Database Target: $DB_NAME"
echo "   • Môi trường   : $ENV_NAME"
echo "------------------------------------------------------------------------------"
echo "💡 HƯỚNG DẪN DEV SIÊU TỐC:"
echo "   - Sửa code trong VS Code / IDE ➔ Lưu file hoặc bấm 'r' để HOT RELOAD (1 giây)!"
echo "   - Bấm 'R' để HOT RESTART (2 giây)!"
echo "   - Bấm 'q' để dừng ứng dụng."
echo "=============================================================================="

flutter run -d "$DEVICE_ID" \
    --dart-define="VCLOUD_ODOO_API_BASE_URL=$API_URL" \
    --dart-define="VCLOUD_ODOO_DB=$DB_NAME"
