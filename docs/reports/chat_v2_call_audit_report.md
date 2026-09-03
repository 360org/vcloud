# BÁO CÁO ZERO-TRUST AUDIT: Chat V2 Voice Call

**1. Kết quả chẩn đoán Thực tế (Live Architecture):**
- Tính năng Call (Gọi thoại) trên Flutter hiện tại **CHỈ LÀ MỘT BỘ XƯƠNG GIAO DIỆN (UI MOCKUP)**. 
- Không tồn tại module nào đảm nhiệm việc thu âm, truyền tải, hay phát âm thanh 2 chiều (Voice Streaming).

**2. Điểm mù Tính năng (Feature Bottlenecks):**
- 🔴 **Lỗi không nghe thấy nhau:** Project CHƯA CÀI ĐẶT bất kỳ thư viện WebRTC hay VoIP nào (`flutter_webrtc`, `agora_rtc_engine`, v.v.). App chỉ gọi API tạo bản ghi "đã gọi" lên Odoo DB, sau đó đếm giây màn hình, hoàn toàn KHÔNG truyền âm thanh.
- 🔴 **Lỗi Mute / Loa ngoài (để cho có):** Hàm `toggleMute()` và `toggleSpeaker()` chỉ đảo ngược một biến boolean để đổi icon (UI), không kết nối với bất kỳ Audio/Micro engine nào dưới hệ thống Android/iOS.
- 🔴 **Lỗi không chuông:** Hàm `_playRingtone()` trong `chat_v2_call_controller.dart` được khởi tạo bằng `AudioPlayer()` nhưng **KHÔNG CÓ source file audio (`.play(AssetSource('...'))`)**, nên dù app mở cũng bị tịt ngòi (không kêu).

**3. Rủi ro Vòng đời (Background/Lifecycle Risks):**
- 🔴 **Lỗi app ẩn/tắt không nhận được cuộc gọi:** Để nhận cuộc gọi khi app tắt/ẩn trên iOS/Android, bắt buộc phải dùng Apple CallKit (iOS) và ConnectionService (Android) thông qua thư viện (như `flutter_callkit_incoming`), kết hợp với FCM Data Message. Hiện tại app chỉ có `FirebaseMessaging` báo Push Notification thường (text). Khi có người gọi, Firebase chỉ gõ cửa hiện popup text, không thể kích hoạt màn hình Incoming Call toàn màn hình.

**4. Kế hoạch vá lỗi & Nâng cấp (Action Plan):**
Đây không phải là "sửa lỗi code", mà là **Xây dựng Epic Voice Call từ con số 0**. Cần thực hiện 2 Phase lớn:
- **Phase 1 (Giao thức Âm thanh - WebRTC):** 
  - Tích hợp `flutter_webrtc`.
  - Cấu hình SDP (Session Description) và ICE Candidates kết nối với WebRTC của Odoo 17 Discuss.
  - Cấp quyền `Permission.microphone`.
  - Link nút Mute/Speaker với MediaStream của WebRTC.
- **Phase 2 (Background Ringing - CallKit):**
  - Cài `flutter_callkit_incoming`.
  - Sửa backend Odoo: Khi bấm Call, Odoo bắn FCM payload type `data` (không chứa `notification` key) chứa Call ID.
  - Flutter nhận Data Message ở chế độ nền (Background Handler) -> Đánh thức CallKit để hiện màn hình "Trượt để trả lời" như Zalo/Messenger ngay cả khi điện thoại đang khoá màn hình.
