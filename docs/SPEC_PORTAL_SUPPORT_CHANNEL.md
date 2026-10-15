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

## V. ĐẶC TẢ GIAO DIỆN FRONTEND FLUTTER (`vclients`)

### 1. Màn hình Chọn Kênh Hỗ Trợ (1-Chạm)
Hiển thị 2 thẻ chọn chuyên nghiệp:
* 🟢 **Customer Care**: *"Tư vấn sản phẩm, chính sách giá, hợp đồng & báo giá ưu đãi"*
* 🛠️ **Technical Support**: *"Báo lỗi hệ thống, hướng dẫn vận hành & hỗ trợ phần mềm"*

### 2. Màn hình Chi tiết Hội Thoại (`ChatV2DetailScreen`)
* **Header Bar**:
  * **Tiêu đề**: Hiển thị **động 100% từ Odoo Backend** (`Customer Care`, `Technical Support`...).
  * **Avatar**: Logo/Ảnh đại diện của Kênh cấu hình trên Odoo (`image_128`).
  * **Trạng thái**: Chấm xanh trực tuyến (**🟢 Online Indicator**) khi có ít nhất 1 Operator trực ca online.
* **Định danh người phản hồi**:
  * **Bot**: Hiển thị **`OdooBot`**.
  * **Nhân viên**: Hiển thị trường bí danh **`livechat_username`** (ví dụ: *Tư vấn viên 01*, *Admin (Viet Nam)*) để giữ tính chuyên nghiệp mà không để lộ tài khoản cá nhân nội bộ.
* **Thanh Quick Action tiện ích (1-Chạm)**:
  * 🌟 **Nút "Nhận báo giá"**: Bấm 1 chạm ➔ Gọi API tạo **CRM Lead**, thông báo mã cơ hội cho khách.
  * 🎫 **Nút "Gửi yêu cầu hỗ trợ"**: Bấm 1 chạm ➔ Gọi API tạo **Helpdesk Ticket**, trả về mã phiếu (VD: `#TCK-1025`).

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
