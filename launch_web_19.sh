#!/usr/bin/env bash

# ==============================================================================
# 🚀 SHORTCUT LAUNCHER — ODOO 19
# ==============================================================================
# Gọi trực tiếp launch_web.sh với chế độ Odoo 19

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/launch_web.sh" 19 "$@"
