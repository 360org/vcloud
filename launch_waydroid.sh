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
#   bash launch_waydroid.sh         -> Menu chọn Local (:8069) hoặc Production
#   bash launch_waydroid.sh local   -> Chạy kết nối Local Server (http://192.168.1.100:8069)
#   bash launch_waydroid.sh prod    -> Chạy kết nối Production (https://vuahethong.net)
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

# 2. Chọn Backend
BACKEND_ARG="${1:-}"
LOCAL_URL="http://192.168.1.100:8069"
PROD_URL="https://vuahethong.net"

if [[ "$BACKEND_ARG" == "local" || "$BACKEND_ARG" == "1" ]]; then
    API_URL="$LOCAL_URL"
    ENV_NAME="Local Server ($LOCAL_URL)"
elif [[ "$BACKEND_ARG" == "prod" || "$BACKEND_ARG" == "2" ]]; then
    API_URL="$PROD_URL"
    ENV_NAME="Production ($PROD_URL)"
else
    echo "------------------------------------------------------------------------------"
    echo "🎯 Chọn Backend kết nối:"
    echo "   [1] Local Server ($LOCAL_URL)"
    echo "   [2] Production   ($PROD_URL)"
    echo "------------------------------------------------------------------------------"
    read -rp "👉 Lựa chọn của Sếp [1/2] (Mặc định: 1): " choice
    choice="${choice:-1}"
    if [[ "$choice" == "2" || "$choice" == "prod" ]]; then
        API_URL="$PROD_URL"
        ENV_NAME="Production ($PROD_URL)"
    else
        API_URL="$LOCAL_URL"
        ENV_NAME="Local Server ($LOCAL_URL)"
    fi
fi

echo "=============================================================================="
echo "🎯 Đang khởi chạy ứng dụng lên Waydroid:"
echo "   • Thiết bị ADB : $DEVICE_ID"
echo "   • Backend      : $ENV_NAME"
echo "------------------------------------------------------------------------------"
echo "💡 HƯỚNG DẪN DEV SIÊU TỐC:"
echo "   - Sửa code trong VS Code / IDE ➔ Lưu file hoặc bấm 'r' để HOT RELOAD (1 giây)!"
echo "   - Bấm 'R' để HOT RESTART (2 giây)!"
echo "   - Bấm 'q' để dừng ứng dụng."
echo "=============================================================================="

flutter run -d "$DEVICE_ID" \
    --dart-define="VCLOUD_ODOO_API_BASE_URL=$API_URL"
