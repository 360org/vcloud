# CHANGELOG

## [2.9.12 - Build 144] - 2026-10-01

### 🚀 Bổ Sung & Nâng Cấp Hệ Thống
- **Danh Mục Tính Năng Toàn Diện**: Đã tổng hợp đầy đủ 78 tính năng hệ thống VCloud Mobile App & Odoo Backend tại `docs/FEATURES_CATALOG.md`.
- **API Backend Fixes**: Cập nhật các bản vá API Chat V2, WebRTC Signaling, Lazy UUID generation chống 404 và tối ưu query DB cho Odoo 17 & 19.

⚠️ **LƯU Ý QUAN TRỌNG KHI RE-AUDIT / DEPLOY**:
1. Đối với Odoo Backend (`v_mobile_17` & `v_mobile_19`): Bắt buộc chạy lệnh nâng cấp module **`vmobile`** trên Odoo Server (`odoo-bin -u vmobile`).
2. Tham chiếu chi tiết 78 tính năng tại: `docs/FEATURES_CATALOG.md`.
