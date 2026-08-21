## [2.4.0+76] - 2026-08-18
### Added
- **Tính Năng Tạo Bình Chọn Trong Chat V2 & Lưu Trữ Vĩnh Viễn Trên Odoo (Chat Poll / Voting System)**:
  - Cho phép tạo cuộc bình chọn trực tiếp từ thanh đính kèm (`+` ➔ `Bình chọn`) với câu hỏi và từ 2 đến 10 phương án lựa chọn linh hoạt (`ChatV2CreatePollSheet`).
  - Hỗ trợ chế độ bình chọn đơn (Single Choice) hoặc bình chọn nhiều phương án (Multiple Choice).
  - Hiển thị thẻ bình chọn sống động chuẩn Zalo / Telegram trong luồng tin nhắn (`ChatV2PollCard`): thanh tiến trình % chạy mượt mà, đếm số phiếu, hiển thị danh sách người đã bầu, trạng thái tick chọn trực quan.
  - Lưu trữ dữ liệu vĩnh viễn trên Odoo Backend (`POST /api/v1/mobile/chat/messages/<id>/poll/vote`): lưu toàn bộ lịch sử và trạng thái đã bình chọn vào `mail.message` trong cơ sở dữ liệu PostgreSQL.
- **Hệ Thống Thông Báo Nổi Đa Tầng (`AppToast`)**:
  - Xây dựng component `AppToast` dạng thẻ nổi bo cong 20px, đổ bóng phát sáng đa tầng, không dính đáy và không đè lên thanh điều hướng (Bottom Navigation Bar / FAB).
  - 4 biến thể chuẩn hóa: `AppToast.success`, `AppToast.error`, `AppToast.warning`, `AppToast.info`.
- **Kiểm Soát Dung Lượng Tệp Tải Lên (25MB File Size Limit Guard)**:
  - Khóa trần dung lượng tệp tối đa 25MB ở cả Frontend (`MobileAttachmentRepository` & `CreateTicketScreen`) và Backend (`attachments.py` - HTTP 413).
- **Làm Mới Danh Sách Ticket (Pull-to-Refresh & Newest-first ID Sorting)**:
  - Tích hợp `RefreshIndicator` và sắp xếp ticket theo ID giảm dần (`id desc`) ở màn hình danh sách Ticket.
- **Unit Tests**:
  - Bổ sung bộ kiểm thử tự động toàn diện cho Poll parsing (`test/chat_v2_poll_test.dart`) và Avatar resolution (`test/chat_v2_avatar_resolution_test.dart`) (100% tests passed).

### Changed
- **Tối Ưu & Đồng Bộ Giao Diện Màn Hình Tạo Ticket (`CreateTicketScreen`)**:
  - Loại bỏ hoàn toàn khối thẻ màu cam thừa (`_TicketSummary`), giải phóng hơn 100px không gian dọc giúp form vào thẳng các trường nhập liệu chính.
  - Thiết kế lại thanh tiêu đề `_CreateTicketHeader` với nút Quay lại bo góc 16px và huy hiệu "Tạo ticket" đồng bộ 100% với toàn hệ thống.
  - Đồng bộ nút bấm hành động chính "Gửi ticket" sang dải màu xanh ngọc thương hiệu (`AppColors.brand`).
- **Cải Tiến Trải Nghiệm Màn Hình Đăng Nhập (`LoginScreen`)**:
  - Tự động hạ bàn phím ảo (`FocusScope.unfocus()`) khi nhấn "Đăng nhập".
  - Tự động bắt lỗi khi nhập thiếu thông tin hoặc sai tài khoản/mật khẩu (`invalid_credentials`), kích hoạt hiệu ứng rung thẻ (shake animation), viền đỏ cảnh báo trên ô nhập liệu và hiển thị thẻ lỗi nội tuyến (Inline Error Banner) kèm thông báo nổi `AppToast.error`.
- **Tái Thiết Kế Phân Luồng Task Timesheet Chuẩn UI/UX (Segmented Filter Tabs)**:
  - Xây dựng thanh chuyển đổi Segmented Tabs thông minh gồm `[ 📝 Cần làm (N) ]` và `[ ✅ Đã hoàn thành (N) ]` ngay trên đầu danh sách, hỗ trợ chuyển đổi 1-chạm (Zero Scrolling).
  - Giới hạn hiển thị ban đầu 10 task kèm nút "Xem thêm" và "Thu gọn" thông minh.

### Fixed
- **Sửa Lỗi Khung Tin Nhắn Chat Bị Dài Vô Tận Với Chữ Ngắn**:
  - Xây dựng cấu trúc `Wrap` thông minh giúp bong bóng tin nhắn ôm sát theo độ dài thực tế của chữ (Bubble Shrink-wrap), căn lề chữ bên trái chuẩn UI/UX, hiển thị thời gian và trạng thái đã gửi/đã nhận tinh tế (chuẩn Zalo/Telegram).
- **Sửa Lỗi Dòng Xem Trước Ngoài Danh Sách Chat (Preview Formatting)**:
  - Chuẩn hóa tin nhắn bình chọn ngoài danh sách hội thoại hiển thị thành `📊 [Bình chọn] <Câu hỏi>` thay vì in chuỗi JSON thô.
  - Nhận diện đúng `[Hình ảnh]` ngoài danh sách chat khi tin nhắn mới nhất là tệp ảnh thuần không có chú thích.
- **Sửa Lỗi Hiển Thị Ảnh Gửi Từ iPhone 13 (iOS `image_picker_`)**:
  - Bổ sung nhận diện tiền tố `image_picker_...`, `.heic`, `.heif`, `.bmp` trong `ChatV2Message.fromMap` để không bị gán nhầm sang thẻ tệp tin thô (`application/octet-stream`).
  - Tự động khởi tạo luồng tải ảnh qua mạng (`ChatV2AttachmentImage`) khi thiết bị nhận chưa có sẵn dữ liệu trong Local Cache, hiển thị khung ảnh thumbnail trực tiếp thay vì thẻ tệp màu xanh.
- **Sửa Lỗi Tràn Màn Hình Lịch Sử Điểm Danh (`AttendanceHistoryScreen`)**:
  - Khắc phục lỗi `BOTTOM OVERFLOWED BY 4.0 PIXELS` trên lưới lịch bằng cách điều chỉnh `childAspectRatio` từ 0.85 sang 0.72 và bọc `FittedBox` tự co giãn nhãn ngày.
- **Sửa Lỗi Tự Động Giật Cuộn Màn Hình Chi Tiết Ticket (`TicketDetailScreen`)**:
  - Ngăn chặn hàm `_scrollToComments()` kích hoạt ngoài ý muốn trong quá trình nạp dữ liệu ban đầu.
- **Chuyển Cảnh Mượt Mà Giữa Các Màn Hình**:
  - Tối ưu hiệu ứng chuyển cảnh `GoRoute` cho `/tickets/:id` và `/tickets/new` sang hiệu ứng trượt ngang tự nhiên (`SlideTransition`) kết hợp mờ dần (`FadeTransition`).
- **Sửa Lỗi Thiếu Avatar Admin (ID 2) và OdooBot (ID 1)**:
  - Chuẩn hóa URL ảnh đại diện tương đối `/web/image` và xây dựng kiến trúc fallback 3 tầng đảm bảo luôn hiển thị avatar hoặc chữ cái đại diện sắc nét.
- **Sửa Lỗi Tràn Viền Thẻ Lịch Làm Việc iPhone 13 (`AttendanceScreen`)**:
  - Tối ưu bố cục thẻ lịch làm việc ("Thứ ba - Thứ sáu") không bị tràn chữ trên màn hình nhỏ.

---

## [2.4.0+28] - 2026-08-03
### Added
- Success SnackBar notifications and automatic `context.pop()` navigation after ticket status updates.

### Fixed
- Fixed RenderFlex 3.9px overflow in `_TicketActionBar` by adding `maxLines: 1` and `TextOverflow.ellipsis`.
- Safe parsing for system messages and `author_id == false` in `TicketComment.fromMap`.
- Fixed `isDone` status mapping in `_ticketFromOdoo` using `close_date` and `stage_id`.
