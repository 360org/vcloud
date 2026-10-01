# CHANGELOG

## [2.9.12 - Build 146] - 2026-10-01

### 🎨 Tối Ưu Theme & Độ Tương Phản Màn Hình "Hồ Sơ Cá Nhân" (Edit Profile Screen)
- **Làm Nổi Bật Tiêu Đề Trường Thông Tin**: Thêm thanh chỉ báo màu xanh thương hiệu (`AppColors.primary`) và nâng cấp màu chữ tiêu đề ("Họ và tên", "Chức vụ", "Công ty", "Email") lên màu trắng sáng `Color(0xFFF1F5F9)` kèm font weight `FontWeight.w700` trong Dark Mode, chống hiện tượng tiêu đề bị chìm vào nền card tối.
- **Sửa Lỗi Nền Khung Giá Trị Bị Biến Thành Màu Trắng**: Sửa container hiển thị giá trị trường thông tin từ màu trắng cố định (`AppColors.bg`) sang màu nền tối `Color(0xFF0F172A)` với đường viền tinh tế `Color(0xFF334155)` khi ở Dark Mode. Chữ giá trị chuyển sang màu trắng sắc nét.
- **Chuẩn Hóa Giao Diện Đổi Avatar & AppBar**:
  - `_showAvatarPickerSheet`: BottomSheet hiển thị nền tối `Color(0xFF1E293B)` và chữ màu sáng `Color(0xFFF1F5F9)` trong Dark Mode.
  - `AppScaffold`: AppBar tự động nhận biết Dark Mode, sử dụng nền phẳng tối `Color(0xFF1E293B)` với đường viền tóc 1px thay vì dải gradient xanh neon chói mắt.
- **Kiểm Thử Toàn Diện**: Mở rộng `test/features/profile/profile_edit_test.dart` lên 11 test cases độc lập (tất cả pass 100%).

## [2.9.12 - Build 145] - 2026-10-01

### 🐛 Sửa Lỗi Tiêu Đề Kênh Nhóm "Internal" Bị Biến Thành "Chau, Le Ba (Internal)" Trên iPhone (TestFlight)
- **Root Cause**: Khi người dùng nhận Push Notification Odoo định dạng `{author_name} ({channel.name})`, tiêu đề `"Chau, Le Ba (Internal)"` bị router nạp vào query param `name`, `ChatV2DetailScreen` ghi đè thành kênh chat 1-1 giả lập vào `_pinnedDirectChannels` của `FlutterSecureStorage`. Khi API trả về đúng `"Internal"`, hàm `ChatV2ChannelLocalCache.set()` ưu tiên lấy tên trong pinned direct cache đè lên tên từ API.
- **Bản Vá & Bảo Vệ**:
  - Nâng cấp `ChatV2Channel.cleanChannelName()` & `getCleanName()`: Thêm Master Regex phát hiện và bóc tách chuẩn xác định dạng `{author_name} ({channel.name})` về `"Internal"` cho kênh nhóm.
  - Sửa `ChatV2ChannelLocalCache.set()`: Với kênh nhóm, tên từ API Odoo luôn là SSOT tuyệt đối 100%, đồng thời tự động phát hiện và xóa kênh nhóm khỏi `_pinnedDirectChannels` trong bộ nhớ và disk storage.
  - Sửa `ChatV2ChannelLocalCache.init()`: Tự động thanh lọc các bản ghi rác trong `pinned_direct_channels_v2` và làm sạch tên kênh lưu trong `cached_channels_v3`.
  - Cập nhật `pinDirectChannel()` & `ChatV2DetailScreen`: Tuyệt đối không lưu Group Channel hoặc kênh `Internal` vào `_pinnedDirectChannels`.
  - Bổ sung 7 test case đặc trị trong `test/features/chat_v2/chat_v2_channel_sanitize_test.dart` (pass 20/20 test).

## [2.9.12 - Build 144] - 2026-10-01

### 🚀 Bổ Sung & Nâng Cấp Hệ Thống
- **Danh Mục Tính Năng Toàn Diện**: Đã tổng hợp đầy đủ 78 tính năng hệ thống VCloud Mobile App & Odoo Backend tại `docs/FEATURES_CATALOG.md`.
- **API Backend Fixes**: Cập nhật các bản vá API Chat V2, WebRTC Signaling, Lazy UUID generation chống 404 và tối ưu query DB cho Odoo 17 & 19.

⚠️ **LƯU Ý QUAN TRỌNG KHI RE-AUDIT / DEPLOY**:
1. Đối với Odoo Backend (`v_mobile_17` & `v_mobile_19`): Bắt buộc chạy lệnh nâng cấp module **`vmobile`** trên Odoo Server (`odoo-bin -u vmobile`).
2. Tham chiếu chi tiết 78 tính năng tại: `docs/FEATURES_CATALOG.md`.
