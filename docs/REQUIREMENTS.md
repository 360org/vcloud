# REQUIREMENTS.md - VCloud Mobile Requirements

## Functional Requirements
- Đăng nhập qua Odoo Mobile API Gateway và lưu tenant session an toàn trên thiết bị.
- Chat nội bộ hỗ trợ danh sách kênh, tin nhắn, file/ảnh, ghim, đánh dấu đã đọc, nhóm mới và tìm kiếm người dùng.
- Chấm công hỗ trợ trạng thái hôm nay, check-in/check-out, lịch sử và cấu hình ca làm việc từ backend.
- Timesheet hỗ trợ danh sách log gần đây, project/task lookup, ghi giờ và danh sách công việc hôm nay.
- Ticket hỗ trợ danh sách, chi tiết, tạo ticket, bình luận, đính kèm, đội xử lý và thông tin liên hệ.
- Dashboard hiển thị tổng quan công việc, ticket, timesheet, chấm công và badge chat.
- Push notification đăng ký/hủy FCM token sau login/logout khi cấu hình Firebase có đủ.

## Non-Functional Requirements
- Presentation không gọi HTTP/API trực tiếp; mọi backend call đi qua repository trong `lib/features/*/data` hoặc `lib/core/api`.
- Không hard-code secret, host cá nhân, token, password, certificate, private key hoặc local machine path.
- `flutter analyze` phải đạt 0 errors / 0 warnings trước khi báo sẵn sàng commit.
- Mobile release dùng version trong `pubspec.yaml` và tag chuẩn `vX.Y.Z+BUILD`.
- GitHub `360org/vcloud` là build mirror sạch: chỉ giữ `main`, không push branch dev, không chứa handoff nội bộ.
- VCloud chỉ release mobile artifacts; deploy Odoo/server thuộc repo `v_mobile` và cần yêu cầu rõ.

## Acceptance Criteria
- API contract liên quan được cập nhật trong `docs/SPEC.md`.
- Kiến trúc/luồng dữ liệu liên quan được cập nhật trong `docs/ARCH.md`.
- Thay đổi release/build được ghi trong `docs/CHANGELOGS.md` và `docs/AUDIT_REPORT.md` khi phát hành.
- Build release qua GitHub Actions chạy từ tag `v*`, không từ branch dev.
