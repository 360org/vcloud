#!/usr/bin/env bash

# ==============================================================================
# ⚡ VCLOUD ODOO BACKEND QUICK UPDATE & RESTART (INTERACTIVE MENU)
# ==============================================================================
#
# Mục đích:
#   Hiển thị Menu tương tác để người dùng chọn nâng cấp Odoo 17, Odoo 19
#   hoặc nâng cấp đồng thời cả hai bản.
#
# Cách dùng:
#   bash update_backend.sh
#   ./update_backend.sh
#
# ==============================================================================

set -Eeuo pipefail

update_odoo() {
    local VERSION="$1"
    local CONTAINER="$2"
    local DB_NAME="$3"
    local MODULE_NAME="$4"
    local DEV_ENV_DIR="/media/tanma/DATA/save/dev_env/${VERSION}"

    echo
    echo "------------------------------------------------------------------------------"
    echo "🔄 Đang nâng cấp Odoo $VERSION (Container: $CONTAINER | DB: $DB_NAME)..."
    echo "------------------------------------------------------------------------------"

    # Kiểm tra và khởi động container nếu chưa chạy
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
        echo "   🐳 Container $CONTAINER chưa chạy. Đang khởi động stack..."
        (cd "$DEV_ENV_DIR" && ./prod up -d) >/dev/null 2>&1 || true
    fi

    # Restart container để nạp code Python mới
    echo "   🔄 [1/2] Restart container $CONTAINER nạp Python code mới..."
    (cd "$DEV_ENV_DIR" && ./prod restart odoo) >/dev/null 2>&1 || true

    # Nâng cấp module trong database
    echo "   ⚡ [2/2] Nâng cấp module $MODULE_NAME trong Database $DB_NAME..."
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
        upgraded = False
        for m in mod:
            if m.state == 'installed':
                m.button_immediate_upgrade()
                upgraded = True
                print(f'   ✅ Đã nâng cấp thành công module: {m.name}')
        if not upgraded:
            print('   ℹ️ Module v_mobile chưa được cài đặt trong DB này.')
except Exception as e:
    print(f'   ℹ️ Database $DB_NAME có thể chưa được khởi tạo hoặc chưa cài module ({e})')
" 2>/dev/null || true

    echo "   🎉 Hoàn tất nạp code cho Odoo $VERSION!"
}

# ------------------------------------------------------------------------------
# Kiểm tra tham số dòng lệnh nếu truyền trực tiếp
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
    echo "⚡ VCLOUD ODOO BACKEND QUICK UPDATE & RESTART"
    echo "=============================================================================="
    echo "📊 Trạng thái hiện tại trên máy:"
    echo "   • Odoo 17 (demo-17) : $STATUS_17"
    echo "   • Odoo 19 (demo-19) : $STATUS_19"
    echo "------------------------------------------------------------------------------"
    echo "👉 Vui lòng chọn phiên bản muốn nâng cấp:"
    echo "   [1] hoặc 17   ➔ Nâng cấp Odoo 17 (demo-17)"
    echo "   [2] hoặc 19   ➔ Nâng cấp Odoo 19 (demo-19)"
    echo "   [3] hoặc all  ➔ Nâng cấp CẢ HAI (Odoo 17 + Odoo 19)"
    echo "   [4] hoặc auto ➔ Tự động nhận diện bản đang chạy [Mặc định]"
    echo "   [0] hoặc q    ➔ Thoát"
    echo "------------------------------------------------------------------------------"
    read -r -p "Nhập lựa chọn của anh [Mặc định: 4]: " CHOICE
    CHOICE="${CHOICE:-4}"
else
    CHOICE="$INPUT_ARG"
fi

# ------------------------------------------------------------------------------
# Xử lý lựa chọn của người dùng
# ------------------------------------------------------------------------------
case "$CHOICE" in
    1|17|"17.0")
        echo ">> Anh đã chọn: Nâng cấp Odoo 17"
        update_odoo "17.0" "demo-17" "demo-17" "mobile_api"
        ;;
    2|19|"19.0")
        echo ">> Anh đã chọn: Nâng cấp Odoo 19"
        update_odoo "19.0" "demo-19" "demo-19" "v_mobile"
        ;;
    3|all|"ALL")
        echo ">> Anh đã chọn: Nâng cấp CẢ HAI (Odoo 17 + Odoo 19)"
        update_odoo "17.0" "demo-17" "demo-17" "mobile_api"
        update_odoo "19.0" "demo-19" "demo-19" "v_mobile"
        ;;
    4|auto|"AUTO"|"")
        IS_17_RUNNING=$(docker ps --format '{{.Names}}' | grep -q "^demo-17$" && echo "yes" || echo "no")
        IS_19_RUNNING=$(docker ps --format '{{.Names}}' | grep -q "^demo-19$" && echo "yes" || echo "no")

        if [[ "$IS_17_RUNNING" == "yes" && "$IS_19_RUNNING" == "yes" ]]; then
            echo "🔍 [Auto] Phát hiện CẢ 2 container (demo-17 và demo-19) đang chạy ➔ Tự động update CẢ HAI!"
            update_odoo "17.0" "demo-17" "demo-17" "mobile_api"
            update_odoo "19.0" "demo-19" "demo-19" "v_mobile"
        elif [[ "$IS_19_RUNNING" == "yes" ]]; then
            echo "🔍 [Auto] Phát hiện Odoo 19 (demo-19) đang chạy ➔ Tự động update Odoo 19!"
            update_odoo "19.0" "demo-19" "demo-19" "v_mobile"
        elif [[ "$IS_17_RUNNING" == "yes" ]]; then
            echo "🔍 [Auto] Phát hiện Odoo 17 (demo-17) đang chạy ➔ Tự động update Odoo 17!"
            update_odoo "17.0" "demo-17" "demo-17" "mobile_api"
        else
            echo "🔍 [Auto] Không có container nào đang chạy ➔ Mặc định nâng cấp Odoo 17!"
            update_odoo "17.0" "demo-17" "demo-17" "mobile_api"
        fi
        ;;
    0|q|Q|exit)
        echo "👋 Đã hủy thao tác. Thoát."
        exit 0
        ;;
    *)
        echo "❌ Lựa chọn '$CHOICE' không hợp lệ. Vui lòng chọn 17, 19 hoặc all."
        exit 1
        ;;
esac

echo
echo "=============================================================================="
echo "✨ Đã hoàn thành quá trình nâng cấp Backend Odoo!"
echo "=============================================================================="
