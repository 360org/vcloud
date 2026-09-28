#!/usr/bin/env bash
# ==============================================================================
# VCloud Mobile Automated Test & Quality Assurance Suite
# ==============================================================================
set -e

export PATH="$HOME/flutter/bin:$PATH"
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 0. Tự động kiểm tra độ mới mã nguồn & chống đè code trước khi chạy test
if [[ -f "$ROOT_DIR/scripts/check_code_freshness.sh" ]]; then
    bash "$ROOT_DIR/scripts/check_code_freshness.sh" vclients
fi

cd "$SCRIPT_DIR"

echo "================================================================================"
echo "🧪 [1/2] Đang chạy Static Analysis (flutter analyze)..."
echo "--------------------------------------------------------------------------------"
flutter analyze

echo ""
echo "================================================================================"
echo "🧪 [2/2] Đang chạy Automated Unit & Widget Tests (flutter test)..."
echo "--------------------------------------------------------------------------------"
flutter test

echo ""
echo "================================================================================"
echo "🎉 TẤT CẢ CÁC BÀI TEST TRÊN NHÁNH FLUTTER ĐÃ VƯỢT QUA 100% (ZERO ERRORS)!"
echo "================================================================================"
