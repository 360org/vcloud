# Project Guidelines (FLUTTER)

> File do AIaC tạo. Quy tắc global được kế thừa từ Global CLAUDE.md.

## Quy tắc cục bộ
- Kế thừa Global CLAUDE.md; không lặp hoặc ghi đè các rule global.
- Chỉ sửa cấu hình `.claude/` do AIaC tạo; giữ nguyên file cục bộ có sẵn.
- Tránh bang operator (`!`); kiểm tra `context.mounted` sau `await`.
- Chạy `flutter analyze` trước khi xác nhận.
- 🛑 **Ranh giới quyền hạn Production (`vuahethong.net`)**: Sếp Tân có Web Admin (`Settings -> Technical`, `ir.cron`, `ir.model.access`) & DB Manager (`/web/database/manager`), KHÔNG có SSH / `kubectl` Production. TUYỆT ĐỐI KHÔNG yêu cầu Sếp chạy `ssh`, `kubectl`, `systemctl`, `psql` trên Production. Lỗi hạ tầng/backend K8s -> hướng dẫn lấy log qua F12/Web Admin và soạn Diagnostic Summary để Sếp gửi đội DevOps. (Chi tiết: `docs/QUYEN_HAN_VUAHETHONG.md`).
