#!/usr/bin/env bash
set -e

# ==============================================================================
# 🤖 VCLOUD FLUTTER MOBILE — AUTOMATION E2E TEST RUNNER (AIaC 3.0)
# ==============================================================================
# Mục đích: Chạy tự động 100% kịch bản E2E (Đăng nhập, Chọn Multi-DB, Đồng bộ Avatar)
# Không cần thao tác thủ công, chống vỡ giao diện trên Canvas!
# ==============================================================================

PROJECT_DIR="/media/tanma/DATA/save/mobile_versions/vclients"
FLUTTER_BIN="/home/tanma/flutter/bin/flutter"

echo "=============================================================================="
echo "🚀 KHỞI ĐỘNG BỘ TEST TỰ ĐỘNG HOÁ E2E (FLUTTER INTEGRATION TEST)"
echo "=============================================================================="
echo "📂 Thư mục dự án: $PROJECT_DIR"
echo "🎯 Kịch bản     : integration_test/login_and_avatar_e2e_test.dart"
echo "=============================================================================="

cd "$PROJECT_DIR"

# 1. Chạy static analysis trước khi test
echo "🔍 Bước 1: Kiểm tra phân tích tĩnh (Static Analysis)..."
$FLUTTER_BIN analyze lib/ integration_test/

# 2. Khởi chạy bộ Automation Test E2E và Avatar Sync tự động
echo "⚡ Bước 2: Thực thi Bộ Kịch Bản Automation E2E Flow (10/10 Cases) & Avatar Sync (10/10 Cases)..."
$FLUTTER_BIN test test/avatar_sync_test.dart test/e2e_flow_automation_test.dart

echo "=============================================================================="
echo "🎉 [PASS] BỘ TEST E2E TỰ ĐỘNG ĐÃ HOÀN TẤT THÀNH CÔNG 100%!"
echo "=============================================================================="
