# KẾ HOẠCH TRIỂN KHAI (PLAN) — HỆ THỐNG LIVE CHAT OMNICHANNEL & PORTAL SUPPORT CHUẨN ODOO ENTERPRISE

> **Mã tài liệu**: `docs/PLAN_PORTAL_SUPPORT_CHANNEL.md`  
> **Căn cứ kỹ thuật**: `docs/SPEC_PORTAL_SUPPORT_CHANNEL.md` (Phiên bản chuẩn hóa 2026-10-15)  
> **Hệ thống gốc**: Odoo Core (`im_livechat`, `discuss.channel`, `crm_livechat`, `website_helpdesk_livechat`)  
> **Dự án**: VCloud Mobile/Web Client (`vclients`) & Odoo Backend Addon (`v_mobile_17`, `v_mobile_19`)  
> **Single Authority Director**: Anh Tân (Sếp Tân) — 360 CORP  
> **Quy tắc thực thi**: Ponytail (Tối giản diff, kế thừa 100% Odoo Core, YAGNI, tuyệt đối CẤM chế tính năng ngoài chuẩn)  
> **Ngày lập kế hoạch**: 2026-10-15  

---

## I. MỤC TIÊU & RÀO CHẮN KỸ THUẬT (GOALS & GUARDRAILS)

### 1. Mục tiêu cốt lõi
1. **Khắc phục triệt để lỗi 0 Sessions**: Chuyển từ cơ chế chat 1-1 với Admin hoặc nhóm tự chế (`channel_type: 'group'`) sang phiên Live Chat chuẩn Odoo (`channel_type: 'livechat'`), ghi nhận chính xác số ca trực thực tế trên menu `/home/livechat`.
2. **Kế thừa 100% hạ tầng Odoo Discuss**: Đưa tin nhắn của khách hàng từ cả Website và App Mobile vào đúng mục **`Looking for help`** trong Odoo Discuss để nhân viên trong ca trực tiếp nhận theo thời gian thực.
3. **Chuyển giao phiên liền mạch (Session Continuity)**: Khách trao đổi trên Web Live Chat, khi đăng nhập vào Portal App Mobile trên điện thoại sẽ kế thừa trọn vẹn toàn bộ lịch sử tin nhắn cũ qua `web_session_uuid`.
4. **Chuyển đổi nghiệp vụ chuẩn Odoo Core (Chat ➔ Business)**: Kế thừa 100% cơ chế chuẩn Odoo `crm_livechat` (lệnh `/lead`) và `website_helpdesk_livechat` (lệnh `/ticket`). Operator trực ca gõ lệnh slash command trên Odoo Discuss hoặc Chatbot tự động chuyển đổi, lịch sử chat tự động nhúng vào mô tả.

### 2. Danh mục Deprecated & Loại bỏ vĩnh viễn (RÀO CHẮN NGHIÊM NGẶT)
* ❌ **CẤM Quick Action Buttons trên Mobile (`[⭐ Nhận báo giá]`, `[🎫 Gửi yêu cầu hỗ trợ]`)**: Nghiệp vụ tạo Lead/Ticket thuộc về Operator hoặc Chatbot, khách hàng không tự bấm nút tạo Lead trong CRM.
* ❌ **CẤM 2 Endpoints REST tự tạo (`POST /api/v1/mobile/crm/lead` và `POST /api/v1/mobile/helpdesk/ticket`)**: Odoo Core không dùng client REST để tạo Lead/Ticket từ livechat.
* ❌ **CẤM tham số tự chế `channel_alias`**: Odoo Core định danh kênh Live Chat bằng **`channel_id`** (Integer bản ghi `im_livechat.channel`).
* ❌ **CẤM thẻ hệ thống "SystemNotificationCard" (`#LEAD-xxx`, `#TCK-xxx`) trong khung chat khách**: Slash commands Odoo chỉ gửi transient notification cho Operator.
* ❌ **CẤM Hardcode tên kênh ("Chăm Sóc Khách Hàng 360") và tích xanh MXH tự chế**: Lấy động 100% từ Odoo `im_livechat.channel`; trạng thái trực ca dùng chấm xanh trực tuyến (**🟢 Online Indicator**).
* ❌ **CẤM chat 1-1 với Admin (`channel_type: 'chat'`) hoặc nhóm tĩnh (`channel_type: 'group'`)**: Gây nghẽn tại 1 tài khoản và phá vỡ cơ chế xoay ca trực.

---

## II. MA TRẬN PHÂN RÃ CÔNG VIỆC CHI TIẾT (WBS)

Kế hoạch triển khai được cấu trúc thành **2 phần việc chính** và **5 giai đoạn tuần tự**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│ GIAI ĐOẠN 1: KHẢO SÁT & CHUẨN BỊ MÔ HÌNH DỮ LIỆU (READ-BEFORE-WRITE)   │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ GIAI ĐOẠN 2: THỰC THI BACKEND ODOO 17 & 19 (v_mobile_17 & v_mobile_19)  │
│ - Task 1.1: LivechatController (GET /channels, POST /session)          │
│ - Task 1.2: Phân bổ "Looking for help" & Nhảy số /home/livechat        │
│ - Task 1.3: Tương thích Slash Commands (/lead, /ticket) & Chatbot      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ GIAI ĐOẠN 3: THỰC THI FRONTEND FLUTTER (vclients)                      │
│ - Task 2.1: Data Models & LivechatRepository                           │
│ - Task 2.2: LivechatSelectionBottomSheet (Kênh động, Chấm xanh 🟢)     │
│ - Task 2.3: Điều hướng 1-Touch thẳng vào ChatV2RoomScreen hiện hữu     │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ GIAI ĐOẠN 4: BỘ 10 CASE KIỂM THỬ ĐỘC LẬP & TỰ ĐỘNG HÓA (VERIFICATION)  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ GIAI ĐOẠN 5: REVIEW DIFF, COMMIT GIT CHUẨN & BÀN GIAO SẾP TÂN          │
└────────────────────────────────────────────────────────────────────────┘
```

---

### GIAI ĐOẠN 1: Khảo Sát & Chuẩn Bị Mô Hình Dữ Liệu (Read-Before-Write)

* **Mục tiêu**: Rà soát đối chiếu ORM giữa Odoo 17 và Odoo 19 để đảm bảo tái sử dụng 100% logic chuẩn của `im_livechat.channel` và `discuss.channel`.
* **Chi tiết khảo sát**:
  1. Xác nhận sự hiện diện của module `im_livechat` trong database:
     * Odoo 17: `origin/addons/im_livechat/models/im_livechat_channel.py`.
     * Odoo 19: Module `im_livechat` trong Odoo 19.
  2. Xác nhận hàm cốt lõi `_get_livechat_discuss_channel_vals(anonymous_name, user_id=None, previous_operator_id=None, chatbot_script=None)`:
     * Trả về dict: `channel_member_ids`, `livechat_active=True`, `livechat_operator_id`, `livechat_channel_id`, `channel_type='livechat'`, `name`.
  3. Kiểm tra cơ chế `available_operator_ids`:
     * Đọc các operator có `im_status` trong `('online', 'away')` hoặc thông qua bảng `bus.presence` / `mail.presence`.

---

### GIAI ĐOẠN 2: Triển Khai Backend Odoo 17 & 19 (`v_mobile_17` & `v_mobile_19`)

Đồng bộ code đối xứng 100% cho cả 2 backend. Tệp tạo mới duy nhất:
* `v_mobile_17/controllers/livechat.py`
* `v_mobile_19/controllers/livechat.py`
* Khai báo `from . import livechat` trong `__init__.py` của cả 2 thư mục controllers.

#### Task 1.1: Viết Controller `LivechatController` cung cấp 2 API chuẩn Odoo Core
1. **Endpoint `GET /api/v1/mobile/livechat/channels`**:
   * **Mục đích**: Cung cấp danh sách các kênh livechat đang kích hoạt của tổ chức cho Mobile App.
   * **Authentication**: JWT Bearer token qua `AuthController.authenticate()` (Hỗ trợ cả Portal User và Internal User).
   * **Logic ORM**:
     * Search `im_livechat.channel` với domain `[('id', '!=', False)]` (active channels).
     * Với mỗi channel, kiểm tra danh sách Operator trực ca:
       - Lấy `channel.user_ids`.
       - Xác định có ít nhất 1 operator đang online (kiểm tra `im_status == 'online'` hoặc presence) hoặc channel có gắn `chatbot_script_id` đang active.
     * Trích xuất thông tin:
       - `id`: ID kênh (Integer).
       - `name`: Tên kênh ("Customer Care", "Technical Support"...).
       - `description`: Mô tả nghiệp vụ kênh.
       - `avatar_url`: `/api/v1/mobile/avatar/im_livechat.channel/<id>?field=image_128`.
       - `is_available`: Boolean (True nếu có operator online hoặc có chatbot script).
       - `default_message`: Câu chào cấu hình trên kênh hoặc mặc định chuẩn 360 CORP.

2. **Endpoint `POST /api/v1/mobile/livechat/session`**:
   * **Mục đích**: Khởi tạo hoặc tái sử dụng phiên Live Chat chuẩn Odoo.
   * **Request Body**:
     ```json
     {
       "channel_id": 1,
       "web_session_uuid": "optional-uuid-string"
     }
     ```
   * **Logic ORM (Idempotency & Session Continuity)**:
     * **Bước 1**: Xác thực JWT token, lấy `uid` và `partner_id` của khách hàng Portal.
     * **Bước 2 (Nối phiên từ Web)**: Nếu có `web_session_uuid`, tìm kiếm `discuss.channel` có `uuid = web_session_uuid` và `livechat_active = True`. Nếu tìm thấy, tự động add `partner_id` của Portal user vào kênh (nếu chưa là member) và cập nhật `visitor_uid`.
     * **Bước 3 (Idempotent reuse)**: Nếu không có `web_session_uuid`, tìm kiếm phiên livechat đang mở (`livechat_active = True`, `channel_type = 'livechat'`, `livechat_channel_id = channel_id`) mà `partner_id` này đang tham gia trong vòng 24 giờ qua. Nếu đã có phiên active ➔ Trả về phiên đó, không tạo trùng lặp.
     * **Bước 4 (Khởi tạo phiên mới chuẩn Odoo Core)**:
       - Gọi hàm Odoo Core:
         ```python
         channel_vals = livechat_channel.sudo()._get_livechat_discuss_channel_vals(
             anonymous_name=partner.name,
             user_id=uid
         )
         ```
       - Nếu không có operator trực ca và không có chatbot: Fallback gán Operator mặc định hoặc OdooBot để tiếp nhận tin nhắn offline, đảm bảo khách hàng luôn được lắng nghe.
       - Tạo bản ghi `discuss.channel` bằng `sudo().create(channel_vals)`.
     * **Bước 5 (Tin nhắn chào khởi đầu)**:
       - Nếu phiên mới được tạo, kiểm tra nếu kênh có `default_message` hoặc chatbot welcome message ➔ Tạo bản ghi `mail.message` từ `livechat_operator_id` (hoặc OdooBot) gửi lời chào trang trọng tới khách.
     * **Bước 6 (Trả về Payload chuẩn SPEC)**:
       - Trả về: `channel_id`, `uuid`, `channel_name`, `channel_type: 'livechat'`, `is_operator_online`, thông tin `operator` (`id`, `name`, `livechat_username`, `avatar_url`), và `last_message`.

#### Task 1.2: Đẩy phiên vào mục "Looking for help" & Nhảy số tại `/home/livechat`
* Khi `discuss.channel` được tạo với `channel_type = 'livechat'` và `livechat_active = True`, Odoo Core Discuss JS Web Client tự động xếp kênh vào danh mục **`Looking for help`** (hoặc `Livechat`) trên giao diện web của Operator.
* Bản ghi `im_livechat.channel` tự động liên kết với `discuss.channel` qua trường `livechat_channel_id` ➔ Menu backend `/home/livechat` tự động nhảy số thống kê Sessions thực tế (chấm dứt hoàn toàn lỗi 0 Sessions).

#### Task 1.3: Tương thích Slash Commands Odoo Core (`/lead`, `/ticket`) & Chatbot
* Vì phiên hội thoại là bản ghi `discuss.channel` kiểu `livechat` chuẩn mực:
  * Module `crm_livechat` của Odoo tự động lắng nghe lệnh `/lead [tiêu đề]` từ Operator, tự động bốc toàn bộ nội dung trò chuyện qua `_get_channel_history()` điền vào `crm.lead.description`.
  * Module `website_helpdesk_livechat` tự động lắng nghe lệnh `/ticket [tiêu đề]` từ Operator, tự động tạo `helpdesk.ticket` nhúng toàn bộ lịch sử chat.
  * Chatbot Odoo Core (`chatbot.script`) hoạt động nguyên bản theo từng step mà không cần code tùy biến.

---

### GIAI ĐOẠN 3: Triển Khai Frontend Flutter (`vclients`)

Ứng dụng tuân thủ Clean Architecture và Design Tokens chuẩn **360 CORP (Tech Royal Blue `#0077cd` & Digital Green `#00ce2c`)**.

#### Task 2.1: Xây dựng Data Models & LivechatRepository
* **Thư mục tạo mới**: `vclients/lib/features/livechat/`
* **Tệp `data/models/livechat_channel_model.dart`**:
  * Các trường: `id`, `name`, `description`, `avatarUrl`, `isAvailable`, `defaultMessage`.
  * Phương thức: `fromJson`, `toJson`.
* **Tệp `data/models/livechat_session_model.dart`**:
  * Các trường: `channelId`, `uuid`, `channelName`, `channelType`, `avatarUrl`, `isOperatorOnline`, `operatorName`, `operatorAvatarUrl`, `lastMessage`.
* **Tệp `data/livechat_repository.dart`**:
  * Gọi `OdooApiClient`:
    - `Future<List<LivechatChannelModel>> getChannels()` ➔ `GET /api/v1/mobile/livechat/channels`.
    - `Future<LivechatSessionModel> createOrGetSession({required int channelId, String? webSessionUuid})` ➔ `POST /api/v1/mobile/livechat/session`.
* **Tệp `application/livechat_controller.dart`**:
  * Riverpod Provider `livechatChannelsProvider`: Nạp danh sách kênh hỗ trợ.
  * `LivechatSessionNotifier`: Xử lý mở session và lưu trữ `web_session_uuid` trong local storage.

#### Task 2.2: Thiết kế `LivechatSelectionBottomSheet` (Kênh động, Chấm xanh 🟢)
* **Tệp `presentation/widgets/livechat_selection_bottom_sheet.dart`**:
  * Kế thừa giao diện chuẩn wireframe trong SPEC:
    - Drag handle tinh tế.
    - Tiêu đề: "TRUNG TÂM HỖ TRỢ TRỰC TUYẾN" (Slate 900 `#0f172a`, font-weight: `w600`).
    - Subtitle: "Vui lòng chọn bộ phận tiếp nhận để được hỗ trợ tốt nhất".
    - Danh sách thẻ kênh bo góc 16dp:
      * Chấm xanh trực tuyến 🟢 Digital Green `#00ce2c` khi `isAvailable == true` ("Đang có chuyên viên trực ca • Phản hồi ~2 phút").
      * Chấm xám khi ngoại tuyến kèm thông báo tiếp nhận 24/7.
      * Tên kênh động từ Odoo Backend ("Customer Care", "Technical Support"...).
      * Mô tả chi tiết phạm vi hỗ trợ của từng kênh.
    - Hiệu ứng tap có phản hồi xúc giác nhẹ (Haptic feedback) và trạng thái loading trực tiếp trên card khi đang kết nối.

#### Task 2.3: Điều hướng 1-Touch thẳng vào `ChatV2RoomScreen` hiện hữu
* **Cơ chế 1-Touch**:
  * Khi khách chạm vào một kênh trong BottomSheet:
    1. Gọi `createOrGetSession(channelId: channel.id)`.
    2. Đóng BottomSheet (`Navigator.of(context).pop()`).
    3. Điều hướng thẳng vào phòng chat:
       ```dart
       context.push('/chat/${session.channelId}?name=${Uri.encodeComponent(session.channelName)}&avatar=${Uri.encodeComponent(session.avatarUrl ?? '')}');
       ```
    4. Màn hình `ChatV2DetailScreen` hiện hữu tự động tải tin nhắn và cho phép chat ngay lập tức bằng API `/api/v1/mobile/chat/*` sẵn có.
* **Tối ưu trải nghiệm Portal**:
  * Khách hàng Portal khi bấm nút "Hỗ Trợ" ở Home Screen được mở thẳng BottomSheet này, không bị đẩy vào màn hình danh sách chat nội bộ nhân viên.
  * Khung chat hiển thị sạch sẽ, không có bất kỳ nút bấm Quick Action tự chế nào.

---

### GIAI ĐOẠN 4: Bộ 10 Case Kiểm Thử Độc Lập & Nghiệm Thu (DoD)

Mọi nghiệm thu phải vượt qua 100% 10 test cases độc lập theo đúng ma trận SPEC:

| Mã Case | Tình huống kiểm thử | Hành vi kỳ vọng chuẩn Odoo Core | Tiêu chí Đạt |
|:---:|---|---|:---:|
| **TC-01** | Khách chọn kênh `Customer Care` trên Mobile | Khởi tạo phiên `discuss.channel` có `channel_type = 'livechat'`. | ĐẠT |
| **TC-02** | Khách chọn kênh `Technical Support` trên Mobile | Khởi tạo phiên Live Chat phân bổ tới kỹ thuật viên trực ca. | ĐẠT |
| **TC-03** | Đối soát menu `/home/livechat` trên Odoo Web | Số lượng phiên Live Chat tăng lên (`>= 1 Sessions`), chấm dứt lỗi 0 Sessions. | ĐẠT |
| **TC-04** | Hiển thị trong Odoo Discuss của nhân viên | Phiên chat xuất hiện tại mục **`Looking for help`** của Operator trực ca. | ĐẠT |
| **TC-05** | Nhận diện tiêu đề Header trên App Mobile | Header hiển thị đúng tên kênh từ Odoo, không bị gán cứng "Chăm Sóc Khách Hàng 360". | ĐẠT |
| **TC-06** | Trạng thái trực ca của nhân viên | Hiển thị chấm xanh trực tuyến 🟢 khi Operator online; chuyển xám khi ngoại tuyến. | ĐẠT |
| **TC-07** | Nhận diện danh tính người phản hồi | Hiển thị `OdooBot` hoặc `livechat_username`, không làm lộ thông tin cá nhân nội bộ. | ĐẠT |
| **TC-08** | Operator gõ `/lead [tiêu đề]` trong Odoo Discuss | Odoo Core (`crm_livechat`) tạo `crm.lead`, trường `description` nhúng đủ lịch sử chat. | ĐẠT |
| **TC-09** | Operator gõ `/ticket [tiêu đề]` trong Odoo Discuss | Odoo Core (`website_helpdesk_livechat`) tạo `helpdesk.ticket` nhúng đủ lịch sử chat. | ĐẠT |
| **TC-10** | Đồng bộ phiên từ Web sang App (Continuity) | Khách chat trên web, đăng nhập vào App Mobile thấy lại toàn bộ tin nhắn cũ. | ĐẠT |

* **Kiểm tra tĩnh**: Chạy `flutter analyze` trên `vclients` bảo toàn 0 errors / 0 warnings.
* **Kiểm tra Python**: Viết 1 test script tự động `tests/test_livechat_api.py` verify 2 API mới trên Odoo 17 & 19.

---

### GIAI ĐOẠN 5: Review Diff, Commit Git Chuẩn & Bàn Giao

* **Rà soát Diff**: Đảm bảo diff ngắn nhất, không thừa thãi file cấu hình, tuân thủ nguyên tắc Ponytail.
* **Commit Trailer bắt buộc**:
  ```text
  docs(plan): Odoo Core Omnichannel Live Chat & Portal Support Plan - Date: 2026-10-15
  
  Authored-By: 360org <support@360.org.vn>
  ```
* **Bàn giao**: Trình bày báo cáo cô đọng cho Sếp Tân phê duyệt trước khi kích hoạt Bước 5 (Build/Code).

---

## III. DỰ TOÁN THỜI LƯỢNG & RỦI RO DỰ PHÒNG

| Hạng mục | Công việc cụ thể | Thời lượng dự kiến | Rủi ro & Giải pháp phòng ngừa |
|---|---|:---:|---|
| **Backend v17 & v19** | Viết `LivechatController` (2 API chuẩn Odoo Core) | 1.5 giờ | Database chưa có sẵn channel `im_livechat` mẫu ➔ Tự động fallback tạo hoặc tìm channel active đầu tiên. |
| **Frontend Mobile** | Tạo BottomSheet 🟢, Repository, Provider & 1-Touch Nav | 1.5 giờ | Lệch version Flutter SDK / analyzer ➔ Giữ nghiêm quy chuẩn const, null safety, không dùng bang operator (`!`). |
| **Kiểm thử 10 TC** | Chạy automated test script & kiểm thử Odoo Web | 1.0 giờ | Môi trường test thiếu Operator online ➔ Kiểm tra cơ chế OdooBot fallback. |
| **Review & Bàn giao**| Diff audit, commit chuẩn trailer | 0.5 giờ | Không có rủi ro. |
| **TỔNG CỘNG** | | **4.5 giờ** | |
