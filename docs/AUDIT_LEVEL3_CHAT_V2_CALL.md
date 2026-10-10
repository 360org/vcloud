# 📊 BÁO CÁO AUDIT LEVEL 3 CHUYÊN SÂU CHỨC NĂNG GỌI CHAT V2 (WEBRTC & SIGNALING)

> **Dự án:** VCloud Mobile (`vclients`) & Backend Odoo Mobile Addon (`v_mobile_19`, `v_mobile_17`)  
> **Phiên bản tài liệu:** v3.0.0 (AIaC Evidence-First Protocol)  
> **Ngày thực hiện:** 2026-10-10  
> **Chế độ kiểm toán:** STRICT READ-ONLY DEEP CODE INSPECTION & RUNTIME VERIFICATION TRACE  
> **Thang đo độ chắc chắn:** Level 4 (Code Verified) / Level 0 (Waydroid Runtime Environment Blocked)  

---

## 1. TỔNG QUAN KẾT QUẢ AUDIT LEVEL 3

| STT | Hạng Mục Audit Chuyên Sâu | Vị Trí File Mã Nguồn & Tọa Độ | Trạng Thái Rà Soát | Mức Độ Rủi Ro |
| :---: | :--- | :--- | :--- | :---: |
| **1** | Quản lý bộ nhớ & Memory Leak | `vclients/lib/features/chat_v2/application/chat_v2_webrtc_engine.dart:284-298`<br>`chat_v2_call_controller.dart:547-553` | `MediaStreamTrack.stop()` & `dispose()` được gọi đầy đủ khi gác máy. Phát hiện `_queuedRemoteCandidates` chưa dọn dẹp khi abort giữa chừng; tạo mới `AudioPlayer` nhiều lần có thể gây spike. | 🟡 **GAP** (Rủi ro tích tụ bộ nhớ đệm) |
| **2** | Call State Machine & 5 Edge Cases | `vclients/lib/features/chat_v2/application/chat_v2_call_controller.dart:206-234, 400-421, 513-525`<br>`chat_v2_call_screen.dart:25-44` | Ma trận 10 trạng thái hoàn chỉnh; 5 edge cases (Reject, Fast-Busy, Timeout 30s, Cancel, Network Drop 10s) có logic xử lý. Phát hiện Timeout 30s phía client không gửi request cập nhật DB ngay. | 🟡 **GAP** (Đồng bộ timeout DB) |
| **3** | Signaling & STUN/TURN Security | `vclients/lib/features/chat_v2/application/chat_v2_webrtc_engine.dart:70-98`<br>`v_mobile_19/controllers/chat.py:3056` | WebRTC Engine nạp động từ `/call/config`. Tuy nhiên client hardcode STUN Google & TURN credentials (`vuahethong_webrtc:360corp_turn_pass_2026`) vi phạm Rule 5 bảo mật token. | 🟠 **SEC** (Hardcoded TURN Credentials) |
| **4** | Bảo mật IDOR & Phân quyền Portal | `v_mobile_19/controllers/call.py:152-156, 354, 389, 435, 476, 517`<br>`v_mobile_17/controllers/call.py:134, 269, 311, 349, 396, 437, 478, 531` | **IDOR:** Kiểm tra caller/receiver/channel_members chặt chẽ (HTTP 403).<br>**Portal Block:** `v_mobile_17` chặn `deny_portal(uid)` 100%. `v_mobile_19` **THIẾU HOÀN TOÀN** `deny_portal(uid)` trên toàn bộ route `call.py`. | 🔴 **CRITICAL SEC** (Lỗ hổng Portal Bypass trên Odoo 19) |
| **5** | Code Parity Odoo 19 vs Odoo 17 | `v_mobile_19/models/discuss_channel_member.py:65-85, 132-148`<br>`v_mobile_17/controllers/call.py:118-587` | Odoo 19 dùng Native RTC Core (`/mail/rtc/*`) + Bus `vmobile.call/ended`. Odoo 17 dùng Custom API `mobile.api.call.session`. Phát hiện lệch sự kiện bus và lệch kiểm tra portal giữa 2 bản. | 🟠 **PARITY GAP** (Lệch chuẩn bảo vệ Odoo 19 vs 17) |
| **6** | Chống Double-Click Cuộc Gọi | `vclients/lib/features/chat_v2/presentation/screens/chat_v2_detail_screen.dart:1042, 1962-2068` | Nút gọi không có cờ debounce/throttle; không kiểm tra trạng thái active call trước khi push màn hình. Bấm nhanh 5 lần có thể mở nhiều màn hình chồng lấn. | 🟡 **GAP** (Thiếu Debounce UI) |

---

## 2. CHI TIẾT 6 HẠNG MỤC AUDIT CHUYÊN SÂU LEVEL 3

### 2.1. Hiệu Năng & Quản Lý Bộ Nhớ (Memory Leak & Latency Trace)
* **Code Trace WebRTC Engine (`chat_v2_webrtc_engine.dart`):**
  - Hàm `dispose()` (dòng 284–298) đã gọi `_localStream?.getTracks().forEach((track) => track.stop())`, `_localStream?.dispose()` và `_peerConnection?.close()`, `_peerConnection?.dispose()`.
  - Không có hàm nào tên `terminateCall()` trong Engine (logic kết thúc nằm tại Controller).
* **Code Trace Call Controller (`chat_v2_call_controller.dart`):**
  - Hàm `_stopAudio()` (dòng 547–553) gọi `_audioPlayer?.stop()`, `_audioPlayer?.dispose()`, `_audioPlayer = null`.
  - Hàm `_stopTimers()` (dòng 555–564) hủy cả 4 timer: `_durationTimer`, `_ringingTimeoutTimer`, `_disconnectTimer`, `_autoResetTimer`.
* **Phát hiện rủi ro:**
  1. `_queuedRemoteCandidates` (dòng 21): Nếu nhận ICE candidate trước khi có `remoteDescription` mà cuộc gọi bị hủy/từ chối ngay sau đó, mảng này không được `clear()`.
  2. Tạo mới `AudioPlayer()` ở mỗi lần đổ chuông (dòng 530, 540): Trên môi trường Waydroid/Android, việc khởi tạo Native AudioTrack liên tục nếu bấm gọi/hủy nhanh có thể gây CPU spike và rò rỉ AudioTrack descriptor.
  3. Latency Signaling: Trao đổi SDP qua Odoo Bus có độ trễ phụ thuộc vào WebSocket. Nếu fallback về HTTP Long-Polling (50s), latency có thể đạt 200–2500ms, vượt ngưỡng SLA 800ms.

### 2.2. Logic Call State Machine & Edge Cases
* **10 Trạng thái quản lý trong Enum `ChatV2CallState`:**
  `idle`, `outgoingRinging`, `incomingRinging`, `connecting`, `connected`, `ended`, `rejected`, `missed`, `cancelled`, `failed`.
* **Rà soát 5 kịch bản biên:**
  1. **Người nhận từ chối (`rejected`):** Controller gọi `rejectCall()`, phát bus, máy gọi nhận tín hiệu hiển thị "Cuộc gọi bị từ chối", delay 1.2s rồi tự đóng.
  2. **Người nhận bận máy (`busy` - Fast-Busy):** Khi nhận incoming call mà đang ở trạng thái `connected` (dòng 208–219), hệ thống tự động gọi `rejectCall(reason: 'busy')` và `leaveCall(reason: 'busy')`. Máy gọi hiển thị "Người dùng đang trong cuộc gọi khác", delay 1.2s rồi đóng.
  3. **Hết 30 giây không nghe máy (`missed`):** Timer 30s kích hoạt (dòng 515–525), chuyển state sang `missed`, CallScreen hiển thị "Không có phản hồi", delay 1.2s rồi đóng. Phía Odoo backend có trường `expires_at = now + 30s`. **Điểm khuyết:** Client không bắn request cập nhật DB Odoo ngay lúc 30s mà để DB tự xử lý thụ động.
  4. **Người gọi tự hủy trước khi nghe máy (`cancelled`):** Controller gọi `cancelCall()` -> `leaveCall()`, phát bus `cancelled`, phía người nhận dừng chuông và gỡ dialog tức thì.
  5. **Mất mạng đột ngột (Network Drop):** Khi WebRTC đổi sang `disconnected`/`failed`, `_disconnectTimer` đếm ngược 10 giây (grace period cho ICE restart). Quá 10s tự động ngắt với lý do `network_lost`, hiển thị "Cuộc gọi bị ngắt do mất kết nối mạng", giữ màn hình 2.2s để người dùng đọc thông báo.

### 2.3. Bảo Mật Session Cuộc Gọi & IDOR
* **Kiểm tra IDOR (Insecure Direct Object References):**
  - `initiate_call`: Kiểm tra caller bắt buộc thuộc `channel.channel_member_ids` (HTTP 403 nếu ngoài kênh).
  - `get_call_session`: Dòng 354 kiểm tra `caller_id == uid or receiver_id == uid` (HTTP 403).
  - `accept_call` / `reject_call`: Dòng 389 & 435 chỉ cho phép `receiver_id == uid` (HTTP 403).
  - `cancel_call`: Dòng 476 chỉ cho phép `caller_id == uid` (HTTP 403).
  - `end_call` / `append_ice`: Dòng 517 & 570 chỉ cho phép người tham gia cuộc gọi (HTTP 403).
* **Lỗ hổng Phân quyền Portal (CRITICAL):**
  - Trên Odoo 17 (`v_mobile_17/controllers/call.py`): Gọi `deny_portal(uid)` tại dòng 134, 269, 311, 349, 396, 437, 478, 531 -> Chặn 100% tài khoản Portal.
  - Trên Odoo 19 (`v_mobile_19/controllers/call.py`): **KHÔNG CÓ `deny_portal(uid)`** trong bất kỳ route nào! Hàm `deny_portal` có sẵn tại `v_mobile_19/controllers/auth.py:512` nhưng bị bỏ quên không gọi trong `call.py`.

### 2.4. Bảo Tồn Cấu Trúc Code Parity Odoo 19 vs Odoo 17
* **Kiến trúc Odoo 19:** Sử dụng Native RTC API (`/mail/rtc/*`) qua cơ chế xác thực JWT Bearer tại `ir.http._authenticate_explicit`. Kế thừa `discuss.channel.member` để hook FCM wake-up và phát bus notification `vmobile.call/ended`.
* **Kiến trúc Odoo 17:** Sử dụng Custom Controller `mobile.api.call.session` độc lập.
* **Lệch chuẩn (Parity Divergence):**
  - `v_mobile_19/controllers/call.py:129` phát bus `discuss.channel.rtc.session/ended`, trong khi `v_mobile_19/models/discuss_channel_member.py:141` lại phát `vmobile.call/ended`.
  - Thiếu `deny_portal` trên Odoo 19 làm phá vỡ tính đồng bộ về chính sách bảo mật giữa 2 phiên bản.

### 2.5. Tối Ưu Thư Viện Hàm & Signaling Pipeline
* **ICE Servers Config:**
  - Client nạp động từ API `/call/config` (fallback Odoo 19 `join_call`).
  - **Lỗi bảo mật:** Dòng 88–97 `chat_v2_webrtc_engine.dart` hardcode thông tin TURN:
    ```dart
    'urls': ['turn:turn.vuahethong.net:3478?transport=udp', 'turn:turn.vuahethong.net:3478?transport=tcp'],
    'username': 'vuahethong_webrtc',
    'credential': '360corp_turn_pass_2026',
    ```
    Thông tin này cần chuyển vào `--dart-define` hoặc lấy hoàn toàn động từ backend System Parameters (`vmobile.turn_user`, `vmobile.turn_password`).
* **Debounce / Lock bấm gọi:**
  - `chat_v2_detail_screen.dart:1042` gọi `_handleVoiceCall` không có throttle, không check `isCalling`. Bấm nhanh có thể trigger nhiều lần push giao diện.

---

## 3. RÀ SOÁT 10 TESTCASES RUNTIME (TC-01 ➔ TC-10)

| Mã Case | Tên Kịch Bản Kiểm Thử | Kết Quả Code Inspection | Trạng Thái Waydroid Runtime | Đánh Giá |
| :---: | :--- | :--- | :--- | :---: |
| **TC-01** | Happy Path 1-1 Call (A gọi B nghe đàm thoại mượt mà) | Code luồng đầy đủ: `startCall` -> `acceptCall` -> `connected` -> `endCall` | ⚠️ **BLOCKED** (Waydroid stopped, D-Bus sandbox deny) | 🟡 CODE PASS / ENV BLOCKED |
| **TC-02** | Reject Call (B bấm từ chối, A nhận thông báo) | Code xử lý đầy đủ: phát bus `rejected`, UI hiển thị thông báo, tự đóng sau 1.2s | ⚠️ **BLOCKED** | 🟡 CODE PASS / ENV BLOCKED |
| **TC-03** | Call Timeout 30s (Hết 30s tự ngắt báo nhỡ) | Code controller có Timer 30s chuyển `missed`, UI hiển thị "Không có phản hồi" | ⚠️ **BLOCKED** | 🟡 CODE PASS / ENV BLOCKED |
| **TC-04** | Cancel Before Answer (A bấm hủy trước khi B nhấc máy) | Code có `cancelCall()`, cancel invitation, B dừng chuông tức thì | ⚠️ **BLOCKED** | 🟡 CODE PASS / ENV BLOCKED |
| **TC-05** | Mic & Speaker Toggle (Bật/tắt mic, chuyển loa ngoài) | Code liên kết `MediaStreamTrack.enabled` và `Helper.setSpeakerphoneOn` | ⚠️ **BLOCKED** | 🟡 CODE PASS / ENV BLOCKED |
| **TC-06** | Permission Denied (Từ chối quyền Micro không văng app) | Code kiểm tra `Permission.microphone.request()`, show SnackBar, return an toàn | ⚠️ **BLOCKED** | 🟡 CODE PASS / ENV BLOCKED |
| **TC-07** | IDOR Security Check (User C gọi API cuộc gọi của A-B) | Backend Odoo 19 & 17 chặn HTTP 403 Forbidden nếu `uid != caller and uid != receiver` | ⚠️ **BLOCKED** | 🟢 CODE PASS (VERIFIED) |
| **TC-08** | Portal Block (Tài khoản Portal bị chặn gọi điện) | **Odoo 17:** Chặn HTTP 403 qua `deny_portal`.<br>**Odoo 19:** **FAIL (THIẾU CHẶN)**. | ⚠️ **BLOCKED** | 🔴 CODE FAIL ON ODOO 19 |
| **TC-09** | Double Click Prevention (Bấm liên tiếp 5 lần nút gọi) | Phía UI Flutter thiếu cờ lock/debounce; Backend có cơ chế trả về session cũ | ⚠️ **BLOCKED** | 🟡 CODE GAP (UI UNLOCKED) |
| **TC-10** | Memory Leak Check (10 cuộc gọi liên tiếp không phình RAM) | Code có dispose tracks và close connection, nhưng cần profiler đo đạc thực tế | ⚠️ **BLOCKED** | 🟡 CODE PASS / ENV BLOCKED |

---

## 4. CHI TIẾT VỀ MÔI TRƯỜNG RUNTIME WAYDROID
* **Trạng thái thực tế:** Lệnh `waydroid status` trả về `Session: STOPPED`.
* **Rào cản môi trường:** Trong Bubblewrap Sandbox của Claude Code CLI, quyền truy cập hệ thống D-Bus (`org.freedesktop.DBus.Error.AccessDenied: Failed to open socket: Operation not permitted`) bị chặn, không thể tự động khởi chạy Weston daemon và Waydroid container từ phiên sandbox.
* **Kết nối ADB:** `adb devices` chưa có thiết bị nào được kết nối tại thời điểm kiểm toán.
* **Kết luận Kỷ luật (Anti-Sycophancy):** Báo cáo đúng thực tế môi trường là **BLOCKED BY RUNTIME ENVIRONMENT**, không suy diễn hoặc giả mạo kết quả runtime thực tế của Waydroid.

---

## 5. KHUYẾN NGHỊ KHẮC PHỤC TRƯỚC KHI VẬN HÀNH (ACTION PLAN)
1. 🔴 **Bảo mật P0 (Odoo 19 Portal Block):** Bổ sung `portal_denied = deny_portal(uid)` vào 8 endpoint trong `v_mobile_19/controllers/call.py`.
2. 🟠 **Bảo mật P1 (TURN Credentials):** Xóa thông tin đăng nhập TURN hardcode trong `chat_v2_webrtc_engine.dart`, chuyển sang cấu hình từ server Odoo `ir.config_parameter`.
3. 🟡 **Giao diện P2 (Debounce Call Button):** Thêm biến `bool _isInitiatingCall = false` trong `_handleVoiceCall` và kiểm tra `chatV2CallControllerProvider != null` trước khi gọi.
4. 🟡 **Đồng bộ Timeout P2:** Khi Timer 30s kích hoạt phía client, gọi API `cancelCall` hoặc `leaveCall` để cập nhật trạng thái `missed` lên Odoo DB ngay lập tức.
