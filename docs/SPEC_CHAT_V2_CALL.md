# SPECIFICATION: Vcloud Chat V2 Voice Call & CallKit

> **Dự án**: Vcloud Mobile (Flutter) & V_Mobile (Odoo 17)
> **Mục tiêu**: Xây dựng tính năng VoIP Call 1-1 qua WebRTC kết nối với Odoo Discuss, tích hợp CallKit/ConnectionService để nhận cuộc gọi lúc tắt app.

---

## 1. Kiến trúc Tổng quan (VoIP Call Architecture)

Ứng dụng sẽ sử dụng giao thức **WebRTC** để truyền tải âm thanh P2P (Peer-to-Peer), thông qua Server Odoo đóng vai trò là **Signaling Server**.

### 1.1 Sơ đồ luồng (Flow)
```text
[Caller (A)]                    [Signaling Server (Odoo)]                 [Callee (B)]
    |                                     |                                     |
    |-- 1. Bấm Gọi (API: /rtc/call) ----->|                                     |
    |                                     |-- 2. FCM Push Data (Action: CALL)-> |
    |                                     |                                     |-- 3. Bật CallKit "Đang gọi tới"
    |<-- 4. Trả về Session ID ------------|                                     |
    |                                     |                                     |-- 5. Bấm Nghe (CallKit Accept)
    |                                     |<-- 6. API: /rtc/accept -------------|
    |                                     |                                     |
    |-- 7. ICE Candidate / SDP Offer ---->|-- 8. Gửi SDP Offer ---------------->|
    |<-- 10. Gửi SDP Answer --------------|<-- 9. SDP Answer / ICE Candidate ---|
    |                                     |                                     |
    |======================= 11. WEBRTC P2P AUDIO STREAM =======================|
```

## 2. Phase 1: Môi trường & Core WebRTC (Tầng Âm Thanh)

### 2.1 Các Dependencies Mới
- `flutter_webrtc: ^0.10.4` (Core engine âm thanh/video 2 chiều).
- `permission_handler: ^11.3.0` (Xin quyền Microphone).

### 2.2 Quy trình Xử lý Âm thanh (Audio MediaStream)
1. **Thiết lập Micro:** 
   - Xin quyền `Permission.microphone.request()`.
   - Lấy Audio Stream từ thiết bị: `navigator.mediaDevices.getUserMedia({"audio": True, "video": False})`.
2. **Nút Mute / Unmute:** 
   - Truy xuất track âm thanh nội bộ: `localStream.getAudioTracks()[0].enabled = false / true`.
3. **Nút Speaker (Loa ngoài):** 
   - Dùng `Helper.setSpeakerphoneOn(true / false)` thuộc `flutter_webrtc`.
4. **Đổ chuông:**
   - Dùng `audioplayers`. Cung cấp file audio `.mp3` cục bộ (assets) vào hàm `_playDialingTone()` (tiếng bíp bíp) và `_playRingtone()` (tiếng chuông viber).

## 3. Phase 2: Native Call Background (Tầng Nền & Hệ Điều Hành)

### 3.1 Các Dependencies Mới
- `flutter_callkit_incoming: ^2.0.1` (Giao diện Nghe/Từ chối chuẩn Apple CallKit và Android ConnectionService).
- *Firebase Cloud Messaging* (đã có sẵn trong Core, cần dùng Data Message).

### 3.2 Kịch bản Bắt sự kiện (Event Handling)
1. **Trạng thái KILLED (App tắt hoàn toàn) / BACKGROUND:**
   - Odoo đẩy lệnh Push notification dạng `DATA` (Không có object `notification`).
   - Catcher `@pragma('vm:entry-point')` trong Flutter bắt `FirebaseMessaging.onBackgroundMessage`.
   - Kích hoạt `FlutterCallkitIncoming.showCallkitIncoming(params)`.
   - Màn hình đen điện thoại sáng lên, hiển thị UI Gọi của Hệ điều hành.
2. **Nút Nhận (Accept) từ Lockscreen:**
   - CallKit gửi event `ACTION_CALL_ACCEPT`.
   - App đánh thức Flutter WebRTC, mở App, chuyển trang vào màn hình `ChatV2CallScreen`, gửi SDP qua Odoo.
3. **Nút Từ chối (Decline) từ Lockscreen:**
   - CallKit gửi event `ACTION_CALL_DECLINE`.
   - App âm thầm gọi API `/rtc/reject` để báo Backend gác máy.

## 4. Phase 3: Giao thức Báo hiệu (Signaling Protocol - Odoo)

⚠️ **CHÚ Ý QUAN TRỌNG:** Cơ chế WebRTC của Odoo 17 và Odoo 19 khác biệt rất lớn do Odoo 19 đã rework lại toàn bộ module `mail`/`discuss`. App Flutter phải sử dụng **Signaling Abstraction Layer (Lớp trừu tượng hóa)** để tương thích với cả 2 phiên bản.

### 4.1. Kiến Trúc Lớp Trừu Tượng Hóa (Interface `IOdooRtcSignaling`)

Tạo 2 Implementation tách biệt và Inject dựa trên phiên bản Odoo hiện tại (lấy từ `/web/webclient/version_info` hoặc config):

*   **`Odoo17RtcSignaling` (Dành cho Backend v_mobile_17):**
    *   **Khởi tạo:** POST `/web/dataset/call_kw/discuss.channel/rtc_join_call` (Hoặc endpoint tùy chỉnh trên `v_mobile_17`).
    *   **Đàm phán (SDP/ICE):** POST `/web/dataset/call_kw/mail.rtc.session/update_and_broadcast`. Cần xử lý lắng nghe message dạng `rtc_update` qua Websocket cũ.
    *   **Kết thúc:** POST `/web/dataset/call_kw/discuss.channel/rtc_leave_call`.

*   **`Odoo19RtcSignaling` (Dành cho Backend v_mobile_19):**
    *   Sử dụng API mới của hệ thống Discuss Odoo 19 (các model `discuss.voice.rtc.session` thay cho `mail.rtc.session` - tùy cấu trúc Odoo 19).
    *   Sử dụng luồng WebSockets mới của Odoo 19 để truyền Notification siêu tốc.

*   **Custom Mobile Wrapper (ĐỀ XUẤT TỐI ƯU NHẤT - Zero Config):**
    Thay vì chạy theo sự thay đổi của Odoo Core ở từng version, ta sẽ tạo **Endpoint Đồng Nhất** ngay trên module `v_mobile` (cả nhánh 17.0 và 19.0 đều cài đặt chung 1 API cấu trúc giống nhau):
    - `/api/v1/mobile/rtc/join`
    - `/api/v1/mobile/rtc/signal`
    - `/api/v1/mobile/rtc/leave`
    - Nhiệm vụ của `v_mobile` ở Backend là tự dịch các lệnh API này sang lời gọi ORM tương ứng của Core Odoo 17 hoặc 19. Lúc này, **Flutter App không cần quan tâm nó đang gọi cho bản 17 hay 19**, mọi gánh nặng tương thích đẩy về Backend `v_mobile`.

## 5. Roadmap Thực Thi & Nhiệm Vụ

**Sprint 1: Xây dựng Audio Core (1-2 ngày)**
- [ ] Bổ sung 2 file âm thanh chuông vào `assets/audio/`.
- [ ] Cài đặt `flutter_webrtc`, `permission_handler`.
- [ ] Chỉnh sửa `ChatV2CallScreen` để check quyền Micro trước khi cho vào màn hình.
- [ ] Kết nối biến `_isMuted`, `_isSpeaker` tới MediaStream của WebRTC.

**Sprint 2: Odoo WebRTC Signaling (2 ngày)**
- [ ] Viết lớp `ChatV2Signaling` đóng gói luồng STUN/TURN & SDP.
- [ ] Chỉnh sửa `ChatV2CallController` thay vì gửi message mock, sẽ gửi lệnh join_call để tương thích Odoo Native Call.
- [ ] Ràng buộc P2P stream xuất ra Headpiece (Loa trong) thay vì tắt ngóm.

**Sprint 3: Background CallKit (1 ngày)**
- [ ] Cài đặt `flutter_callkit_incoming`.
- [ ] Gắn listener CallKit trong `main.dart` (Foreground & Background).
- [ ] Đẩy Push Data chuẩn Odoo để đánh thức CallKit.

---
*Ghi chú cho AI: Bắt buộc code theo trình tự Sprint trên. Không nhảy bước Background nếu Audio Core chưa chạy.*
