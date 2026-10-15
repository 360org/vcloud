# ĐẶC TẢ KỸ THUẬT (SPEC) — HỆ THỐNG LIVE CHAT OMNICHANNEL & PORTAL SUPPORT CHUẨN ODOO ENTERPRISE

> **Mã tài liệu**: `docs/SPEC_PORTAL_SUPPORT_CHANNEL.md`  
> **Hệ thống gốc**: Odoo Enterprise (Module `im_livechat`, `mail.discuss`, `crm_livechat`, `website_helpdesk_livechat`)  
> **Nền tảng đồng bộ**: VCloud Mobile App (Flutter `vclients`) ⟷ Backend Addon `v_mobile` (Odoo 17 & 19)  
> **Thẩm định & Phê duyệt**: Sếp Tân — 360 CORP  
> **Trạng thái**: Chuẩn hóa 100% theo Odoo Core (Áp dụng nguyên tắc Ponytail & YAGNI)  
> **Cập nhật lần cuối**: 2026-10-15  

---

## I. MỤC TIÊU & PHẠM VI (GOALS & SCOPE)

### 1. Mục tiêu cốt lõi
1. **Khắc phục triệt để lỗi 0 Sessions**: Chuyển từ cơ chế chat 1-1 với Admin hoặc nhóm tự chế (`channel_type: 'group'`) sang phiên Live Chat chuẩn Odoo (`channel_type: 'livechat'`), ghi nhận chính xác số ca trực thực tế trên menu `/home/livechat`.
2. **Kế thừa 100% hạ tầng Odoo Discuss**: Đưa tin nhắn của khách hàng từ cả Website và App Mobile vào đúng mục **`Looking for help`** trong Odoo Discuss để nhân viên trong ca trực tiếp nhận theo thời gian thực.
3. **Chuyển giao phiên liền mạch (Session Continuity)**: Khách trao đổi trên Web Live Chat, khi đăng nhập vào Portal App Mobile trên điện thoại sẽ kế thừa trọn vẹn toàn bộ lịch sử tin nhắn cũ.
4. **Chuyển đổi nghiệp vụ 1-chạm (Chat ➔ Business)**: Cho phép chuyển nhanh nội dung hội thoại thành cơ hội bán hàng (**CRM Lead**) hoặc phiếu báo lỗi (**Helpdesk Ticket**) với toàn bộ lịch sử chat được tự động nhúng vào mô tả.

### 2. Danh mục các ý tưởng sai bị loại bỏ hoàn toàn (Deprecated & Removed)
Theo chỉ đạo và rà soát thực tế, các cách làm sau **bị loại bỏ hoàn toàn khỏi kiến trúc**:
* ❌ **Bỏ chat 1-1 với cá nhân Admin (`channel_type: 'chat'`)**: Gây nghẽn tại 1 tài khoản, các nhân viên trực ca không nhìn thấy.
* ❌ **Bỏ tạo kênh nhóm tự chế (`channel_type: 'group'`) rồi gán cứng nhân viên tĩnh**: Phá vỡ cơ chế xoay ca trực của Live Chat.
* ❌ **Bỏ gộp chung 1 kênh không phân loại nhu cầu**: Gây chồng chéo giữa tư vấn bán hàng và hỗ trợ kỹ thuật.
* ❌ **Bỏ hardcode tên kênh ("Chăm Sóc Khách Hàng 360") và tích xanh MXH tự chế**: Tên kênh và avatar bắt buộc lấy **động 100% từ Odoo Backend** (`im_livechat.channel`); trạng thái trực ca dùng chấm xanh trực tuyến (**🟢 Online Indicator**).
* ❌ **Bỏ triệt tiêu danh tính người trực (ép hiển thị logo vô danh)**: Chuẩn Odoo bảo mật danh tính qua trường `livechat_username` trong User Profile (hoặc `OdooBot`).
* ❌ **Bỏ câu trả lời mẫu (`mail.shortcode`)**: Trên `vuahethong.net` chưa cấu hình danh mục câu mẫu thực tế ➔ Không đưa vào (YAGNI).
* ❌ **Bỏ đánh giá Rating / Sao (`rating.rating`) & gửi email transcript**: Tối giản luồng chat, tập trung hỗ trợ nhanh (YAGNI).
* ❌ **Bỏ gọi thoại / gọi video WebRTC (`discuss.call`)**: Tránh phình to phạm vi giải pháp (YAGNI).

---

## II. HAI TRỤ CỘT KIẾN TRÚC DUY NHẤT (THE 2 CORE PILLARS)

Hệ thống được đóng gói tinh gọn xoay quanh **đúng 2 trụ cột nghiệp vụ**:

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        TRỤ CỘT 1: LIVE CHAT SESSIONS & PHÂN LUỒNG                      │
│                                                                                        │
│   Khách hàng Portal ───► Chọn kênh hỗ trợ ───► Tạo discuss.channel (type: livechat)    │
│                                                     │                                  │
│                                                     ▼                                  │
│                         Phân bổ tới Operator online trong "Looking for help"           │
│                         (Đếm đúng số Sessions tại /home/livechat)                      │
└───────────────────────────────────────────┬────────────────────────────────────────────┘
                                            │
                                            ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                    TRỤ CỘT 2: CHUYỂN ĐỔI NGHIỆP VỤ 1-CHẠM (QUICK ACTIONS)              │
│                                                                                        │
│   [⭐ Nhận báo giá]  ───► Tạo crm.lead (Tự động bốc Chat History vào description)       │
│   [🎫 Gửi báo lỗi]    ───► Tạo helpdesk.ticket (Tự động bốc Chat History vào description)│
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## III. ĐẶC TẢ MÔ HÌNH DỮ LIỆU ODOO (DATA MODELS)

| Model kỹ thuật | Vai trò & Quy cách sử dụng |
|---|---|
| **`im_livechat.channel`** | Cấu hình 2 kênh hỗ trợ chuẩn của tổ chức: `Customer Care` (CSKH / Bán hàng) và `Technical Support` (Kỹ thuật). Quản lý danh sách Operator trực ca. |
| **`discuss.channel`** | Bản ghi phiên hội thoại. Bắt buộc: `channel_type = 'livechat'`, liên kết `livechat_channel_id`. Tên kênh lấy động từ `im_livechat.channel.name`. |
| **`discuss.channel.member`** | Quản lý các thành viên trong phiên: Khách hàng Portal (`res.partner`) + Operator nội bộ được phân bổ. |
| **`crm.lead`** | Bản ghi cơ hội bán hàng sinh ra từ Quick Action, trường `description` tự động kế thừa `_get_channel_history()`. |
| **`helpdesk.ticket`** | Bản ghi phiếu hỗ trợ sinh ra từ Quick Action, trường `description` tự động kế thừa `_get_channel_history()`. |

---

## IV. ĐẶC TẢ API CONTRACT (BACKEND `v_mobile`)

### 1. Endpoint: Mở / Lấy Phiên Live Chat Cho Portal User
* **URL**: `POST /api/v1/mobile/livechat/session`
* **Headers**: `Authorization: Bearer <jwt_token>`
* **Request Body**:
  ```json
  {
    "channel_alias": "customer_care",
    "web_session_uuid": "b7fbb80a-900e-410b-8e12-cskh360corp01"
  }
  ```
  *(Ghi chú: `channel_alias` nhận `customer_care` hoặc `technical_support`. `web_session_uuid` là tham số tùy chọn khi khách hàng muốn nối lại phiên chat dở trên Website).*
* **Response (200 OK / 201 Created)**:
  ```json
  {
    "success": true,
    "data": {
      "channel_id": 1420,
      "uuid": "b7fbb80a-900e-410b-8e12-cskh360corp01",
      "channel_name": "Customer Care",
      "channel_type": "livechat",
      "avatar_url": "/api/v1/mobile/avatar/im_livechat.channel/1?field=image_128",
      "is_operator_online": true,
      "operator": {
        "id": 3514,
        "name": "Tư vấn viên 01",
        "livechat_username": "Tư vấn viên 01",
        "avatar_url": "/api/v1/mobile/avatar/res.partner/3514?field=avatar_128"
      },
      "last_message": {
        "id": 9812,
        "author_name": "OdooBot",
        "body": "Dạ em xin chào Quý khách! Em có thể hỗ trợ gì cho anh/chị về dịch vụ 360 ạ?",
        "date": "2026-10-15T08:30:00Z"
      }
    }
  }
  ```

---

### 2. Endpoint: Tạo Cơ Hội Bán Hàng (CRM Lead) 1-Chạm
* **URL**: `POST /api/v1/mobile/crm/lead`
* **Headers**: `Authorization: Bearer <jwt_token>`
* **Request Body**:
  ```json
  {
    "channel_id": 1420,
    "title": "Khách hàng quan tâm báo giá dịch vụ Cloud"
  }
  ```
* **Logic Backend**:
  * Kiểm tra quyền truy cập vào `discuss.channel` ID 1420.
  * Tự động trích xuất toàn bộ lịch sử tin nhắn qua `channel._get_channel_history()`.
  * Tạo bản ghi `crm.lead`:
    - `name`: Tiêu đề do khách/nhân viên gửi hoặc mặc định `"Yêu cầu báo giá từ Live Chat"`.
    - `partner_id`: ID của khách hàng Portal (`me_partner.id`).
    - `description`: Toàn bộ nội dung hội thoại vừa trao đổi.
    - `source_id`: Nguồn Live Chat (`crm_livechat.utm_source_livechat`).
* **Response (200 OK)**:
  ```json
  {
    "success": true,
    "data": {
      "lead_id": 452,
      "lead_name": "Khách hàng quan tâm báo giá dịch vụ Cloud",
      "message": "Đã gửi yêu cầu báo giá thành công. Chuyên viên kinh doanh sẽ liên hệ trong ít phút!"
    }
  }
  ```

---

### 3. Endpoint: Tạo Phiếu Hỗ Trợ (Helpdesk Ticket) 1-Chạm
* **URL**: `POST /api/v1/mobile/helpdesk/ticket`
* **Headers**: `Authorization: Bearer <jwt_token>`
* **Request Body**:
  ```json
  {
    "channel_id": 1420,
    "title": "Báo sự cố kết nối thiết bị"
  }
  ```
* **Logic Backend**:
  * Tự động trích xuất toàn bộ lịch sử tin nhắn qua `channel._get_channel_history()`.
  * Tạo bản ghi `helpdesk.ticket`:
    - `name`: Tiêu đề sự cố.
    - `partner_id`: ID của khách hàng Portal (`me_partner.id`).
    - `description`: Toàn bộ nội dung hội thoại mô tả lỗi.
* **Response (200 OK)**:
  ```json
  {
    "success": true,
    "data": {
      "ticket_id": 1025,
      "ticket_code": "#TCK-1025",
      "message": "Đã ghi nhận phiếu hỗ trợ #TCK-1025. Kỹ sư kỹ thuật đang xử lý sự cố."
    }
  }
  ```

---

## V. ĐẶC TẢ CHI TIẾT GIAO DIỆN FRONTEND FLUTTER (`vclients`)

Ứng dụng Flutter triển khai chuẩn thiết kế công nghệ cao cấp **360 CORP (Tech Royal Blue `#0077cd` & Digital Green `#00ce2c`)**, loại bỏ hoàn toàn các asset hardcode (`branding/cskh_logo_360.png`, tích xanh MXH) để chuyển sang giao diện động 100% kết nối với Odoo Live Chat.

---

### 1. Sơ Đồ Giao Diện Trực Quan (UI Wireframes)

#### A. BottomSheet Chọn Kênh Hỗ Trợ (Support Channel Selection Sheet)
Mở ra khi khách hàng Portal chạm vào nút "Hỗ Trợ" trên Trang Chủ hoặc thanh điều hướng:

```text
┌─────────────────────────────────────────────────────────────┐
│ ─── (Drag Handle)                                           │
│                                                             │
│  TRUNG TÂM HỖ TRỢ TRỰC TUYẾN                           [✕]  │
│  Vui lòng chọn bộ phận tiếp nhận để được hỗ trợ tốt nhất    │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 🟢 Customer Care (CSKH & Kinh Doanh)                  │  │
│  │    Tư vấn sản phẩm, chính sách giá, hợp đồng dịch vụ  │  │
│  │    và nhận báo giá ưu đãi độc quyền 360 CORP.         │  │
│  │    ────────────────────────────────────────────────── │  │
│  │    🟢 Đang có chuyên viên trực ca • Phản hồi ~2 phút  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ 🛠️ Technical Support (Hỗ Trợ Kỹ Thuật)                │  │
│  │    Báo lỗi phần mềm, hướng dẫn vận hành hệ thống,     │  │
│  │    khắc phục sự cố kỹ thuật và đồng bộ dữ liệu.       │  │
│  │    ────────────────────────────────────────────────── │  │
│  │    🟢 Kỹ sư kỹ thuật trực tuyến • Tiếp nhận 24/7      │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

#### B. Màn Hình Hội Thoại Chi Tiết (`ChatV2DetailScreen`)
Sau khi chọn kênh, chuyển hướng vào màn hình chat Live Chat chuẩn:

```text
┌─────────────────────────────────────────────────────────────┐
│ [◀]  (Avatar)  Customer Care                        [ⓘ] [⋮] │
│      Odoo      🟢 Đang trực ca                              │
├─────────────────────────────────────────────────────────────┤
│ (Banner nếu ngoài giờ: 🌙 Ca trực kết thúc, để lại tin...)   │
│                                                             │
│      [10:30]                                                │
│  ┌───────────────┐                                          │
│  │ 🤖 OdooBot    │ Dạ em xin chào anh Tân! Em là trợ lý     │
│  └───────────────┘ tự động của 360 CORP. Em có thể hỗ trợ gì│
│                    cho anh hôm nay ạ?                       │
│                                                       10:30 │
│                                                             │
│                             ┌────────────────────────────┐  │
│                             │ Tôi cần tư vấn gói phần mềm│  │
│                             │ Odoo cho 50 nhân sự nhé!   │  │
│                             └────────────────────────────┘  │
│                                                       10:31 │
│  ┌───────────────┐                                          │
│  │ 👨‍💼 Tư vấn 01  │ Dạ em chào anh Tân! Em là chuyên viên tư │
│  └───────────────┘ vấn của 360. Em gửi anh báo giá ngay ạ.  │
│                                                       10:32 │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│ [⭐ Nhận báo giá (CRM Lead)]     [🎫 Gửi yêu cầu hỗ trợ]    │  <-- Thanh Quick Actions cố định
├─────────────────────────────────────────────────────────────┤
│ [+]  Nhập tin nhắn hỗ trợ...                         [ 🎙️ ] [ ➤ ] │
└─────────────────────────────────────────────────────────────┘
```

---

#### C. Thẻ Xác Nhận Hành Động Nhanh (Quick Action Confirmation Toast / Card)
Khi khách bấm vào 1 trong 2 nút Quick Action trên thanh tiện ích:

* **Khi bấm `[⭐ Nhận báo giá]`**:
  * Hiển thị BottomSheet xác nhận ngắn:
    ```text
    ┌─────────────────────────────────────────────────────────┐
    │ ⭐ GỬI YÊU CẦU BÁO GIÁ NHANH                            │
    │ Hệ thống sẽ chuyển toàn bộ nội dung trao đổi vừa rồi    │
    │ thành Cơ Hội Bán Hàng gửi riêng cho Chuyên viên Kinh    │
    │ doanh liên hệ với bạn kèm bảng giá chi tiết.            │
    │                                                         │
    │ [ Hủy ]                       [ Xác nhận gửi yêu cầu ]  │
    └─────────────────────────────────────────────────────────┘
    ```
  * Sau khi gửi thành công: Ngay trong phòng chat tự động xuất hiện 1 thẻ thông báo chuyên nghiệp:
    ```text
    ┌─────────────────────────────────────────────────────────┐
    │ 📢 THÔNG BÁO HỆ THỐNG                                   │
    │ ✅ Đã khởi tạo Cơ hội Báo giá thành công!                │
    │ Mã hồ sơ: #LEAD-2026-089                                │
    │ Chuyên viên kinh doanh đang chuẩn bị báo giá cho bạn.   │
    └─────────────────────────────────────────────────────────┘
    ```

* **Khi bấm `[🎫 Gửi yêu cầu hỗ trợ]`**:
  * Hiển thị form ngắn 1 trường: *"Tóm tắt sự cố (nếu có)"* hoặc bấm Gửi ngay.
  * Phản hồi thẻ Ticket trong chat:
    ```text
    ┌─────────────────────────────────────────────────────────┐
    │ 🎫 PHIẾU HỖ TRỢ KỸ THUẬT                                │
    │ Mã phiếu: #TCK-1025                                     │
    │ Trạng thái: Đang tiếp nhận (In Progress)                │
    │ Kỹ sư phần mềm đang kiểm tra log hệ thống.              │
    └─────────────────────────────────────────────────────────┘
    ```

---

### 2. Phân Tách Cấu Trúc Thành Phần Giao Diện (Widget Hierarchy)

```text
ChatV2DetailScreen
├── LiveChatAppBar (Custom PreferredSizeWidget)
│   ├── Leading: IconButton (Back)
│   ├── TitleArea: Row
│   │   ├── LiveChatChannelAvatar (Network Image Odoo image_128 + Fallback Icon)
│   │   └── Column
│   │       ├── ChannelTitleText (Dynamic Name: "Customer Care" / "Technical Support")
│   │       └── LiveChatStatusIndicator (Chấm xanh 🟢 + "Đang trực ca" / "Ngoại tuyến")
│   └── Actions: [IconButton(Info)]
│
├── LiveChatBodyArea (Expanded)
│   ├── OfflineNoticeBanner (Hiển thị có điều kiện nếu is_operator_online == false)
│   └── MessageListView
│       ├── ChatBotMessageBubble (Avatar OdooBot + Badge Bot + Bubble xám nhạt)
│       ├── OperatorMessageBubble (Avatar Operator + Tên livechat_username + Bubble trắng)
│       ├── CustomerMessageBubble (Bubble xanh Tech Royal Blue #0077cd + Text trắng)
│       └── SystemNotificationCard (Render thẻ xác nhận Lead #LEAD-xxx / Ticket #TCK-xxx)
│
├── LiveChatQuickActionsBar (SizedBox cố định chiều cao 44dp, padding horizontal 12)
│   └── ListView (Cuộn ngang nếu màn hình nhỏ)
│       ├── QuickActionChip (Icon: LucideIcons.star, Label: "Nhận báo giá", Primary Tint)
│       └── QuickActionChip (Icon: LucideIcons.ticket, Label: "Gửi yêu cầu hỗ trợ", Accent Tint)
│
└── LiveChatMessageComposer (Chat Composer chuẩn)
    ├── AttachmentButton (Upload ảnh / tài liệu đính kèm)
    ├── MessageTextField (Auto-expand max 4 dòng)
    └── SendButton (Animated Icon khi có text)
```

---

### 3. Quy Chuẩn Màu Sắc, Phông Chữ & Tokens Giao Diện (Design Tokens)

* **Bảng màu chủ đạo**:
  * **Primary (Thương hiệu chính)**: `#0077cd` (Tech Royal Blue — dùng cho nút gửi, card active, bubble tin nhắn của khách, viền thẻ CSKH).
  * **Success / Online (Trạng thái ca trực)**: `#00ce2c` (Digital Green — dùng cho chấm đèn 🟢 Online Indicator, tag badge tiếp nhận).
  * **Warning / Lead**: `#f59e0b` (Amber 500 — dùng cho icon nhận báo giá và thẻ Lead).
  * **Info / Ticket**: `#3b82f6` (Blue 500 — dùng cho icon phiếu hỗ trợ Helpdesk).
  * **Nền giao diện (Surface)**: `#f8fafc` (Slate 50 — nền màn hình chat sạch sẽ, chống mỏi mắt).
  * **Văn bản (Typography Contrast)**:
    * Tiêu đề chính: Slate 900 (`#0f172a`), font-weight: `w600`.
    * Phụ đề & trạng thái: Slate 600 (`#475569`), font-size: `12sp`.
    * Nội dung tin nhắn: Slate 800 (`#1e293b`), line-height: `1.4`.
* **Quy chuẩn Bo góc & Khoảng cách (Spacings)**:
  * Thẻ chọn kênh: `BorderRadius.circular(16)`.
  * Bubble tin nhắn: `BorderRadius.circular(16)` với góc nhọn 4dp ở phía người gửi.
  * Chip Quick Action: `BorderRadius.circular(20)` (Pill shape), viền `1dp` màu `#cbd5e1`.

---

### 4. Quản Lý Trạng Thái Giao Diện Bằng Riverpod (State Management)

1. **`liveChatChannelProvider`**:
   * Quản lý trạng thái khởi tạo phiên từ API `POST /api/v1/mobile/livechat/session`.
   * Cung cấp các cờ phản ứng UI: `isLoading`, `channelId`, `isOperatorOnline`, `channelName`, `operatorName`.
2. **`quickActionControllerProvider`**:
   * Quản lý các đột biến thao tác nhanh (Mutation):
     - `createCrmLead(channelId, note)`: Hiển thị loading spinner trên chip, sau khi thành công tự động chèn 1 bản ghi tin nhắn hệ thống vào danh sách chat.
     - `createHelpdeskTicket(channelId, note)`: Hiển thị thông báo mã `#TCK-xxx` và mở rộng thông tin theo dõi.
3. **Web-to-Mobile Continuity Listener**:
   * Khi khởi động App: Nếu trong bộ nhớ tạm (`FlutterSecureStorage`) có lưu `web_session_uuid` từ lần quét QR hoặc đăng nhập Portal, App tự động nạp phiên cũ và nhảy vào phòng chat mà không bắt khách chọn lại từ đầu.

---

## VI. BỘ 10 CASE KIỂM THỬ ĐỘC LẬP (VERIFICATION TEST MATRIX)

| Mã Case | Tình huống kiểm thử | Hành vi mong đợi | Tiêu chuẩn Đạt |
|---|---|---|:---:|
| **TC-01** | Khách chọn kênh `Customer Care` trên Mobile | Khởi tạo phiên Live Chat với `channel_type = 'livechat'`. | ĐẠT |
| **TC-02** | Khách chọn kênh `Technical Support` trên Mobile | Khởi tạo phiên Live Chat phân bổ tới kỹ thuật viên trực ca. | ĐẠT |
| **TC-03** | Đối soát menu `/home/livechat` trên Odoo Web | Số lượng phiên Live Chat tăng lên (`>= 1 Sessions`), chấm dứt lỗi 0 Sessions. | ĐẠT |
| **TC-04** | Hiển thị trong Odoo Discuss của nhân viên | Phiên chat xuất hiện tại mục **`Looking for help`** của Operator trực ca. | ĐẠT |
| **TC-05** | Nhận diện tiêu đề Header trên App Mobile | Header hiển thị đúng tên kênh từ Odoo, không bị gán cứng chữ "Chăm Sóc Khách Hàng 360". | ĐẠT |
| **TC-06** | Trạng thái trực ca của nhân viên | Hiển thị chấm xanh trực tuyến 🟢 khi Operator online; chuyển xám khi không có ai trực. | ĐẠT |
| **TC-07** | Nhận diện danh tính người phản hồi | Hiển thị `OdooBot` hoặc `livechat_username`, không làm lộ thông tin cá nhân nội bộ. | ĐẠT |
| **TC-08** | Khách bấm nút Quick Action "Nhận báo giá" | Tạo thành công `crm.lead`, phần mô tả của Lead có đầy đủ nội dung đoạn chat. | ĐẠT |
| **TC-09** | Khách bấm nút Quick Action "Gửi yêu cầu hỗ trợ"| Tạo thành công `helpdesk.ticket`, mô tả phiếu nhúng trọn vẹn lịch sử đoạn chat. | ĐẠT |
| **TC-10** | Đồng bộ phiên từ Web sang App (Session Continuity)| Khách chat trên web, đăng nhập vào App Mobile thấy lại toàn bộ tin nhắn cũ. | ĐẠT |
