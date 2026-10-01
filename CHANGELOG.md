# CHANGELOG

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
