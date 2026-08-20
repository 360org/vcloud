#!/usr/bin/env bash

# ==============================================================================
# 🚀 VCLOUD FLUTTER WEB QA LAUNCHER
# ==============================================================================
#
# Mục đích:
#   Chạy Flutter Web local và kết nối trực tiếp Production Backend.
#
# Backend:
#   https://vuahethong.net
#
# Frontend:
#   vclients
#
# Port mặc định:
#   8088
#
# LƯU Ý:
#   - Đây là launcher dành cho DEV/QA.
#   - Chrome sử dụng --disable-web-security để test localhost → production API.
#   - KHÔNG dùng browser session này cho hoạt động web thông thường.
#   - KHÔNG tự động git pull để tránh thay đổi source ngoài ý muốn.
#
# ==============================================================================

set -Eeuo pipefail

export PATH="$PATH:$HOME/flutter/bin:/usr/local/bin"

# ------------------------------------------------------------------------------
# 0. Resolve project directory
# ------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

PORT="${PORT:-8088}"
API_URL="${API_URL:-https://vuahethong.net}"

CHROME_PROFILE="${CHROME_PROFILE:-/tmp/flutter_chrome_prod}"

# ------------------------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------------------------

cleanup_port() {
    echo "🧹 Giải phóng port ${PORT} và dọn dẹp tiến trình Flutter Web cũ..."

    if command -v fuser >/dev/null 2>&1; then
        fuser -k -9 "${PORT}/tcp" 2>/dev/null || true
    fi

    if command -v lsof >/dev/null 2>&1; then
        lsof -ti "tcp:${PORT}" 2>/dev/null \
            | xargs -r kill -9 2>/dev/null || true
    fi

    # Giải phóng các tiến trình frontend_server / chrome runner mồ côi nếu có
    pkill -f "flutter_tools.*--web-port=${PORT}" 2>/dev/null || true
}

ensure_dependencies() {
    if [[ ! -d ".dart_tool" ]]; then
        echo "📦 Chưa có .dart_tool → chạy flutter pub get..."
        flutter pub get
        return
    fi

    echo "✅ Flutter dependencies đã tồn tại."
}

CLEAN_PROFILE=false
for arg in "$@"; do
    if [[ "$arg" == "--clean" ]] || [[ "$arg" == "-c" ]]; then
        CLEAN_PROFILE=true
    fi
done

prepare_chrome_profile() {
    if [[ "$CLEAN_PROFILE" == "true" ]]; then
        echo "🧹 Đang dọn sạch toàn bộ cache trình duyệt và session cũ ($CHROME_PROFILE)..."
        rm -rf "$CHROME_PROFILE" 2>/dev/null || true
    fi

    mkdir -p "$CHROME_PROFILE"

    # Xóa stale lock và socket files để tránh compiler crash / port collision
    rm -f \
        "${CHROME_PROFILE}/SingletonLock" \
        "${CHROME_PROFILE}/SingletonSocket" \
        "${CHROME_PROFILE}/SingletonCookie" \
        "${CHROME_PROFILE}/DevToolsActivePort" \
        2>/dev/null || true
}

# ------------------------------------------------------------------------------
# Header
# ------------------------------------------------------------------------------

echo
echo "=============================================================================="
echo "🚀 VCLOUD FLUTTER WEB — QA / PRODUCTION BACKEND"
echo "=============================================================================="
echo "📂 Frontend : $SCRIPT_DIR"
echo "🌐 Backend  : $API_URL"
echo "🔌 Port     : $PORT"
echo "🌐 Browser  : Chrome"
echo "=============================================================================="
echo

# ------------------------------------------------------------------------------
# 1. Verify Flutter
# ------------------------------------------------------------------------------

if ! command -v flutter >/dev/null 2>&1; then
    echo "❌ Không tìm thấy Flutter trong PATH ($PATH)."
    exit 1
fi

FLUTTER_RAW_VER="$(flutter --version 2>&1 || true)"
FLUTTER_VER_FIRST_LINE="$(echo "$FLUTTER_RAW_VER" | head -n 1)"
echo "✅ Flutter: $FLUTTER_VER_FIRST_LINE"

# ------------------------------------------------------------------------------
# 2. Clean port
# ------------------------------------------------------------------------------

cleanup_port

# ------------------------------------------------------------------------------
# 3. Dependencies
# ------------------------------------------------------------------------------

ensure_dependencies

# ------------------------------------------------------------------------------
# 4. Chrome profile
# ------------------------------------------------------------------------------

prepare_chrome_profile

# ------------------------------------------------------------------------------
# 5. Launch
# ------------------------------------------------------------------------------

echo
echo "=============================================================================="
echo "🌐 STARTING FLUTTER WEB"
echo "=============================================================================="
echo
echo "Backend : $API_URL"
echo "Port    : $PORT"
echo
echo "Hotkeys:"
echo "  r → Hot Reload"
echo "  R → Hot Restart"
echo "  h → Help"
echo "  q → Quit"
echo
echo "⚠️  Chrome Web Security đang DISABLED cho session này."
echo "⚠️  Chỉ sử dụng Chrome session này để DEV/QA."
echo
echo "=============================================================================="
echo

MODE_FLAG=""
for arg in "$@"; do
    if [[ "$arg" == "--release" ]] || [[ "$arg" == "--profile" ]]; then
        MODE_FLAG="$arg"
    fi
done

if [[ -n "$MODE_FLAG" ]]; then
    echo "⚡ Chế độ chạy: $MODE_FLAG (AOT Optimized - Siêu mượt 60-120fps)"
else
    echo "🐞 Chế độ chạy: Debug JIT (Mặc định cho Dev). Dùng './launch_web_prod.sh --release' để chạy tốc độ tối đa."
fi

exec flutter run \
    -d chrome \
    $MODE_FLAG \
    --web-port="$PORT" \
    --web-browser-flag="--disable-web-security" \
    --web-browser-flag="--user-data-dir=$CHROME_PROFILE" \
    --dart-define="VCLOUD_ODOO_API_BASE_URL=$API_URL"
