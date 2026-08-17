#!/usr/bin/env bash
# 🚀 VCLOUD FLUTTER WEB LAUNCHER (AIaC 2026 Edition)
# Tự động giải phóng cổng 8088 và khởi chạy Flutter Web với phiên Chrome độc lập

set -e

PORT=8088
API_URL="https://vuahethong.net"
CHROME_PROFILE="/tmp/flutter_chrome_dev"

echo "🧹 [1/3] Đang dọn dẹp các tiến trình chiếm dụng cổng ${PORT}..."
fuser -k ${PORT}/tcp 2>/dev/null || true
sleep 1

echo "📦 [2/3] Nạp thư viện dependencies..."
flutter pub get

echo "🌐 [3/3] Khởi chạy Flutter Web trên Chrome (Port: ${PORT})..."
flutter run -d chrome \
  --web-port=${PORT} \
  --web-browser-flag="--disable-web-security" \
  --web-browser-flag="--user-data-dir=${CHROME_PROFILE}" \
  --dart-define=VCLOUD_ODOO_API_BASE_URL=${API_URL}
