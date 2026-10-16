# ĐẶC TẢ KỸ THUẬT (SPEC) — HỆ THỐNG LIVE CHAT OMNICHANNEL & PORTAL SUPPORT CHUẨN ODOO ENTERPRISE

> **Mã tài liệu**: `docs/SPEC_PORTAL_SUPPORT_CHANNEL.md`  
> **Hệ thống gốc**: Odoo Enterprise (Module `im_livechat`, `mail.discuss`, `crm_livechat`, `website_helpdesk_livechat`)  
> **Nền tảng đồng bộ**: VCloud Mobile App (Flutter `vclients`) ⟷ Backend Addon `v_mobile` (Odoo 17 & 19)  
> **Thẩm định & Phê duyệt**: Sếp Tân — 360 CORP  
> **Trạng thái**: Chuẩn hóa 100% theo Odoo Core (Áp dụng nguyên tắc Ponytail & YAGNI, Tuyệt đối KHÔNG chế tính năng hay API ngoài chuẩn Odoo)  
> **Cập nhật lần cuối**: 2026-10-15  

---

## I. MỤC TIÊU & PHẠM VI (GOALS & SCOPE)

### 1. Mục tiêu cốt lõi
1. **Khắc phục triệt để lỗi 0 Sessions**: Chuyển từ cơ chế chat 1-1 với Admin hoặc nhóm tự chế (`channel_type: 'group'`) sang phiên Live Chat chuẩn Odoo (`channel_type: 'livechat'`), ghi nhận chính xác số ca trực thực tế trên menu `/home/livechat`.
2. **Kế thừa 100% hạ tầng Odoo Discuss**: Đưa tin nhắn của khách hàng từ cả Website và App Mobile vào đúng mục **`Looking for help`** trong Odoo Discuss để nhân viên trong ca trực tiếp nhận theo thời gian thực.
3. **Chuyển giao phiên liền mạch (Session Continuity)**: Khách trao đổi trên Web Live Chat, khi đăng nhập vào Portal App Mobile trên điện thoại sẽ kế thừa trọn vẹn toàn bộ lịch sử tin nhắn cũ.
4. **Chuyển đổi nghiệp vụ chuẩn Odoo Core (Chat ➔ Business)**: Kế thừa 100% cơ chế chuẩn Odoo `crm_livechat` (lệnh `/lead`) và `website_helpdesk_livechat` (lệnh `/ticket`). Operator trực ca gõ lệnh slash command trên Odoo Discuss hoặc Chatbot tự động chuyển đổi, lịch sử chat tự động nhúng vào mô tả. Khách hàng trên Mobile không phải làm thay việc của nhân viên và không bị ép tương tác với các nút bấm tự chế.

### 2. Danh mục các ý tưởng sai & tính năng tự chế bị loại bỏ hoàn toàn (Deprecated & Removed)
Theo chỉ đạo và rà soát đối soát thực tế với Odoo 17, Odoo 19 và `vuahethong.net`, các cách làm sau **bị loại bỏ hoàn toàn khỏi kiến trúc**:
* ❌ **Bỏ các nút bấm Quick Action trên Mobile (`[⭐ Nhận báo giá]`, `[🎫 Gửi yêu cầu hỗ trợ]`)**: Trong Odoo chuẩn nguyên bản, khách hàng chỉ là người chat trao đổi nhu cầu. Việc tạo Lead vào CRM hay Ticket vào Helpdesk là nghiệp vụ nội bộ của Operator hoặc Chatbot, khách hàng không tự bấm nút tạo Lead trong CRM.
* ❌ **Bỏ 2 Endpoint REST API tự tạo (`POST /api/v1/mobile/crm/lead` và `POST /api/v1/mobile/helpdesk/ticket`)**: Odoo Core không dùng client REST để tạo Lead/Ticket từ livechat. Loại bỏ hoàn toàn để không chế API thừa thãi.
* ❌ **Bỏ tham số tự chế `channel_alias`**: Odoo Core định danh kênh Live Chat bằng **`channel_id`** (Integer bản ghi `im_livechat.channel`), hoàn toàn không có trường alias. Sử dụng API lấy danh sách kênh `GET /api/v1/mobile/livechat/channels` và mở phiên bằng `channel_id`.
* ❌ **Bỏ thẻ hệ thống "SystemNotificationCard" trong khung chat khách**: Khi Operator gõ `/lead` hoặc `/ticket`, Odoo chỉ gửi thông báo riêng (transient message) cho nhân viên trên Odoo Discuss, không spam thẻ nội bộ vào khung chat của khách hàng.
* ❌ **Bỏ chat 1-1 với cá nhân Admin (`channel_type: 'chat'`)**: Gây nghẽn tại 1 tài khoản, các nhân viên trực ca không nhìn thấy.
* ❌ **Bỏ tạo kênh nhóm tự chế (`channel_type: 'group'`) rồi gán cứng nhân viên tĩnh**: Phá vỡ cơ chế xoay ca trực của Live Chat.
* ❌ **Bỏ gộp chung 1 kênh không phân loại nhu cầu**: Gây chồng chéo giữa tư vấn bán hàng và hỗ trợ kỹ thuật.
* ❌ **Bỏ hardcode điều hướng 1-chạm ép Portal User vào thẳng 1 phòng chat duy nhất**: Trước đây khi Portal User bấm vào mục Chat ở sidebar, app bị hardcode tự động ép nhảy thẳng vào phòng chat duy nhất "Chăm Sóc Khách Hàng 360", tước đoạt quyền xem danh sách các hội thoại khác và nút Back bị ép quay về `/home`. Quy chuẩn mới: Portal User mở danh sách hội thoại (`ChatV2ListScreen`), thấy toàn bộ các kênh Live Chat đã mở ("Technical Support", "Customer Care"...) và mở kênh mới qua nút "Hỗ trợ trực tuyến".
* ❌ **Bỏ cơ chế gán đè tên Operator ("Admin") lên tiêu đề kênh Live Chat của Portal User**: Trong Odoo, kênh Live Chat là kênh hỗ trợ phòng ban/dịch vụ chuyên trách. Việc hiển thị tên cá nhân của chuyên viên tiếp nhận (như "Mitchell Admin" hay "Admin") là sai lệch bản chất dịch vụ. Phía Portal User luôn phải nhìn thấy tên bộ phận tiếp nhận ("Technical Support", "Customer Care") kèm Avatar của kênh Live Chat.
* ❌ **Bỏ hardcode tên kênh ("Chăm Sóc Khách Hàng 360") và tích xanh MXH tự chế**: Tên kênh và avatar bắt buộc lấy **động 100% từ Odoo Backend** (`im_livechat.channel`); trạng thái trực ca dùng chấm xanh trực tuyến (**🟢 Online Indicator**).
* ❌ **Bỏ triệt tiêu danh tính người trực (ép hiển thị logo vô danh)**: Chuẩn Odoo bảo mật danh tính qua trường `livechat_username` trong User Profile (hoặc `OdooBot`).
* ❌ **Bỏ câu trả lời mẫu (`mail.shortcode`)**: Trên `vuahethong.net` chưa cấu hình danh mục câu mẫu thực tế ➔ Không đưa vào (YAGNI).
* ❌ **Bỏ đánh giá Rating / Sao (`rating.rating`) & gửi email transcript**: Tối giản luồng chat, tập trung hỗ trợ nhanh (YAGNI).
* ❌ **Bỏ gọi thoại / gọi video WebRTC (`discuss.call`)**: Tránh phình to phạm vi giải pháp (YAGNI).

---

## II. HAI TRỤ CỘT KIẾN TRÚC DUY NHẤT (THE 2 CORE PILLARS)

Hệ thống được đóng gói tinh gọn xoay quanh **đúng 2 trụ cột nghiệp vụ chuẩn Odoo Core**:

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        TRỤ CỘT 1: LIVE CHAT SESSIONS & PHÂN LUỒNG                      │
│                                                                                        │
│   Khách hàng Portal ───► Chọn kênh hỗ trợ ───► Tạo discuss.channel (type: livechat)    │
│   (Mobile App)           (im_livechat.channel)              │                          │
│                                                             ▼                          │
│                                         Phân bổ tới Operator online trong              │
│                                         mục "Looking for help" trên Odoo Discuss       │
│                                         (Đếm đúng số Sessions tại /home/livechat)      │
└───────────────────────────────────────────┬────────────────────────────────────────────┘
                                            │
                                            ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│             TRỤ CỘT 2: CHUYỂN ĐỔI NGHIỆP VỤ CHUẨN ODOO CORE (SLASH COMMANDS)           │
│                                                                                        │
│   Operator gõ /lead   ───► Odoo crm_livechat tạo crm.lead (Bốc tự động Chat History)   │
│   Operator gõ /ticket ───► Odoo website_helpdesk_livechat tạo helpdesk.ticket          │
│   (Hoặc Chatbot Step) ───► Tự động tạo Lead/Ticket qua kịch bản Chatbot Odoo Core      │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## III. ĐẶC TẢ MÔ HÌNH DỮ LIỆU ODOO (DATA MODELS)

| Model kỹ thuật | Vai trò & Quy cách sử dụng chuẩn Odoo Core |
|---|---|
| **`im_livechat.channel`** | Cấu hình các kênh hỗ trợ của tổ chức: `Customer Care` (CSKH / Bán hàng) và `Technical Support` (Kỹ thuật). Quản lý danh sách Operator trực ca (`user_ids`), ảnh đại diện (`image_128`), kịch bản Chatbot (`chatbot_script_id`). |
| **`discuss.channel`** | Bản ghi phiên hội thoại. Bắt buộc: `channel_type = 'livechat'`, liên kết `livechat_channel_id`. Tên kênh sinh tự động từ logic Odoo Core `_get_livechat_discuss_channel_vals(...)`. |
| **`discuss.channel.member`** | Quản lý các thành viên trong phiên: Khách hàng Portal (`res.partner`) + Operator nội bộ được phân bổ. |
| **`crm.lead`** | Bản ghi cơ hội bán hàng sinh ra từ lệnh `/lead` của Operator trong Odoo Discuss hoặc Chatbot Step `create_lead` (`crm_livechat`). Trường `description` tự động nhúng trọn vẹn `_get_channel_history()`. |
| **`helpdesk.ticket`** | Bản ghi phiếu hỗ trợ sinh ra từ lệnh `/ticket` của Operator trong Odoo Discuss hoặc Chatbot Step `create_ticket` (`website_helpdesk_livechat`). Trường `description` tự động nhúng trọn vẹn `_get_channel_history()`. |

---

## IV. ĐẶC TẢ API CONTRACT (BACKEND `v_mobile`)

Toàn bộ API được thiết kế dựa trên các phương thức có sẵn của Odoo Core, tuyệt đối không tạo endpoint thừa.

### 1. Endpoint: Lấy Danh Sách Kênh Live Chat
* **URL**: `GET /api/v1/mobile/livechat/channels`
* **Headers**: `Authorization: Bearer <jwt_token>`
* **Logic Backend**:
  * Đọc các bản ghi `im_livechat.channel` đang active trong hệ thống.
  * Kiểm tra danh sách Operator đang online (`available_operator_ids`).
* **Response (200 OK)**:
  ```json
  {
    "success": true,
    "data": [
      {
        "id": 1,
        "name": "Customer Care",
        "description": "Tư vấn sản phẩm, chính sách giá, hợp đồng dịch vụ",
        "avatar_url": "/api/v1/mobile/avatar/im_livechat.channel/1?field=image_128",
        "is_available": true,
        "default_message": "Dạ em xin chào Quý khách! Em có thể hỗ trợ gì cho anh/chị ạ?"
      },
      {
        "id": 2,
        "name": "Technical Support",
        "description": "Báo lỗi phần mềm, hướng dẫn vận hành, khắc phục sự cố kỹ thuật",
        "avatar_url": "/api/v1/mobile/avatar/im_livechat.channel/2?field=image_128",
        "is_available": true,
        "default_message": "Chào bạn! Bộ phận kỹ thuật sẵn sàng hỗ trợ xử lý sự cố."
      }
    ]
  }
  ```

---

### 2. Endpoint: Mở / Lấy Phiên Live Chat Cho Portal User
* **URL**: `POST /api/v1/mobile/livechat/session`
* **Headers**: `Authorization: Bearer <jwt_token>`
* **Request Body**:
  ```json
  {
    "channel_id": 1,
    "web_session_uuid": "b7fbb80a-900e-410b-8e12-cskh360corp01"
  }
  ```
  *(Ghi chú: `channel_id` là ID bản ghi `im_livechat.channel` chuẩn Odoo. `web_session_uuid` là tham số tùy chọn khi khách muốn nối lại phiên chat dở trên Website).*
* **Logic Backend (Gọi trực tiếp Odoo Core)**:
  * Xác thực JWT token của Portal User ➔ lấy `user_id` và `partner_id`.
  * Nếu có `web_session_uuid`: Tìm `discuss.channel` có `uuid` tương ứng và liên kết thêm `partner_id` của khách hàng vào kênh.
  * Nếu không có hoặc phiên cũ đã đóng: Gọi hàm Odoo Core `im_livechat.channel.browse(channel_id)._get_livechat_discuss_channel_vals(...)` với `user_id=uid`.
  * Tạo bản ghi `discuss.channel` chuẩn với `channel_type = 'livechat'`.
  * Trả về thông tin phiên hội thoại.
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

### 3. Gửi & Nhận Tin Nhắn Hội Thoại
* **API Sử Dụng**: Tái sử dụng 100% các API chat sẵn có của `v_mobile`:
  * Gửi tin nhắn: `POST /api/v1/mobile/chat/messages` với `channel_id` của phiên livechat.
  * Đọc lịch sử tin nhắn: `GET /api/v1/mobile/chat/channels/<channel_id>/messages`.
* **Tuyệt đối không tạo API riêng**: Không cần thêm bất kỳ endpoint gửi/nhận tin nhắn đặc thù nào cho Livechat vì `discuss.channel` là mô hình cốt lõi dùng chung cho toàn bộ hệ thống Discuss của Odoo.

---

### 4. Chuẩn Hóa Danh Sách Hội Thoại & Phân Định Góc Nhìn Hai Chiều (Role-Based Perspective Parity)

#### A. Nguyên nhân gốc rễ lỗi hiển thị tên "Admin"
Trong Odoo, phiên Live Chat được lưu dưới dạng `discuss.channel` với `channel_type: 'livechat'`, có 2 thành viên: Khách hàng Portal (`res.partner` của portal user) và Chuyên viên tiếp nhận (`livechat_operator_id`, thường là Mitchell Admin trong môi trường kiểm thử).
* **Lỗi Backend cũ**: API `list_channels` và `channel_info` gom kênh 2 thành viên thành `is_direct = True` (chat 1-1 cá nhân), trích xuất `other_partner_dict` ("Mitchell Admin") và gán vào `partner_id` / `direct_partner`.
* **Lỗi Frontend cũ**: Class `ChatV2Channel` trên Flutter khi thấy `directPartnerName != null` thì luôn ưu tiên ghi đè tên kênh bằng `directPartnerName` ("Mitchell Admin"), dẫn tới việc khách chọn "Technical Support" hay "Customer Care" đều bị biến thành "Mitchell Admin".

#### B. Ma trận góc nhìn hai chiều chuẩn Odoo Enterprise (Perspective Parity Matrix)

| Thuộc tính | 👤 Góc nhìn Khách Hàng (Portal User) | 👨‍💼 Góc nhìn Chuyên Viên Trực Ca (Operator / Admin) |
|---|---|---|
| **Bản chất kênh** | Kênh dịch vụ tiếp nhận hỗ trợ chuyên trách | Phiên hỗ trợ tiếp nhận yêu cầu từ khách hàng bên ngoài |
| **Tên kênh (`name`)** | Tên dịch vụ Live Chat (`livechat_channel_id.name`, e.g. **"Customer Care"**, **"Technical Support"**) | Tên khách hàng kèm tên phòng ban Livechat: **`${portal_partner_name} • ${service_name}`** (e.g. **"Khách Hàng Mới • Technical Support"**). Không để trơ trọi tên khách tránh Admin không biết khách gọi vào bộ phận nào. |
| **Phòng ban Livechat (`department_name`)** | Tên phòng ban (`livechat_channel_id.name`) | Tên phòng ban (`livechat_channel_id.name`) để hiển thị badge phân loại |
| **Ảnh đại diện (`avatar_url`)** | Avatar chuyên biệt theo phòng ban (`im_livechat.channel` image_128 hoặc icon nhận diện: Tai nghe cho CSKH, Cờ lê cho Kỹ thuật) | Avatar của khách hàng Portal (`res.partner` avatar_128) |
| **Định danh 1-1 (`direct_partner`)** | `None` (Tuyệt đối không gán `partner_id` của Admin) | `{ "id": portal_p.id, "name": portal_p.name, ... }` |
| **Kênh Chat 1-1 (`channel_type: 'chat'`)** | Tên chuyên viên tư vấn phụ trách (hoặc tên đối tác) | Tên khách hàng đối tác (`other_partner`), **tuyệt đối KHÔNG trả về tên của chính Admin** |
| **Nhãn phân loại (Badge / Tag)** | Badge phòng ban (`Hỗ trợ kỹ thuật` / `Chăm sóc KH`), **không dùng tag `CSKH` nhóm** | Badge Livechat chuyên trách kèm tên bộ phận, **không dùng tag `CSKH` nhóm nội bộ** |
| **Trạng thái trực (`im_status`)** | Trạng thái ca trực của bộ phận (`online` nếu có operator online) | Trạng thái online của khách hàng Portal |

#### C. Quy chuẩn Payload API Backend (`/api/v1/mobile/chat/channels`)
```python
is_livechat = bool(ch.channel_type == "livechat" or (hasattr(ch, "livechat_channel_id") and ch.livechat_channel_id))
is_group = bool(ch.channel_type in ("channel", "group") or total_member_count > 2)
is_direct = bool(not is_group and not is_livechat)

if is_livechat:
    livechat_ch = ch.livechat_channel_id
    service_name = livechat_ch.name if livechat_ch else (ch.name or "Hỗ trợ trực tuyến")
    department_id = livechat_ch.id if livechat_ch else False
    if is_portal_user:
        channel_name = service_name
        avatar_url = _avatar_url_for(env, "im_livechat.channel", department_id, field="image_128")
        direct_partner = None
        partner_id = None
    else:
        # Operator / Admin view: Phải có tên phòng ban để phân loại
        channel_name = f"{portal_p['name']} • {service_name}"
        avatar_url = portal_p["avatar_url"]
        direct_partner = { "id": portal_p["id"], "name": portal_p["name"], ... }
elif is_direct:
    # Chat 1-1 cá nhân: other_partner BẮT BUỘC là người đối diện, KHÔNG được là chính mình
    other_p = _resolve_other_partner(ch, current_user.partner_id)
    channel_name = other_p["name"]
    avatar_url = other_p["avatar_url"]
    direct_partner = other_p
```

---

## V. ĐẶC TẢ CHI TIẾT GIAO DIỆN FRONTEND FLUTTER (`vclients`)

Ứng dụng Flutter triển khai chuẩn thiết kế công nghệ cao cấp **360 CORP (Tech Royal Blue `#0077cd` & Digital Green `#00ce2c`)**, loại bỏ hoàn toàn các asset hardcode (`branding/cskh_logo_360.png`, tích xanh MXH) và loại bỏ toàn bộ các nút bấm Quick Action tự chế.

---

### 1. Sơ Đồ Giao Diện Trực Quan (UI Wireframes)

#### A0. Màn Hình Danh Sách Hội Thoại (`ChatV2ListScreen` — Portal View)
Khi khách hàng Portal bấm vào mục **Chat** tại thanh điều hướng / Sidebar, ứng dụng hiển thị danh sách toàn bộ các kênh trao đổi đã mở (không tự ý ép vào phòng chat duy nhất), thanh Filter Chips tự động ẩn các danh mục không có dữ liệu (Nhóm, Kênh, Zalo OA), cùng nút nổi **"Hỗ trợ trực tuyến"** để mở phiên mới:

```text
┌─────────────────────────────────────────────────────────────┐
│ [☰]  Trò chuyện                                       [🔍]  │
├─────────────────────────────────────────────────────────────┤
│ [ Tất cả 3 ]  [ Chưa đọc 1 ]  [ Hỗ trợ 2 ]  [ Trực tiếp 1 ]   │
│ (Tự động ẩn các tab Nhóm, Kênh, Zalo OA vì count = 0)       │
├─────────────────────────────────────────────────────────────┤
│ ┌─── Danh sách hội thoại ─────────────────────────────────┐ │
│ │ 🛠️  Technical Support                              10:35 │ │
│ │ 🟢 Odoo           Kỹ thuật viên 01: Đã cấu hình xong...  │ │
│ │─────────────────────────────────────────────────────────│ │
│ │ 🎧  Customer Care                                  09:15 │ │
│ │ 🟢 Odoo           Tư vấn viên 02: Bảng báo giá gửi anh...│ │
│ │─────────────────────────────────────────────────────────│ │
│ │ 👤  Chuyên viên Tân (360 CORP)                   Hôm qua │ │
│ │     ✓ Bạn: Cảm ơn anh đã tư vấn nhiệt tình              │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│                                                             │
│                                   ┌───────────────────────┐ │
│                                   │ [🎧] Hỗ trợ trực tuyến │ │
│                                   └───────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

#### A0_admin. Màn Hình Danh Sách Hội Thoại (`ChatV2ListScreen` — Admin/Operator/CSKH/Kỹ Thuật View)
Khi chuyên viên nội bộ / CSKH / Kỹ thuật đăng nhập, danh sách hội thoại hiển thị đầy đủ 7 Filter Chips chuẩn, có định danh phòng ban và đối tác rõ ràng, chấm dứt tình trạng trùng lặp tên hoặc hiện ngược tên mình:

```text
┌─────────────────────────────────────────────────────────────┐
│ [☰]  Trò chuyện                                       [🔍]  │
├─────────────────────────────────────────────────────────────┤
│ [Tất cả 85] [Chưa đọc 12] [Trực tiếp 5] [Nhóm 3]           │
│ [Kênh 2]    [ Hỗ trợ 2 ]  [ Zalo OA 73 ]                   │
│                    └── Badge xanh Royal Blue (#0077CD)     │
├─────────────────────────────────────────────────────────────┤
│ ┌─── Danh sách hội thoại ─────────────────────────────────┐ │
│ │ 👤 Khách Hàng Mới • Technical Support             10:35 │ │
│ │ [🛠️ Hỗ trợ]   ✓ Bạn: Em đang kiểm tra kết nối...        │ │
│ │─────────────────────────────────────────────────────────│ │
│ │ 👤 Công Ty DAVITA • Customer Care                 09:15 │ │
│ │ [🎧 Hỗ trợ]   Khách: Bên mình muốn mở rộng thêm user... │ │
│ │─────────────────────────────────────────────────────────│ │
│ │ 👥 DAVITA Support [CSKH]                          08:30 │ │
│ │    Kiệt: Anh em cập nhật tiến độ sprint nhé             │ │
│ │─────────────────────────────────────────────────────────│ │
│ │ 💬 Khách Zalo - Nguyễn Văn A (Zalo OA)           Hôm qua │ │
│ │    Khách: Shop tư vấn giúp em sản phẩm này              │ │
│ │─────────────────────────────────────────────────────────│ │
│ │ 👤 Khách Hàng Mới (Direct Chat 1-1)              Thứ 4  │ │
│ │    (Không có badge Hỗ trợ, partner = Khách Hàng Mới)    │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│                                                       [ + ] │
└─────────────────────────────────────────────────────────────┘
```

#### A. BottomSheet Chọn Kênh Hỗ Trợ (Support Channel Selection Sheet)
Mở ra khi khách hàng Portal chạm vào nút "Hỗ Trợ" trên Trang Chủ hoặc thanh điều hướng (Dữ liệu load động từ `GET /api/v1/mobile/livechat/channels`):

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
│  │    và giải đáp thông tin ưu đãi 360 CORP.             │  │
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
Sau khi chọn kênh, chuyển hướng vào màn hình chat Live Chat chuẩn nguyên bản (Thanh thoát, không có nút bấm tự chế):

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
│  └───────────────┘ vấn của 360. Em hỗ trợ gửi anh thông tin │
│                    báo giá chi tiết ngay đây ạ.             │
│                                                       10:32 │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│ [+]  Nhập tin nhắn hỗ trợ...                         [ 🎙️ ] [ ➤ ] │
└─────────────────────────────────────────────────────────────┘
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
│       └── CustomerMessageBubble (Bubble xanh Tech Royal Blue #0077cd + Text trắng)
│
└── LiveChatMessageComposer (Chat Composer chuẩn)
    ├── AttachmentButton (Upload ảnh / tài liệu đính kèm)
    ├── MessageTextField (Auto-expand max 4 dòng)
    └── SendButton (Animated Icon khi có text)
```

---

### 3. Quy Chuẩn Màu Sắc, Phông Chữ & Tokens Giao Diện (Design Tokens)

* **Bảng màu chủ đạo**:
  * **Primary (Thương hiệu chính)**: `#0077cd` (Tech Royal Blue — dùng cho nút gửi, card active, bubble tin nhắn của khách).
  * **Success / Online (Trạng thái ca trực)**: `#00ce2c` (Digital Green — dùng cho chấm đèn 🟢 Online Indicator).
  * **Nền giao diện (Surface)**: `#f8fafc` (Slate 50 — nền màn hình chat sạch sẽ, chống mỏi mắt).
  * **Văn bản (Typography Contrast)**:
    * Tiêu đề chính: Slate 900 (`#0f172a`), font-weight: `w600`.
    * Phụ đề & trạng thái: Slate 600 (`#475569`), font-size: `12sp`.
    * Nội dung tin nhắn: Slate 800 (`#1e293b`), line-height: `1.4`.
* **Quy chuẩn Bo góc & Khoảng cách (Spacings)**:
  * Thẻ chọn kênh: `BorderRadius.circular(16)`.
  * Bubble tin nhắn: `BorderRadius.circular(16)` với góc nhọn 4dp ở phía người gửi.

---

### 4. Quản Lý Trạng Thái Giao Diện Bằng Riverpod (State Management)

1. **`liveChatChannelListProvider`**:
   * Gọi API `GET /api/v1/mobile/livechat/channels`.
   * Cung cấp danh sách các kênh Live Chat động cho BottomSheet chọn kênh.
2. **`liveChatSessionProvider`**:
   * Quản lý trạng thái phiên chat từ API `POST /api/v1/mobile/livechat/session`.
   * Cung cấp các thông tin phản ứng UI: `channelId`, `isOperatorOnline`, `channelName`, `operatorName`.
3. **Web-to-Mobile Continuity Listener**:
   * Khi khởi động App: Nếu trong bộ nhớ tạm (`FlutterSecureStorage`) có lưu `web_session_uuid` từ lần quét QR hoặc đăng nhập Portal, App tự động nạp phiên cũ và nhảy vào phòng chat mà không bắt khách chọn lại từ đầu.

---

### 5. Quy Chuẩn Xử Lý Subtitle & Tin Nhắn Xem Trước (Subtitle Truncation Specification)

Khắc phục triệt để lỗi cắt chuỗi tên người gửi có ngoặc đơn (như `"Sales Engineer (Kinh Doanh)"` bị cắt thành `"Doanh): jlikhjkj"`):

* **Thuật toán chuẩn hóa**:
  * Nếu tin nhắn từ chính người dùng: Hiển thị prefix `✓ Bạn: [Nội dung tin nhắn]`.
  * Nếu tin nhắn từ người khác trong kênh nhóm:
    1. Trích xuất tên người gửi từ trường `author_name` hoặc `author.name`.
    2. Rút gọn chức danh/họ tên dài (nếu cần) nhưng giữ nguyên vẹn cụm từ đầu, ví dụ: `"Sales Engineer: jlikhjkj"` hoặc `"Kinh Doanh: jlikhjkj"`.
    3. **Tuyệt đối CẤM** dùng các biểu thức chính quy (Regex) cắt chuỗi thô thiển như `replaceFirst(RegExp(r'\(.*?\)'), '')` gây gãy ngoặc đơn và để lại phần đuôi rác `"):"`.

---

### 6. Quy Chuẩn Phân Định Trực Quan Avatar Theo Phòng Ban (Distinct Visual Identity)

Chấm dứt việc toàn bộ kênh trên cùng đều dùng chung một logo quả cầu Vcloud xanh gây nhầm lẫn:

1. **Kênh Livechat Hỗ Trợ Kỹ Thuật (`Technical Support`)**:
   * Ưu tiên load ảnh đại diện từ `im_livechat.channel.image_128` (ID: 2).
   * Fallback UI Kit: Avatar nền xanh dương công nghệ (`#0077cd`), biểu tượng cờ lê kỹ thuật (`Icons.build_rounded` hoặc `Icons.support_agent_rounded`).
2. **Kênh Livechat Chăm Sóc Khách Hàng (`Customer Care`)**:
   * Ưu tiên load ảnh đại diện từ `im_livechat.channel.image_128` (ID: 3).
   * Fallback UI Kit: Avatar nền xanh lá chuyển đổi số (`#00ce2c`), biểu tượng tai nghe CSKH (`Icons.headset_mic_rounded`).
3. **Kênh Nhóm Hợp Đồng / CSKH Doanh Nghiệp (`[CSKH]`)**:
   * Hiển thị logo thương hiệu chính thức `branding/cskh_logo_360.png` hoặc Logo của Công ty khách hàng.
4. **Kênh Chat Trực Tiếp 1-1 (`channel_type: 'chat'`)**:
   * Hiển thị Avatar cá nhân của đối tác (`res.partner.avatar_128`), hoặc avatar chữ cái viết tắt với màu sắc ngẫu nhiên ổn định theo UID.

---

### 7. Quy Chuẩn Phân Loại Bộ Đếm Tab Lọc Hội Thoại (Filter Pills Specification)

Chấm dứt việc kênh Livechat bị tính nhầm vào tab "Zalo OA" (như lỗi hiển thị `Zalo OA 2` trong ảnh):

| Tên Tab Filter | Tiêu chí phân loại dữ liệu | Điều kiện lọc kỹ thuật |
|---|---|---|
| **Tất cả** | Toàn bộ các kênh người dùng tham gia | `channels` |
| **Chưa đọc** | Các kênh có tin nhắn mới chưa xem | `unread_count > 0` |
| **Trực tiếp** | Các cuộc trò chuyện 1-1 cá nhân | `channel_type == 'chat'` |
| **Nhóm** | Các nhóm thảo luận nội bộ / khách hàng | `channel_type == 'group'` |
| **Kênh** | Các kênh thông báo chung của tổ chức | `channel_type == 'channel'` |
| **Livechat** | Các phiên hỗ trợ trực tuyến đa kênh | `channel_type == 'livechat'` |
| **Zalo OA** | Chỉ các hội thoại kết nối cổng Zalo OA | `channel_type == 'zalo'` hoặc `provider == 'zalo'` (Tuyệt đối **KHÔNG** đếm `livechat`) |

---

## VI. BỘ CASE KIỂM THỬ ĐỘC LẬP (VERIFICATION TEST MATRIX)

| Mã Case | Tình huống kiểm thử | Hành vi mong đợi chuẩn Odoo Core | Tiêu chuẩn Đạt |
|---|---|---|:---:|
| **TC-01** | Khách chọn kênh `Customer Care` trên Mobile | Khởi tạo phiên Live Chat với `channel_type = 'livechat'`. | ĐẠT |
| **TC-02** | Khách chọn kênh `Technical Support` trên Mobile | Khởi tạo phiên Live Chat phân bổ tới kỹ thuật viên trực ca. | ĐẠT |
| **TC-03** | Đối soát menu `/home/livechat` trên Odoo Web | Số lượng phiên Live Chat tăng lên (`>= 1 Sessions`), chấm dứt lỗi 0 Sessions. | ĐẠT |
| **TC-04** | Hiển thị trong Odoo Discuss của nhân viên | Phiên chat xuất hiện tại mục **`Looking for help`** của Operator trực ca. | ĐẠT |
| **TC-05** | Nhận diện tiêu đề Header trên App Mobile | Header hiển thị đúng tên kênh từ Odoo, không bị gán cứng chữ "Chăm Sóc Khách Hàng 360". | ĐẠT |
| **TC-06** | Trạng thái trực ca của nhân viên | Hiển thị chấm xanh trực tuyến 🟢 khi Operator online; chuyển xám khi không có ai trực. | ĐẠT |
| **TC-07** | Nhận diện danh tính người phản hồi | Hiển thị `OdooBot` hoặc `livechat_username`, không làm lộ thông tin cá nhân nội bộ. | ĐẠT |
| **TC-08** | Operator gõ `/lead [tiêu đề]` trong Odoo Discuss | Odoo Core (`crm_livechat`) tạo `crm.lead`, trường `description` có đầy đủ nội dung đoạn chat. | ĐẠT |
| **TC-09** | Operator gõ `/ticket [tiêu đề]` trong Odoo Discuss | Odoo Core (`website_helpdesk_livechat`) tạo `helpdesk.ticket`, trường `description` nhúng trọn vẹn lịch sử đoạn chat. | ĐẠT |
| **TC-10** | Đồng bộ phiên từ Web sang App (Session Continuity)| Khách chat trên web, đăng nhập vào App Mobile thấy lại toàn bộ tin nhắn cũ. | ĐẠT |
| **TC-11** | Hiển thị tên kênh Livechat trong danh sách của Portal User | Khách hàng Portal thấy đúng tên dịch vụ ("Technical Support", "Customer Care"), tuyệt đối KHÔNG bị hiển thị tên "Admin". | ĐẠT |
| **TC-12** | Điều hướng Chat từ Sidebar của Portal User | Bấm vào Chat ở sidebar mở danh sách hội thoại (`ChatV2ListScreen`), nút quay lại trong hội thoại không bị ép về `/home`. | ĐẠT |
| **TC-13** | Hiển thị tên phòng ban Livechat trên giao diện Admin | Admin nhìn thấy rõ khách kèm phòng ban: `"Khách Hàng Mới • Customer Care"`, `"Khách Hàng Hợp Đồng • Technical Support"`. | ĐẠT |
| **TC-14** | Kênh Direct chat 1-1 phía Admin | Admin nhìn thấy tên khách hàng đối tác (`"Khách Hàng Mới (Portal Stage 1)"`), không nhìn thấy tên của chính mình ("Admin"). | ĐẠT |
| **TC-15** | Phân tách nhãn Badge Livechat và CSKH | Kênh Livechat hiển thị badge Livechat chuyên biệt, không bị gán nhãn `CSKH` tràn lan. | ĐẠT |
| **TC-16** | Xử lý Subtitle tin nhắn xem trước | Tên người gửi có dấu ngoặc đơn hiển thị nguyên vẹn, không bị lỗi cắt chuỗi `"Doanh):"`. | ĐẠT |
| **TC-17** | Phân định trực quan Avatar theo phòng ban | Avatar phân biệt màu sắc và icon giữa Technical Support (xanh dương / cờ lê) và Customer Care (xanh lá / tai nghe). | ĐẠT |
| **TC-18** | Bộ đếm tab Zalo OA trên giao diện Portal | Tab Zalo OA không bị đếm nhầm 2 kênh Livechat vào số lượng. | ĐẠT |
| **TC-19** | [Defect 1] Ẩn thông minh Chip lọc count == 0 | Tự động ẩn các chip lọc `Nhóm`, `Kênh`, `Zalo OA` khi số lượng = 0 trên thanh cuộn ngang. | ĐẠT |
| **TC-20** | [Defect 2] Gỡ 2 tích xanh tự chế trên Dòng 3 | Xóa sạch icon tích xanh cạnh tên và huy hiệu góc avatar trên kênh `Chăm Sóc Khách Hàng 360`. | ĐẠT |
| **TC-21** | [Defect 3] Bảo mật danh tính Admin đối với Portal | Kênh chat 1-1 với Admin trên giao diện Portal hiển thị tên chức danh `"Chuyên viên tư vấn"`. | ĐẠT |
| **TC-22** | [Defect 4] Khôi phục chip `[ Hỗ trợ ]` cho Operator | Tách kênh hỗ trợ khỏi Nhóm (`isSupportChannel`), hiển thị đầy đủ chip `[ Hỗ trợ 2 ]` cho nhân viên. | ĐẠT |
| **TC-23** | [Defect 5] Ghép tên khách hàng kèm phòng ban | Format chuẩn `"$customerName • $departmentName"` cho mọi ca Livechat trên giao diện Operator. | ĐẠT |
| **TC-24** | [Defect 6] Chống trùng lặp tiêu đề Dòng 1 & Dòng 5 | Phân định rõ Dòng 1 (Kênh CSKH Livechat) và Dòng 5 (Direct chat 1-1), loại bỏ 100% va chạm tiêu đề. | ĐẠT |
| **TC-25** | Bảo toàn tên thương hiệu CSKH cho Portal | Dòng 3 kênh CSKH trên giao diện Portal luôn hiển thị `"Chăm Sóc Khách Hàng 360"`, không bị đè bởi tên bộ phận Livechat. | ĐẠT |
| **TC-26** | Phân loại toàn vẹn bộ đếm hội thoại đa vai trò | `livechatCount`, `groupCount`, `directCount` tính toán độc lập, phản ánh chuẩn xác số lượng kênh theo từng vai trò. | ĐẠT |
