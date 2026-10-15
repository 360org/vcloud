# Thiết Kế Hệ Thống Live Chat Omnichannel: Kết Nối Website Live Chat ⟷ Portal App Mobile Chuẩn Odoo Enterprise

> **Mã tài liệu**: `docs/idea_portal.md`  
> **Hệ thống gốc**: Odoo Enterprise (Module `im_livechat` & `mail.discuss`)  
> **Nền tảng đồng bộ**: Website Live Chat Widget ⟷ VCloud Mobile App (Flutter `vclients`) ➔ Addon Backend `v_mobile` (Odoo 17 & 19)  
> **Thẩm định & Chuẩn hóa**: Sếp Tân & Ban Điều Hành 360 CORP  
> **Cập nhật lần cuối**: 2026-10-14  

---

## 1. BẢN CHẤT HAI MẢNH GHÉP HỆ THỐNG: WEBSITE LIVE CHAT VS PORTAL MOBILE APP

Trong chiến lược tiếp cận khách hàng đa kênh (Omnichannel) của 360 CORP, hệ thống gồm 2 thành phần tương tác gắn liền nhau trong cùng một hành trình khách hàng:

| Tiêu chí | 🌐 Website Live Chat Widget (Cửa trước) | 📱 VCloud Portal Mobile App (Phòng khách) |
|---|---|---|
| **Đối tượng** | **Khách Vãng Lai (Visitor / Người lạ)** | **Khách Hàng Định Danh (Portal User)** |
| **Điểm tiếp xúc** | Bong bóng Live Chat góc màn hình Website (`vuahethong.net`, landing pages) | **App VCloud Mobile** cài trên điện thoại |
| **Bản chất chat** | **Phiên tạm (Live Chat Session)** qua Odoo Guest Cookie / Token | **Kênh chính thức** gắn liền hồ sơ đối tác (`res.partner`) |
| **Độ bền dữ liệu** | **Tạm bợ**: F5 (Refresh), đóng tab, dùng ẩn danh là mất | **Vĩnh viễn**: Lưu DB PostgreSQL, đổi máy/đăng nhập lại vẫn còn nguyên |
| **Mục đích** | **Hút khách ban đầu, giải đáp nhanh, lấy Email/SĐT** | **Chăm sóc lâu dài, báo giá, xuất hóa đơn, hỗ trợ kỹ thuật** |

---

## 2. NỖI ĐAU THỰC TẾ & BẢN CHẤT "CHUYỂN SESSION" (SESSION HANDOVER)

### 2.1. Nỗi đau: "Khách chat trên Web, F5 (Refresh) là bị mất!"
* **Nguyên nhân kỹ thuật**: Khách vào website chưa đăng nhập chỉ được Odoo cấp token khách vãng lai tạm thời (`mail.guest`). Khi khách Refresh trình duyệt hoặc chuyển trang, token này có thể bị reset hoặc mất kết nối.
* **Hậu quả kinh doanh**:
  1. Khách hàng vừa trình bày nhu cầu / sự cố, F5 mất sạch ➔ Ức chế, bỏ trang web.
  2. Nhân viên Sales/CSKH đang chat dở thấy khách biến mất ➔ **Rớt mất khách hàng tiềm năng (Lost Lead)**.

### 2.2. Bản chất "CHUYỂN SESSION" mà Ban Điều Hành hướng tới
"Chuyển Session" là giải pháp xóa bỏ ranh giới giữa Khách Vãng Lai và Khách Định Danh thông qua 4 cơ chế chuyển tiếp:

```text
[Khách Vãng Lai vào Web] ──(Chat qua Live Chat Widget)──> [OdooBot chào & tiếp nhận]
                                                                  │
                                      Khách cần tư vấn sâu / để lại Email/SĐT
                                                                  │
                                                                  ▼
                                                      【CHUYỂN SESSION】
                      ┌───────────────────────────────────────────┴───────────────────────────────────────────┐
                      ▼                                                                                       ▼
         [Chuyển Sang Người Trực]                                                               [Chuyển Thành Định Danh Portal]
    (OdooBot ➔ Operator trực ca)                                                                 (Gắn Session vào res.partner)
                      │                                                                                       │
                      ▼                                                                                       ▼
    [Chuyển Thành Lead / Ticket]                                                                [Chuyển Tiếp Sang App Mobile]
(:lead ➔ crm.lead / :ticket ➔ helpdesk)                                                         (Mở App VCloud thấy lại lịch sử web)
```

1. **Chuyển từ Khách Vãng Lai ➔ Khách Định Danh Portal (Session Migration)**:
   * Khi khách đang chat trên web, Bot hoặc Nhân viên xin thông tin Email/SĐT hoặc mời đăng nhập Portal.
   * Ngay khi có thông tin: Hệ thống **chuyển phiên chat tạm thành kênh chính thức gắn vào `res.partner`**.
   * Từ thời điểm này, khách F5, tắt máy hay đăng nhập lại đều **không bao giờ bị mất tin nhắn**.
2. **Chuyển tiếp đa thiết bị (Web ⟷ App Mobile Continuity)**:
   * Khách chat dở trên máy tính, khi mở App VCloud Mobile trên điện thoại thì đoạn chat vừa nãy trên web được đồng bộ xuất hiện ngay trong phòng chat của App.
3. **Chuyển từ Bot tự động ➔ Nhân viên trực ca (Bot ➔ Human Handoff)**:
   * OdooBot chào đón ban đầu; khi khách có câu hỏi nghiệp vụ, OdooBot chuyển giao phiên cho nhân viên đang online trong phòng trực.
4. **Chuyển từ Hội Thoại ➔ Nghiệp Vụ Xử Lý (Chat ➔ Lead / Ticket)**:
   * Khách cần báo giá ➔ Chuyển thành **CRM Lead (`crm.lead`)**.
   * Khách báo lỗi ➔ Chuyển thành **Phiếu Hỗ Trợ (`helpdesk.ticket`)**.

---

## 3. DANH MỤC CÁC Ý TƯỞNG SAI BỊ LOẠI BỎ TRIỆT ĐỂ (DEPRECATED & REMOVED)

Để bảo đảm hệ thống chạy đúng chuẩn Odoo Enterprise nguyên bản, các cách làm sau **bị loại bỏ hoàn toàn**:

| Cách làm cũ / Sai lệch | Lý do BẮT BUỘC LOẠI BỎ |
|---|---|
| ❌ **Tự chế Chat 1-1 (`channel_type: 'chat'`) với cá nhân Admin** | Tin nhắn rơi vào `Direct messages` riêng của tài khoản `admin` (như trong ảnh thực tế). Các nhân viên trực ca không nhìn thấy; tab `/home/livechat` luôn bị **`0 Sessions`**. |
| ❌ **Tự chế tạo kênh nhóm (`channel_type: 'group'`) rồi gán cứng nhân viên tĩnh** | Viết script SQL/ORM tìm user theo email để add cứng vào kênh phá vỡ cơ chế ca trực động. Nhân viên nghỉ phép/offline vẫn bị kéo vào, còn người đang trực lại không nhận được. |
| ❌ **Gộp chung 1 kênh duy nhất không phân loại nhu cầu** | Khách cần báo giá lại gặp kỹ thuật; khách gặp sự cố khẩn cấp lại gặp tư vấn bán hàng, làm nghẽn luồng xử lý. |
| ❌ **Tách rời Web Live Chat và App Mobile thành 2 hệ thống độc lập** | Khách chat trên web xong tải app về lại phải khai báo lại từ đầu, gây đứt gãy trải nghiệm khách hàng. |
| ❌ **Tự chế hardcode tên kênh ("Chăm Sóc Khách Hàng 360") & tích xanh MXH** | Phá vỡ tính năng cấu hình động trên Odoo Backend (`im_livechat.channel`). Trên Odoo quản trị viên đặt tên gì (`Customer Care`, `Technical Support`, `HELLO EM`...) thì App phải hiển thị đúng tên đó. Odoo Live Chat dùng chấm trạng thái trực tuyến (🟢 Online Indicator) của ca trực, không dùng tích xanh MXH tự chế. |
| ❌ **Triệt tiêu tên người trực (ép hiển thị Logo vô danh)** | Odoo chuẩn bảo mật danh tính bằng trường `livechat_username` trong User Profile (hoặc `OdooBot`) để khách biết vai trò người hỗ trợ mà vẫn không lộ thông tin cá nhân nội bộ. |

---

## 4. KIẾN TRÚC MỤC TIÊU: HAI PHÒNG TRỰC CHUẨN TRÊN ODOO ENTERPRISE

Phía nhân viên công ty chỉ ngồi trực tập trung tại một nơi duy nhất: **Odoo Discuss (`/home/action-mail.action_discuss`)** trong mục **`Looking for help`** với 2 phòng trực chuẩn:

### 4.1. Kênh 1: 🟢 `Customer Care` (Chăm Sóc Khách Hàng / Kinh Doanh)
* **Phạm vi**: Khách tìm hiểu sản phẩm, hỏi tính năng, chính sách giá, gia hạn hợp đồng, thắc mắc thanh toán.
* **Quy trình xử lý**:
  * Tiếp nhận phiên Live Chat từ Web hoặc App Mobile.
  * Tích hợp Quick Action / lệnh `:lead` tạo nhanh cơ hội bán hàng **CRM Lead**.
  * Nhân sự phụ trách: Đội ngũ Sales Engineer, Chuyên viên tư vấn giải pháp.

### 4.2. Kênh 2: 🟢 `Technical Support` (Hỗ Trợ Kỹ Thuật)
* **Phạm vi**: Khách hàng đang dùng gặp sự cố phần mềm, hướng dẫn vận hành, báo lỗi kết nối thiết bị.
* **Quy trình xử lý**:
  * Tiếp nhận phiên Live Chat từ Web hoặc App Mobile.
  * Tích hợp Quick Action / lệnh `:ticket` tạo phiếu sự cố **Helpdesk Ticket**.
  * Nhân sự phụ trách: Đội ngũ Kỹ sư giải pháp, Kỹ thuật viên phần mềm.

### 4.3. Quy Chuẩn Tên Hiển Thị & Nhận Diện Hội Thoại (Single Source of Truth từ Odoo)
* **Tiêu đề kênh (Header Title)**:
  * Lấy **động 100%** từ trường `name` của `im_livechat.channel` trên Odoo (`Customer Care`, `Technical Support`, hoặc tên do admin cấu hình).
  * Avatar kênh: Lấy từ `im_livechat.channel.image_128` trên Odoo.
  * Trạng thái ca trực: Hiển thị chấm trạng thái trực tuyến (**🟢 Online Indicator**) khi có ít nhất một Operator trực ca đang online trong mục `Looking for help`. Tuyệt đối không dùng tích xanh mạng xã hội tự chế.
* **Tên người phản hồi (Sender Name & Identity)**:
  * **Bot trả lời**: Hiển thị tên bot chuẩn Odoo (**`OdooBot`**) hoặc tên kịch bản chatbot.
  * **Nhân viên trực ca trả lời**: Hiển thị theo trường bí danh **`livechat_username`** (ví dụ: *Tư vấn viên 01*, *Admin (Viet Nam)*) được cấu hình trong Hồ sơ Người dùng (User Profile) Odoo. Cơ chế này bảo đảm khách hàng nhận biết được vai trò người hỗ trợ mà hoàn toàn không bị lộ thông tin cá nhân nội bộ.
  * Tuyệt đối không xóa trắng danh tính hay ép hiển thị logo vô danh.

---

## 5. BÁO CÁO & ĐO LƯỜNG QUẢN TRỊ (TAB SESSIONS TRÊN ODOO)

Khi luồng chat từ cả Website và App Mobile đều đi qua Live Chat Engine:
1. **Ghi nhận chỉ số Sessions thực tế**:
   * Tại `/home/livechat`: Kênh `Customer Care` và `Technical Support` sẽ nhảy số phiên hỗ trợ thực tế (ví dụ: `1 Sessions`, `25 Sessions`...) thay vì bị số `0 Sessions` như hiện tại.
2. **Theo dõi KPI & Báo cáo chất lượng (`Reporting`)**:
   * Ban Giám Đốc theo dõi được:
     * Số lượng phiên hỗ trợ theo ngày/tuần/tháng.
     * Thời gian nhân viên phản hồi khách hàng (First Response Time).
     * Điểm đánh giá độ hài lòng của khách hàng (Rating 1 - 5 ⭐).

---

## 6. KẾ HOẠCH TRIỂN KHAI KỸ THUẬT (ROADMAP)

### 6.1. Phía Backend Addon `v_mobile` (Odoo 17 & 19)
1. **API Mở Session Chuẩn Live Chat**:
   * Endpoint: `POST /api/v1/mobile/livechat/session`
   * Nhận tham số: `channel_alias` (`customer_care` hoặc `technical_support`).
   * Gọi hàm core: `im_livechat.channel._open_livechat_mail_channel(...)` để tạo kênh `discuss.channel` loại `livechat`.
2. **Cơ Chế Nối Session (Session Linking / Handoff)**:
   * Cho phép liên kết `uuid` của Livechat session trên Web với `res.partner` của Portal User khi đăng nhập.
3. **Cung cấp API Quick Action Nghiệp Vụ**:
   * `POST /api/v1/mobile/crm/lead`: Tạo cơ hội bán hàng từ hội thoại.
   * `POST /api/v1/mobile/helpdesk/ticket`: Tạo phiếu hỗ trợ từ hội thoại.

### 6.2. Phía Frontend VCloud Mobile App (`vclients`)
1. **Giao Diện Chọn Nhu Cầu 1-Chạm**:
   * Portal User vào mục Hỗ Trợ hiển thị 2 thẻ chọn chuyên nghiệp:
     * 🟢 **Chăm Sóc Khách Hàng (Customer Care)**: *"Tư vấn dịch vụ, hợp đồng, nhận báo giá ưu đãi"*.
     * 🛠️ **Hỗ Trợ Kỹ Thuật (Technical Support)**: *"Xử lý sự cố, giải đáp kỹ thuật, hỗ trợ phần mềm"*.
2. **Trải Nghiệm Hội Thoại Chuẩn Odoo Enterprise (Single Source of Truth)**:
   * **Tên kênh & Avatar động 100%**: Header hiển thị avatar và tên kênh lấy trực tiếp từ `im_livechat.channel` trên Odoo (`Customer Care`, `Technical Support`...). Tuyệt đối không hardcode.
   * **Trạng thái trực ca (🟢 Online Indicator)**: Hiển thị chấm xanh khi có Operator trực ca online thay cho tích xanh MXH tự chế.
   * **Tên người phản hồi & Bảo mật**: Hiển thị `OdooBot` hoặc bí danh `livechat_username` do nhân viên cài đặt trên Odoo; phía nhân viên thấy rõ tên và thông tin Portal của khách hàng.
   * **Đồng bộ phiên (Session Continuity)**: Kế thừa toàn bộ lịch sử tin nhắn từ phiên Web Live Chat sang App Mobile khi khách hàng đăng nhập Portal.
   * **Thao tác nhanh**: Tích hợp sẵn nút Quick Action nhận báo giá (`crm.lead`) hoặc gửi phiếu hỗ trợ (`helpdesk.ticket`).

---

## 7. QUY CHUẨN ĐÓNG GÓI TINH GỌN (YAGNI & PONYTAIL)
* **Chỉ giữ đúng 2 trụ cột cốt lõi**:
  1. Phân luồng Live Chat Session chuẩn Odoo (`Customer Care`, `Technical Support`).
  2. Chuyển đổi nghiệp vụ 1-chạm (Chat ➔ Lead / Ticket kèm chat history).
* **Tuyệt đối không đưa vào hệ thống các tính năng chưa cần thiết**:
  * ❌ Bỏ đánh giá Rating / Sao (`rating.rating`) & gửi email transcript.
  * ❌ Bỏ gọi thoại / gọi video WebRTC (`discuss.call`).
  * ❌ Bỏ câu trả lời mẫu (`mail.shortcode`) do chưa cấu hình dữ liệu thực tế trên `vuahethong.net`.
