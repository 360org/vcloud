#!/usr/bin/env bash
# ==============================================================================
# 🚀 VCLOUD FLUTTER WEB LAUNCHER (AIaC 2026 Edition)
# ==============================================================================
# 📖 HƯỚNG DẪN KHỞI CHẠY (USAGE GUIDE):
#
# Cách 1: Chạy từ thư mục gốc dự án (/media/tanma/DATA/save/mobile)
#   $ bash vclients/launch_web.sh
#   HOẶC (sau khi chmod +x):
#   $ ./vclients/launch_web.sh
#
# Cách 2: Chuyển thư mục vào vclients rồi chạy
#   $ cd /media/tanma/DATA/save/mobile/vclients
#   $ bash launch_web.sh
#   HOẶC:
#   $ ./launch_web.sh
#
# 💡 LƯU Ý:
#   - Không gõ trơn `launch_web.sh` (sẽ bị lỗi command not found vì không có trong PATH).
#   - Luôn thêm tiền tố `bash launch_web.sh` hoặc `./launch_web.sh`.
#   - Để cấp quyền chạy trực tiếp: chmod +x /media/tanma/DATA/save/mobile/vclients/launch_web.sh
# ==============================================================================

set -e

# Tự động chuyển vào đúng thư mục chứa script (vclients)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PORT=${PORT:-8088}
API_URL="https://vuahethong.net"
CHROME_PROFILE="/tmp/flutter_chrome_dev"

echo "=============================================================================="
echo "🚀 KHỞI CHẠY VCLOUD FLUTTER WEB"
echo "📂 Thư mục làm việc: $SCRIPT_DIR"
echo "🌐 Kết nối Backend: $API_URL"
echo "🔌 Cổng Web (Port): $PORT"
echo "=============================================================================="

# 1. Dọn dẹp cổng và các tiến trình chiếm dụng
echo "🧹 [1/3] Đang kiểm tra và giải phóng cổng ${PORT}..."
if command -v fuser >/dev/null 2>&1; then
  fuser -k -9 ${PORT}/tcp 2>/dev/null || true
fi
if command -v lsof >/dev/null 2>&1; then
  lsof -ti tcp:${PORT} | xargs -r kill -9 2>/dev/null || true
fi

# Xóa các file lock của Chrome profile cũ để tránh lỗi kẹt phiên
rm -f "${CHROME_PROFILE}/SingletonLock" "${CHROME_PROFILE}/SingletonSocket" "${CHROME_PROFILE}/SingletonCookie" 2>/dev/null || true
sleep 1

# 2. Cập nhật mã nguồn mới nhất & nạp thư viện dependencies
echo "🔄 [2/3] Đồng bộ mã nguồn mới nhất (git pull & pub get)..."
git pull --ff-only 2>/dev/null || git pull || true
flutter pub get

# 3. Hướng dẫn phím tắt tương tác & Khởi chạy Flutter Web
echo "=============================================================================="
echo "🌐 [3/3] Đang khởi chạy Flutter Web trên Chrome (Port: ${PORT})..."
echo "=============================================================================="
echo "💡 HƯỚNG DẪN THAO TÁC KHI CODE ĐANG CHẠY:"
echo "   👉 Nhấn 'r' : Hot Reload  (Nạp nhanh UI khi sửa Widget/Layout)"
echo "   👉 Nhấn 'R' : Hot Restart (Khởi động lại State khi sửa Logic/Provider/Service)"
echo "   👉 Nhấn 'h' : Hiển thị bảng trợ giúp phím tắt"
echo "   👉 Nhấn 'q' : Thoát ứng dụng"
echo "=============================================================================="

flutter run -d chrome \
  --web-port=${PORT} \
  --web-browser-flag="--disable-web-security" \
  --web-browser-flag="--user-data-dir=${CHROME_PROFILE}" \
  --dart-define=VCLOUD_ODOO_API_BASE_URL=${API_URL}
