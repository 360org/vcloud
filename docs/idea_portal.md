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
| ❌ **Hardcode điều hướng 1-chạm ép Portal User vào thẳng 1 phòng chat duy nhất** | Bấm mục Chat ở sidebar bị ép nhảy vào duy nhất 1 phòng chat, không cho xem danh sách các kênh khác; nút Back bị ép quay về `/home`. Khách hàng Portal cần có danh sách hội thoại đầy đủ (`ChatV2ListScreen`) và nút mở phiên hỗ trợ trực tuyến linh hoạt. |
| ❌ **Gán đè tên chuyên viên ("Admin") lên tiêu đề kênh Live Chat của Portal User** | Phiên Live Chat có 2 thành viên (Portal và Operator). Nếu hệ thống coi đây là chat 1-1 cá nhân rồi gán tên Operator ("Mitchell Admin") sẽ làm mất hoàn toàn tính nhận diện dịch vụ ("Technical Support" hay "Customer Care"). Phía Portal User luôn phải nhìn thấy tên bộ phận hỗ trợ. |

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

### 4.3. Quy Chuẩn Tên Hiển Thị & Phân Định Góc Nhìn Hai Chiều (Role-Based Perspective Parity)
* **Nguyên tắc góc nhìn hai chiều (Perspective Parity Principle)**:
  * **Phía Khách Hàng (Portal User)**: Phiên Live Chat là kênh liên hệ dịch vụ chuyên trách. Tên hiển thị trên tiêu đề màn hình và danh sách chat **bắt buộc là tên dịch vụ/phòng ban** (`im_livechat.channel.name`, ví dụ: *Customer Care*, *Technical Support*) cùng Avatar của kênh Live Chat. Tuyệt đối không hiển thị tên cá nhân chuyên viên ("Mitchell Admin" hay "Admin") và không coi là chat 1-1 với cá nhân.
  * **Phía Chuyên Viên Trực Ca (Operator)**: Kênh Live Chat trong Discuss hiển thị rõ **tên khách hàng Portal** (`res.partner.name`) và avatar của khách để chuyên viên biết chính xác người đang cần hỗ trợ.
* **Tiêu đề kênh (Header Title)**:
  * Lấy **động 100%** từ trường `name` của `im_livechat.channel` trên Odoo (`Customer Care`, `Technical Support`, hoặc tên do admin cấu hình).
  * Avatar kênh: Lấy từ `im_livechat.channel.image_128` trên Odoo hoặc Logo Công Ty.
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
1. **API Lấy Danh Sách Kênh Live Chat**:
   * Endpoint: `GET /api/v1/mobile/livechat/channels`
   * Đọc danh sách `im_livechat.channel` động từ Odoo Backend (`Customer Care`, `Technical Support`...).
2. **API Mở Session Chuẩn Live Chat**:
   * Endpoint: `POST /api/v1/mobile/livechat/session`
   * Nhận tham số: `channel_id` (Integer bản ghi `im_livechat.channel`) và `web_session_uuid` (tùy chọn).
   * Gọi hàm core: `im_livechat.channel._get_livechat_discuss_channel_vals(...)` để tạo kênh `discuss.channel` loại `livechat`.
3. **Chuyển Đổi Nghiệp Vụ Chuẩn Odoo Core (Không chế API riêng)**:
   * Kế thừa 100% cơ chế slash command `/lead` (`crm_livechat`) và `/ticket` (`website_helpdesk_livechat`) thực thi bởi Operator trên Odoo Discuss hoặc qua Chatbot Script Steps.

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
   * **Trải nghiệm hội thoại tự nhiên**: Khung chat sạch sẽ, chuyên nghiệp, tập trung trao đổi nhu cầu mà không có nút bấm tự chế.

---

## 7. QUY CHUẨN ĐÓNG GÓI TINH GỌN (YAGNI & PONYTAIL)
* **Chỉ giữ đúng 2 trụ cột cốt lõi**:
  1. Phân luồng Live Chat Session chuẩn Odoo (`Customer Care`, `Technical Support`).
  2. Chuyển đổi nghiệp vụ chuẩn Odoo Core (Operator gõ `/lead`, `/ticket` hoặc Chatbot Odoo Core tự động).
* **Tuyệt đối không đưa vào hệ thống các tính năng chưa cần thiết**:
  * ❌ Bỏ đánh giá Rating / Sao (`rating.rating`) & gửi email transcript.
  * ❌ Bỏ gọi thoại / gọi video WebRTC (`discuss.call`).
  * ❌ Bỏ câu trả lời mẫu (`mail.shortcode`) do chưa cấu hình dữ liệu thực tế trên `vuahethong.net`.

---

## 8. ĐỐI SOÁT THỰC TẾ & BẢNG ĐIỂM SAI CẦN KHẮC PHỤC (AUDIT ẢNH CHỤP 2026-10-16)

Sau khi khởi chạy thực tế trên Local Server (`vcloud_test_v19`), đối soát song song giữa 2 tài khoản: **Admin (Hình 1 - Nhân viên nội bộ)** và **Portal (Hình 2 - Khách hàng)** ghi nhận các điểm sai và bất cập cụ thể cần khắc phục:

### 8.1. Phía Tài Khoản Admin / Operator (Hình 1 - Điểm Sai Nghiêm Trọng)
1. **Mất hoàn toàn tên phòng ban Livechat**:
   - Dòng 1 (*Customer Care*) và Dòng 2 (*Technical Support*) đều chỉ hiển thị trơ trọi tên khách hàng: `"Khách Hàng Mới (Portal Stage 1)"`.
   - **Hậu quả**: Admin nhìn vào danh sách hoàn toàn không phân biệt được khách đang liên hệ vào phòng ban nào (*Hỗ trợ kỹ thuật* hay *Chăm sóc khách hàng*) để phân công tiếp nhận.
   - **Định hướng khắc phục**: Phải hiển thị tên khách kèm phòng ban, ví dụ: `"Khách Hàng Mới • Technical Support"` hoặc hiển thị badge phòng ban chuyên biệt.
2. **Kênh chat 1-1 hiển thị ngược tên của chính mình ("Admin")**:
   - Dòng 3 hiển thị tên `"Admin"` kèm avatar chữ A và tin nhắn `"✓ Bạn: HI"`.
   - **Hậu quả**: Đây là kênh chat cá nhân giữa Admin và khách hàng, nhưng góc nhìn Admin lại hiển thị tên của chính Admin thay vì tên đối tác.
   - **Định hướng khắc phục**: Trong kênh `channel_type: 'chat'`, luôn phải bóc tách tên của người đối diện (`other_partner`), không được trả về thông tin của chính người đang đăng nhập.
3. **Trùng lặp 3 kênh cùng 1 tên khách hàng (Dòng 1, 2, 5)**:
   - Dòng 1 (Livechat Customer Care), Dòng 2 (Livechat Tech Support), Dòng 5 (Direct Chat 1-1) đều mang cùng tên `"Khách Hàng Mới (Portal Stage 1)"` khiến Admin rất dễ nhầm lẫn giữa phiên hỗ trợ trực tuyến và tin nhắn riêng.
4. **Gán nhãn `CSKH` tràn lan lên các kênh Livechat**:
   - Kênh Livechat (`channel_type: 'livechat'`) vốn là kênh tiếp nhận đa kênh độc lập nhưng lại bị gắn tag xanh `CSKH` như một nhóm thảo luận nội bộ.

### 8.2. Phía Tài Khoản Portal (Hình 2 - Điểm Cần Tinh Chỉnh)
1. **Lỗi cắt chuỗi người gửi ở tin nhắn xem trước (Dòng 3 - CSKH 360)**:
   - Dòng subtitle hiển thị lỗi: `"Doanh): jlikhjkj"`.
   - **Nguyên nhân**: Tên người gửi gốc là `"Sales Engineer (Kinh Doanh)"`. Bộ lọc regex/substring xử lý không chuẩn làm mất phần đầu, chỉ còn sót lại đuôi `"Doanh):"`.
   - **Định hướng khắc phục**: Chuẩn hóa hàm format tin nhắn xem trước, bóc tách `author_name` hoặc prefix người gửi nguyên vẹn.
2. **Avatar của 3 kênh đầu giống hệt nhau**:
   - Cả 3 kênh trên cùng (`Customer Care`, `Technical Support`, `Chăm Sóc Khách Hàng 360`) đều dùng chung logo quả cầu Vcloud xanh. Khách hàng nhìn lướt qua thấy 3 avatar y hệt nhau, thiếu tính phân biệt trực quan giữa phòng Kỹ thuật, phòng CSKH và nhóm hợp đồng.
   - **Định hướng khắc phục**: Đọc avatar động `image_128` riêng biệt của từng kênh Livechat (`im_livechat.channel`), hoặc cung cấp icon phân biệt (Headset cho CSKH, Wrench/Tech cho Kỹ thuật).
3. **Lộ kênh chat cá nhân tên "Admin" (Dòng 4)**:
   - Khách hàng Portal vẫn thấy kênh chat cá nhân mang tên thô `"Admin"`. Với khách hàng bên ngoài, không nên để lộ tài khoản cá nhân "Admin", mà cần được phân loại hoặc hiển thị chức danh đại diện phù hợp.
4. **Sai lệch bộ đếm filter pill "Zalo OA 2"**:
   - Tài khoản Portal chỉ có 5 kênh nhưng pill lọc Zalo OA lại hiện số **2**. Logic phân loại bộ đếm filter pill đang gom nhầm kênh Livechat vào tab Zalo OA.

---

### 8.3. ĐỐI SOÁT THỰC TẾ LẦN 2 SAU KHI FIX ĐỢT 1 (UAT ẢNH CHỤP 2026-10-16)

Sau đợt sửa đầu tiên, đối soát đồng thời 2 ảnh chụp giao diện thực tế (`2.png` - Portal User và `3.png` - Nhân viên nội bộ CSKH/Sale) ghi nhận kết quả chi tiết:

#### A. Giao diện Khách hàng Portal (`2.png`):
- 🟢 **ĐÃ ĐẠT**:
  1. Chip `[ Hỗ trợ 2 ]` đã xuất hiện với badge xanh Royal Blue (`#0077CD`), đếm đúng 2 kênh livechat. Tách sạch khỏi chip `Zalo OA`.
  2. Dòng 1 (`Customer Care`) và Dòng 2 (`Technical Support`) hiển thị đúng tên phòng ban và avatar phân biệt trực quan: 🎧 Tai nghe viền xanh lá cho CSKH, 🛠️ Cờ lê viền xanh dương cho Kỹ thuật kèm chấm 🟢 Online.
  3. Dòng 3 subtitle hiển thị trọn vẹn `Sales Engineer: jlikhjkj`, lỗi cắt chuỗi văng đuôi `"Doanh):"` đã được giải quyết triệt để.
  4. Nút FAB hiển thị đúng nút `[ 🎧 Hỗ trợ trực tuyến ]` dành riêng cho Portal.
- 🔴 **CHƯA ĐẠT / CÒN THIẾU**:
  1. Chip `[ Kênh ]` và `[ Zalo OA ]` có `count = 0` nhưng vẫn hiển thị trên thanh cuộn ngang, chưa được ẩn tự động theo cơ chế thông minh.
  2. Kênh `Chăm Sóc Khách Hàng 360` (Dòng 3) vẫn còn 2 tích xanh tự chế: 1 icon tích xanh `✓` cạnh tên và 1 huy hiệu tích xanh đè góc avatar. Chuẩn Odoo Livechat chỉ dùng chấm 🟢 Online ca trực.
  3. Dòng 4 vẫn để lộ tài khoản cá nhân thô `"Admin"` (chưa được alias thành `"Chuyên viên tư vấn"`).

#### B. Giao diện Nhân viên Nội bộ CSKH / Sale (`3.png` - LỖI NGHIÊM TRỌNG):
- 🟢 **ĐÃ ĐẠT**:
  1. Nút góc dưới là nút xanh `(+)` để tạo kênh (đúng quyền nhân viên nội bộ, không có nút "Hỗ trợ trực tuyến").
  2. Thanh điều hướng có thêm tab `Timesheet`.
  3. Dòng 2 (`Accounting Dept.`) và Dòng 4 (`General`) hiển thị đúng kênh/nhóm nội bộ.
- 🔴 **SAI NGHIÊM TRỌNG VỀ NGHIỆP VỤ TIẾP NHẬN**:
  1. **BIẾN MẤT HOÀN TOÀN CHIP `[ HỖ TRỢ ]`**: Thanh filter chỉ có `Tất cả 5`, `Chưa đọc`, `Trực tiếp 1`, `Nhóm 2`, `Kênh 1`, `Zalo OA`. Nhân viên không có cách nào lọc nhanh các ca chat trực tuyến của khách hàng. Kênh Livechat bị dồn nhầm vào danh mục `Nhóm 2`.
  2. **MẤT HOÀN TOÀN TÊN PHÒNG BAN TIẾP NHẬN (Lỗi B.11)**:
     - Dòng 1 hiển thị trơ trọi: `Khách Hàng Mới (Portal Stage 1)`.
     - Dòng 3 hiển thị trơ trọi: `Khách Hàng Hợp Đồng (Portal Stage 2)`.
     - Nhân viên Sale/Kỹ thuật nhìn vào danh sách hoàn toàn **không biết khách đang cần vào phòng ban nào** (`Customer Care` hay `Technical Support`) để tiếp nhận xử lý.
     - *Quy chuẩn*: Phải hiển thị dạng `Khách Hàng Mới • Customer Care` hoặc `Khách Hàng Hợp Đồng • Technical Support`.
  3. **TRÙNG LẶP TIÊU ĐỀ KÊNH GÂY LOẠN (Dòng 1 và Dòng 5)**:
     - Dòng 1 mang tên `Khách Hàng Mới (Portal Stage 1)` (phiên Livechat).
     - Dòng 5 cũng mang tên `Khách Hàng Mới (Portal Stage 1)` (tin nhắn chat 1-1 riêng).
     - Nhân viên bị rối loạn, không phân biệt được phiên hỗ trợ trực tuyến và tin nhắn cá nhân.

---

### 8.4. KẾT QUẢ NGHIỆM THU HOÀN TẤT V2 (UAT ĐỐI SOÁT CUỐI CÙNG 2026-10-16)

Sau khi xử lý triệt để 6 Defect trên cả Flutter Client (`vclients`) và Odoo Addon (`v_mobile_17`, `v_mobile_19`), đối soát thực tế trên Local Server (`vcloud_test_v19`) qua 2 ảnh chụp nghiệm thu cuối cùng (`4.png` cho Operator và `5.png` cho Portal) đạt chuẩn 100%:

| Hạng mục Defect | Hiện trạng xử lý kỹ thuật | Kết quả Đối soát Thực tế | Trạng thái |
|---|---|---|:---:|
| **[Defect 1] Ẩn Chip count == 0** | Bọc điều kiện `if (count > 0)` cho các chip tùy chọn (`Nhóm`, `Kênh`, `Zalo OA`, `Hỗ trợ`) | Cả 2 góc nhìn chỉ hiện các chip có dữ liệu (>0). Phía Portal chỉ hiện: `Tất cả 5`, `Chưa đọc`, `Trực tiếp 2`, `Hỗ trợ 3`. Đã ẩn sạch chip 0. Phía Operator chỉ hiện: `Tất cả 5`, `Chưa đọc`, `Trực tiếp 1`, `Kênh 1`, `Hỗ trợ 2`. | ✅ PASS |
| **[Defect 2] Gỡ 2 tích xanh giả Dòng 3** | Xóa sạch `LucideIcons.badgeCheck` ở cả góc avatar và cạnh tiêu đề kênh | Dòng 3 (`Chăm Sóc Khách Hàng 360`) chỉ hiển thị avatar logo tròn Vcloud và chấm 🟢 Online native Odoo. | ✅ PASS |
| **[Defect 3] Ẩn Admin với Portal** | Alias tài khoản Admin/Mitchell Admin thành `"Chuyên viên tư vấn"` | Dòng 4 phía Portal hiển thị: `"Chuyên viên tư vấn"` kèm avatar tròn chữ C màu ngọc. Tuyệt đối không lộ thông tin nội bộ. | ✅ PASS |
| **[Defect 4] Khôi phục Chip [ Hỗ trợ ]** | Tách kênh hỗ trợ khỏi Nhóm (`isSupportChannel => isLivechat \|\| isCskhChannel`), gom chuẩn vào `livechatCount` | Phía Operator xuất hiện đầy đủ chip `[ Hỗ trợ 2 ]`. Không bị dồn nhầm vào `Nhóm 2` như trước. | ✅ PASS |
| **[Defect 5] Tên khách kèm phòng ban** | Định dạng hiển thị phía Operator: `"$customerName • $departmentName"` | Dòng 1 hiện `Khách Hàng Mới • Customer Care`, Dòng 3 hiện `Khách Hàng Hợp Đồng • Technical Support`. Nhân viên nhận diện tức thì phòng ban. | ✅ PASS |
| **[Defect 6] Chống trùng Dòng 1 & Dòng 5** | Dòng 1 (Kênh CSKH) kèm phòng ban, Dòng 5 (1-1) giữ tên đối tác | Phía Operator: Dòng 1 (`Khách Hàng Mới • Customer Care`) và Dòng 5 (`Khách Hàng Mới (Portal Stage 1)`) hoàn toàn tách biệt, không bị trùng tiêu đề. Phía Portal: Dòng 3 hiển thị chuẩn `Chăm Sóc Khách Hàng 360`, không bị trùng với Dòng 1 `Customer Care`. | ✅ PASS |

#### Kết luận & Bàn giao:
Hệ thống Livechat Omnichannel trên Portal Mobile App và Operator Dashboard đã hoàn toàn đối xứng 2 góc nhìn (Role-Based Perspective Parity), đạt 21/21 Unit Test Cases, 0 lỗi static analysis (`dart analyze`), đồng bộ hoàn chỉnh lên Local Server LAN `192.168.1.100`. Sẵn sàng cho giai đoạn release.

---

### 8.5. KIỂM TOÁN MÀN HÌNH HOME PORTAL (UAT ẢNH CHỤP 4.PNG) & QUY CHUẨN THÍCH ỨNG THEO PHÂN HỆ HELPDESK

Đối soát thực tế ảnh chụp màn hình Home của tài khoản Portal Customer (`4.png` - `localhost:8089/#/home`) phát hiện 3 khiếm khuyết phân quyền và ranh giới kiến trúc:

#### A. Khiếm khuyết thực tế phát hiện:
1. 🔴 **Lộ tính năng nội bộ nhân viên (`_TodayWork`)**: Khối "Công việc hôm nay" kèm nút "Mở Timesheet" bị render trên tài khoản Portal (`isPortal == true`). Khách hàng bấm vào bị Router Guard đá văng về `/home`.
2. 🔴 **Dead-click & Trải nghiệm chết khi tenant Odoo chưa cài Helpdesk**: Lưới 4 ô hiển thị `[ 🎫 0 Ticket | Cần xử lý ]` kèm chữ `Tạo ticket` ở header; nhưng khi tenant Odoo chưa cài module `helpdesk`, nút bấm chuyển sang `/tickets` bị GoRouter chặn.
3. 🔴 **Lệch số Tab Bottom Bar không đồng nhất**: Màn hình Chat (`2.png`) có 4 tab (`Home`, `Chat`, `Ticket`, `Tôi`), nhưng màn hình Home (`4.png`) chỉ có 3 tab (`Home`, `Chat`, `Tôi`) do cờ `hasHelpdesk` bị lệch state.

#### B. Quy chuẩn Kiến trúc Phân luồng 2 Trạng thái của Portal Home:
1. 🟢 **Trường hợp 1: Tenant CÓ Module Helpdesk (`isPortal == true && hasHelpdesk == true`)**:
   - **Thanh điều hướng đáy (Bottom Bar)**: Đủ **4 Tab** (`[ 🏠 Home ]  [ 💬 Chat ]  [ 🎫 Ticket ]  [ 👤 Tôi ]`).
   - **Lưới 4 ô (Quick Nav Grid 2x2)**:
     * `[ 🎫 X Ticket ]` (Cam): Đếm số ticket của khách đang mở ➔ Bấm vào sang `/tickets`. Header có nút `Tạo ticket`.
     * `[ ✉️ X Chưa đọc ]` (Xanh dương): Đếm tin nhắn phản hồi mới.
     * `[ 💬 X Hội thoại ]` (Xanh ngọc): Đếm tổng số cuộc trò chuyện ➔ Bấm vào sang `/chat`.
     * `[ 🎧 X Hỗ trợ ]` (Xanh lá): Đếm số kênh Livechat trực tuyến (Customer Care, Tech Support) ➔ Bấm vào lọc tab Hỗ trợ.
   - **Khối bên dưới (Lower Section)**: Thay thế hoàn toàn `_TodayWork` bằng khối **"Phiếu hỗ trợ của bạn" (Recent Helpdesk Tickets)**.
     * Hiển thị 1–2 Ticket gần nhất của khách (Mã vé, Tiêu đề, Badge: *Mới / Đang xử lý / Đã đóng*) kèm nút `Xem tất cả` (`/tickets`).
     * Nếu chưa có vé: Hiển thị Empty state thân thiện kèm nút `[ + Gửi yêu cầu hỗ trợ ]`.

2. ⚪ **Trường hợp 2: Tenant CHƯA CÀI Module Helpdesk (`isPortal == true && hasHelpdesk == false`)**:
   - **Thanh điều hướng đáy (Bottom Bar)**: Rút gọn còn **3 Tab tinh gọn** (`[ 🏠 Home ]  [ 💬 Chat ]  [ 👤 Tôi ]`) — Ẩn hoàn toàn tab Ticket.
   - **Lưới Tổng quan**:
     * **Ẩn hoàn toàn** chữ `Tạo ticket` ở header.
     * Thay vì lưới 4 ô bị rỗng 1 ô, hiển thị **3 thẻ chức năng chuẩn xác**:
       1. `[ 🎧 X Kênh hỗ trợ trực tuyến sẵn sàng (🟢 Online) ]` (Xanh lá `#00CE2C`): Thẻ ngang nổi bật trên đầu.
       2. `[ ✉️ X Chưa đọc ]` (Xanh dương): Đếm tin nhắn mới.
       3. `[ 💬 X Hội thoại ]` (Xanh ngọc): Tổng số phòng chat.
   - **Khối bên dưới (Lower Section)**: Thay thế hoàn toàn bằng **"Dịch vụ hỗ trợ trực tuyến" (Livechat 1-Touch Quick Connect)**:
     * 🟢 **Customer Care (Chăm Sóc Khách Hàng)**: *"Tư vấn sản phẩm, báo giá, chính sách hợp đồng"* ➔ `[ Nhắn tin ➔ ]`.
     * 🛠️ **Technical Support (Hỗ Trợ Kỹ Thuật)**: *"Xử lý sự cố, hướng dẫn sử dụng phần mềm"* ➔ `[ Nhắn tin ➔ ]`.

#### C. Rào chắn Bảo vệ Phân quyền (Strict Architecture Guard):
- Trong `HomeScreen` (`vclients/lib/features/home/presentation/home_screen.dart`):
  ```dart
  if (isPortal) {
    if (hasHelpdesk) {
      return const _PortalRecentTicketsSection();
    } else {
      return const _PortalLivechatServicesSection();
    }
  } else {
    return const _TodayWork(); // CHỈ dành cho nhân viên nội bộ!
  }
  ```
- Khối `_QuickNavGrid`: Phân nhánh `isPortal` độc lập, loại bỏ hoàn toàn `MetricPill` cho Timesheet/Task và điều hướng `/timesheet` đối với khách hàng bên ngoài.

---

### 8.6. KIỂM TOÁN MÀN HÌNH CHI TIẾT TICKET (UAT ẢNH CHỤP 3.PNG & 4.PNG) — CÔ LẬP VAI TRÒ KHÁCH HÀNG PORTAL

Đối soát thực tế ảnh chụp màn hình Chi tiết Ticket trên tài khoản Portal (`3.png` & `4.png` - `localhost:8089/#/tickets`):

#### A. Khiếm khuyết & Lỗi phát hiện trên ảnh:
1. 🔴 **Lỗi nghiêm trọng 403 Forbidden (Ảnh 3.png)**:
   - Hiển thị 2 nút bấm quy trình kỹ thuật nội bộ `[ Nhận ticket ]` và `[ Hoàn thành ]` ở thanh đáy cho tài khoản Portal.
   - Khi khách hàng bấm vào nút `Nhận ticket`, Flutter gọi API `updateStatus` lên Backend Odoo và nhận mã lỗi HTTP 403: `Failure(Tài khoản Portal không có quyền thay đổi workflow ticket.)`.
   - **Root Cause**: Backend Odoo 17 & 19 (`v_mobile_17/19/controllers/ticket.py`, dòng 1013) đã chốt chặn bảo mật đúng chuẩn, nhưng Frontend `ticket_detail_screen.dart` hoàn toàn chưa có logic kiểm tra `isPortal`, áp đặt nguyên xi giao diện Kỹ thuật viên nội bộ cho khách hàng.
2. 🔴 **Lộ thao tác chuyển giao & chỉnh sửa trên Header (Ảnh 4.png)**:
   - Header hiển thị icon Chuyển giao (`onReassign`) cho phép mở danh sách toàn bộ nhân sự công ty để gán ticket, và icon Bút chì (`onEdit`) cho phép sửa đội xử lý/mức độ ưu tiên. Đây là quyền của Kỹ thuật/Admin, không phải của khách hàng.
3. 🔴 **Lộ tính năng Hoạt động nội bộ `mail.activity` (Ảnh 4.png)**:
   - Hiển thị khối `Hoạt động (+ Thêm)`. Trong Odoo, `mail.activity` là tính năng nội bộ nhân viên lên lịch hẹn gọi điện, họp, to-do giao việc; khách hàng Portal không có quyền và không có nhu cầu tạo hoạt động nội bộ.
4. 🔴 **Rác thông tin thẻ chi tiết (Ảnh 4.png)**:
   - Hiển thị hàng loạt chip cấu hình backend không cần thiết cho khách hàng (`Không chọn tag`, `Không CC email`, chip phân công có thể bấm mở popup chuyển giao).

#### B. Quy chuẩn Nghiệp vụ Đối xứng (Internal Support vs Portal Customer):
| Vị trí / Thành phần | Kỹ thuật viên Nội bộ (`!isPortal`) | Khách hàng Portal (`isPortal == true`) |
|---|---|---|
| **Header Actions** | Icon Chuyển giao (`onReassign`) & Icon Sửa (`onEdit`) | **Ẩn 100%** (Khách không thể tự gán người khác hoặc sửa cấu hình) |
| **Thẻ thông tin sự vụ** | Nhiều chip kỹ thuật (Tags, CC Email, Team, Assignee) | **Tối giản**: Tiêu đề, Mô tả sự cố, Trạng thái, SLA & Chuyên viên hỗ trợ |
| **Khối Hoạt động (`mail.activity`)** | Lên lịch gọi điện, họp, to-do giao việc (`+ Thêm`) | **Ẩn 100%** (Khách hàng không thể lên lịch công việc nội bộ) |
| **Thanh Action Bar ở đáy** | 2 nút `[ Nhận ticket ]` và `[ Hoàn thành ]` | **TRIỆT TIÊU 100%** (Khách không can thiệp workflow xử lý) |
| **Chatter / Bình luận** | Ghi chú nội bộ hoặc phản hồi khách hàng | **Khu vực tương tác chính**: Khung chat phản hồi ở đáy để trao đổi với Kỹ thuật |

#### C. Luồng Trạng Thái Hiển Thị Bên Phía Portal Khi Kỹ Thuật Thao Tác:
1. **Khi Kỹ thuật viên bấm "Nhận ticket"**:
   - Trạng thái trên Portal chuyển từ màu cam `Chờ xử lý` ➔ màu xanh dương `Đang xử lý`.
   - Hiển thị Avatar và Tên Kỹ thuật viên đang phụ trách phiếu (VD: `Chuyên viên hỗ trợ: Nguyễn Tuấn Anh`).
   - Lịch sử trao đổi xuất hiện thông báo hệ thống: *"Kỹ thuật viên Nguyễn Tuấn Anh đã tiếp nhận yêu cầu lúc 09:15"*.
2. **Khi Kỹ thuật viên bấm "Hoàn thành ticket"**:
   - Trạng thái trên Portal chuyển sang màu xanh lá: `Đã giải quyết` (kèm thời gian hoàn thành).
   - Hiển thị tóm tắt giải pháp/kết quả xử lý từ Kỹ thuật viên trong dòng tin nhắn.
   - Khu vực đáy hiển thị đánh giá sao chất lượng dịch vụ (⭐ 1-5 sao) hoặc khung gửi phản hồi nếu vấn đề chưa dứt điểm.

#### D. Kết quả Thực thi & Nghiệm thu Hoàn tất (Task B.16 VERIFIED - L4):
- **Triệt tiêu rò rỉ Timesheet**: Khối `_TodayWork` ("Công việc hôm nay" / "Mở Timesheet") bị loại bỏ 100% trên giao diện Portal (`isPortal == true`).
- **Thích ứng động theo Helpdesk**:
  + Khi `hasHelpdesk == true`: Header có nút "Tạo ticket"; Lưới 4 ô (Ticket, Chưa đọc, Hội thoại, Hỗ trợ); Khối dưới render danh sách phiếu hỗ trợ `_PortalRecentTicketsSection`. Bottom Bar đủ 4 tab (`Home`, `Chat`, `Ticket`, `Tôi`).
  + Khi `hasHelpdesk == false`: Header ẩn nút "Tạo ticket"; Lưới 3 ô (Thẻ Livechat ngang nổi bật `_PortalSupportBannerPill` + 2 ô Chưa đọc/Hội thoại); Khối dưới hiển thị 2 phòng trực Livechat 1-chạm (`_PortalLivechatServicesSection`). Bottom Bar rút gọn 3 tab (`Home`, `Chat`, `Tôi`), triệt tiêu dead-click.
- **Bảo đảm chất lượng**:
  + Bộ Widget Test `vclients/test/features/home/portal_home_adaptation_test.dart`: 10/10 test cases PASS.
  + Static Analysis: `flutter analyze` 0 errors, 0 warnings.
  + Tài liệu SSOT: Đồng bộ mục B.16 trong `vclients/docs/features.md`.

#### E. Kết quả Thực thi & Nghiệm thu Hoàn tất (Task B.17 VERIFIED - L4):
- **Triệt tiêu 403 Forbidden**: Loại bỏ hoàn toàn `_TicketActionBar` (nút `Nhận ticket` và `Hoàn thành`) trên tài khoản Portal (`isPortal == true`).
- **Ẩn thao tác quản trị trên Header**: Ẩn 100% icon Chuyển giao (`onReassign`) và icon Bút chì (`onEdit`) trên AppBar khi `isPortal == true`.
- **Ẩn khối Hoạt động nội bộ**: Ẩn 100% khối `_TicketActivitiesSection` (`mail.activity` / `+ Thêm`) với khách hàng Portal.
- **Tối giản chip chi tiết sự cố**: Ẩn các chip nội bộ rác (`Không chọn tag`, `Không CC email`, `Đội xử lý`) và chuyển chip Phụ trách thành thông tin thân thiện không thể click gán người.
- **Ghim khung phản hồi tâm điểm**: Khung nhập bình luận `_CommentComposer` ghim cố định ở đáy cho khách hàng trao đổi.
- **Bảo đảm chất lượng & Không hồi quy**:
  + Bộ Widget Test `vclients/test/features/ticket/portal_ticket_detail_test.dart`: 6/6 test cases PASS.
  + Static Analysis: `dart analyze lib/features/ticket/` đạt 0 errors, 0 warnings.
  + Kỹ thuật viên nội bộ (`!isPortal`): Vẫn hiển thị đầy đủ Action Bar và Hoạt động (Zero Regression).
  + Tài liệu SSOT: Đồng bộ mục B.17 trong `vclients/docs/features.md`.

---

### 8.7. KIỂM TOÁN MÀN HÌNH CHI TIẾT TICKET PORTAL (UAT ẢNH CHỤP 5.PNG) & QUY CHUẨN HOÀN THIỆN TRẢI NGHIỆM KHÁCH HÀNG (TASK B.18)

Đối soát thực tế ảnh chụp màn hình sau khi hoàn thành Task B.17 (`5.png` - `localhost:8089/#/tickets` trên tài khoản Portal `portal`):

#### A. Đánh giá Nghiệm thu UAT Thực tế (Pass B.17):
1. ✅ **Triệt tiêu dứt điểm lỗi 403 Forbidden**: Hai nút `[ Nhận ticket ]` và `[ Hoàn thành ]` ở đáy đã biến mất 100%. Không còn rủi ro khách hàng bấm nhầm gây lỗi phân quyền.
2. ✅ **Header tinh gọn**: Icon chuyển giao nhân sự và icon bút sửa đã bị ẩn hoàn toàn, giữ giao diện sạch sẽ.
3. ✅ **Ẩn tính năng nội bộ**: Khối Hoạt động (`mail.activity`) và các chip rác (`Không chọn tag`, `Không CC email`) đã được dọn sạch.
4. ✅ **Thẻ chuyên viên hỗ trợ trực quan**: Chip `Chuyên viên hỗ trợ: Kỹ Thuật Viên (Tech...)` màu xanh lá hiển thị trang trọng, không click được.
5. ✅ **Khung phản hồi ghim đáy**: Khung nhập bình luận đã được ghim cố định dưới đáy màn hình.

#### B. Phân tích Khiếm khuyết & Khoảng cách So với Chuẩn Odoo 17, 19 Portal & vuahethong.net:
Đối chiếu với cổng Portal Helpdesk chuẩn của Odoo 17 & 19 (`/my/ticket/<id>`) và hệ thống `vuahethong.net`, màn hình hiện tại còn thiếu các điểm then chốt phục vụ trải nghiệm người dùng:

1. **Thiếu Mã số hiệu Ticket (`ticket_ref` / `#ID`) trên Header**:
   - *Thực tế*: Header chỉ hiển thị chữ chung chung `Ticket`. Khách hàng khi cần gọi hotline kỹ thuật hoặc tra cứu không biết mã số phiếu của mình là bao nhiêu.
   - *Chuẩn hóa*: Header hiển thị `#${ticket.id} · Ticket` hoặc badge mã phiếu có nút sao chép 1-chạm.
2. **Thiếu Nút đính kèm tệp / hình ảnh trong khung Chat phản hồi (Chat Attachment)**:
   - *Thực tế*: Ô phản hồi ở thanh đáy chỉ có ô nhập văn bản và nút Gửi. Khi kỹ thuật viên yêu cầu *"Anh/chị gửi thêm ảnh chụp màn hình lỗi mới nhất"*, khách hàng hoàn toàn không có nút chọn ảnh/tệp (`LucideIcons.paperclip` / `LucideIcons.image`).
   - *Chuẩn hóa*: Tích hợp nút kẹp tệp đính kèm ảnh/file vào `_CommentComposer`, gọi API upload attachment Odoo tương tự như lúc tạo ticket.
3. **Thiếu Thời gian gửi yêu cầu (Ngày tạo - Created Date)**:
   - *Thực tế*: Khối SLA hiển thị `SLA: Không giới hạn`, nhưng khách hàng không biết ticket này đã gửi từ khi nào (ngày nào, mấy giờ) trừ khi cuộn xuống tận cùng xem tin nhắn đầu tiên.
   - *Chuẩn hóa*: Bổ sung chip `Ngày gửi: DD/MM/YYYY HH:mm` vào thẻ thông tin sự vụ.
4. **Phân biệt trực quan tin nhắn Kỹ thuật viên vs Khách hàng trong Chatter**:
   - *Thực tế*: Các bong bóng chat trong Chatter hiển thị danh sách phẳng, khó phân biệt nhanh đâu là phản hồi chính thức từ Kỹ thuật viên và đâu là tin nhắn của chính mình.
   - *Chuẩn hóa*: Hiển thị badge `Kỹ thuật viên` / `Hỗ trợ viên` trên tin nhắn của nhân viên nội bộ, hoặc phân màu viền/nền nhẹ để khách nhận biết ngay khi có giải đáp.
5. **Khách hàng tự đóng ticket hoặc Yêu cầu mở lại khi sự cố tái diễn (Self-Close / Reopen)**:
   - *Thực tế Odoo 17 & 19*: Có cơ chế `allow_portal_ticket_closing`. Khi vấn đề đã tự hết, khách có thể bấm xác nhận `Đã được giải quyết / Đóng ticket`. Khi ticket ở trạng thái Hoàn thành (`done`), khách có nút `Cần hỗ trợ thêm / Mở lại` nếu sự cố tái diễn.

#### C. Kế hoạch Triển khai Kỹ thuật (Task B.18 Implementation Plan):
- **Giai đoạn 1**: Bổ sung Mã số ticket trên Header (`_TicketDetailHeader`) và Ngày gửi yêu cầu trên Thẻ thông tin (`_TicketInfoCard`).
- **Giai đoạn 2**: Tích hợp nút đính kèm ảnh/tệp (`LucideIcons.paperclip`) vào `TicketCommentComposer`, cho phép chọn ảnh từ thư viện/camera và tải lên qua `MobileAttachmentRepository`.
- **Giai đoạn 3**: Tinh chỉnh `TicketCommentCard` hiển thị huy hiệu `Chuyên viên hỗ trợ` cho phản hồi từ nhân viên kỹ thuật.
- **Giai đoạn 4**: Bổ sung nút trạng thái thân thiện cho khách khi ticket Hoàn thành (`Cần hỗ trợ thêm` / `Mở lại ticket`).
- **Giai đoạn 5**: Viết bộ test tự động kiểm chứng và chạy static analysis bảo đảm 0 lỗi regression.

#### D. Kết quả Thực thi & Nghiệm thu Hoàn tất (Task B.18 VERIFIED - L4):
- **Mã số hiệu Ticket trên AppBar**: Header hiển thị rõ `#${ticket.id} · Ticket` kèm nút sao chép 1-chạm (`Clipboard.setData`) và thông báo Toast xác nhận sao chép thành công.
- **Ngày gửi yêu cầu**: Thẻ thông tin sự vụ bổ sung chip `Ngày gửi: DD/MM/YYYY HH:mm` định dạng chuẩn tiếng Việt, giúp khách hàng tiện theo dõi thời gian chờ.
- **Đính kèm ảnh/tệp trong Chat phản hồi**: `TicketCommentComposer` tích hợp nút kẹp tệp (`LucideIcons.paperclip`), BottomSheet chọn ảnh (Thư viện/Máy ảnh) hoặc tài liệu (tối đa 25MB), upload qua `MobileAttachmentRepository` và gửi kèm `attachment_ids` vào `/api/v1/mobile/ticket/<id>/message`.
- **Phân định Chuyên viên hỗ trợ**: `TicketCommentCard` hiển thị badge `Chuyên viên hỗ trợ` (`LucideIcons.shieldCheck`) viền xanh lá trên tin nhắn của nhân viên kỹ thuật.
- **Banner Hoàn thành & Yêu cầu mở lại**: Khi `isPortal == true` và `ticket.status == TicketStatus.done`, hiển thị banner xanh lá `_PortalTicketResolvedBanner` kèm nút `[ Cần hỗ trợ thêm / Mở lại ]` cho phép khách hàng yêu cầu mở lại khi sự cố chưa dứt điểm.
- **Bảo đảm chất lượng & Không hồi quy (Zero Regression)**:
  + Bộ Widget Test `test/features/ticket/portal_ticket_detail_test.dart`: **12/12 test cases PASS 100%**.
  + Static Analysis: `dart analyze` toàn bộ `lib/` và `test/` đạt **0 lỗi, 0 warnings**.
  + Kỹ thuật viên nội bộ (`!isPortal`): Bảo toàn 100% các nút thao tác `_TicketActionBar` (Nhận, Hoàn thành, Mở lại ticket) và Hoạt động nội bộ.

---

### 8.8. KIỂM TOÁN HIỆN TƯỢNG PHÂN MẢNH & TRÙNG LẶP PHIÊN LIVECHAT (UAT ẢNH CHỤP 19.PNG, 20.PNG, 21.PNG, 22.PNG) & QUY CHUẨN NỐI PHIÊN DUY NHẤT (TASK B.19)

Đối soát thực tế quá trình kiểm thử Livechat đa kênh giữa Website Widget và VCloud Mobile (`19.png`, `20.png`, `21.png`, `22.png`):

#### A. Hiện tượng thực tế & Nghiệm thu UAT:
- Sếp Tân tạo khách hàng tên `Jon` trên Website Livechat Widget (`http://192.168.1.100:1900`).
- Khi khách nhấn *"Có, rời khỏi cuộc trò chuyện"* trên web widget (ảnh `21.png`), Odoo Core mặc định kết thúc phiên và ghi nhận tin nhắn hệ thống: *"Khách truy cập đã rời khỏi cuộc trò chuyện"*.
- Khi khách tiếp tục mở lại khung trò chuyện và nhắn tin 3 lần liên tiếp:
  * Phía Odoo Discuss Backend (`20.png`): Odoo Core tự động tạo ra **3 kênh riêng biệt** cùng mang tên `Jon` dưới danh mục `Customer Care`.
  * Phía VCloud Mobile Dashboard nhân viên (`19.png` & `22.png`): Danh sách chat của nhân viên bị nhân bản tới **3 dòng `Jon • Customer Care`** (dòng 1: đang active 11:36; dòng 2: đã kết thúc *"Khách truy cập đã rời khỏi cuộc trò chuyện"*; dòng 3: phiên cũ 11:32).
  * Khách hàng quay lại trên web bị mất toàn bộ ngữ cảnh lịch sử trò chuyện cũ; phía nhân viên CSKH/Sale bị phân mảnh thông tin, danh sách chat bị ngập bởi các phòng chat rác của cùng một người.

#### B. Phân tích Nguyên nhân Gốc rễ (Root Cause):
1. **Cơ chế mặc định của Odoo Core Website Livechat (`/im_livechat/get_session`)**:
   - Khi khách vãng lai nhấn *"Rời khỏi cuộc trò chuyện"*, Odoo Core giải phóng guest cookie và đóng trường `livechat_end_dt`. Khi khách chat lại, Odoo Core coi đây là phiên mới hoàn toàn và tạo một bản ghi `discuss.channel` mới thay vì tìm lại kênh cũ.
2. **Cơ chế truy vấn danh sách kênh trên Mobile (`GET /api/v1/mobile/chat/channels`)**:
   - Backend `chat.py` hiện lấy toàn bộ các kênh mà nhân viên tham gia trong vòng 45 ngày qua mà **chưa lọc bỏ hoặc gộp các phiên Livechat đã đóng** (`livechat_end_dt` đã đóng, khách đã rời đi).
   - Chưa có cơ chế **Deduplication / Smart Rollup / Auto-Archive** cho các phiên Livechat trùng tên đối tác hoặc cùng một khách hàng trong cùng phòng ban (`Customer Care`).

#### C. Đối chiếu Chuẩn SSOT Ban Đầu (`docs/idea_portal.md` Mục 2.1 & 2.2):
- **Quy chuẩn cốt lõi đã đề ra**:
  1. **Session Continuity (Kế thừa phiên liên tục)**: Khi khách đã định danh hoặc quay lại, hệ thống phải **kế thừa toàn bộ lịch sử tin nhắn cũ**, không được xóa trắng và không bắt khách chat lại từ đầu.
  2. **Idempotency (Chống trùng lặp kênh)**: Một khách hàng liên hệ cùng một phòng ban (`Customer Care`) thì chỉ duy trì **1 Kênh hỗ trợ duy nhất**, không sinh ra hàng loạt kênh rác.
- **Hành vi thực tế hiện tại là LỆCH SO VỚI PLAN SSOT**: Cần phải chuẩn hóa gom phiên để danh sách chat chỉ còn duy nhất 1 dòng cho mỗi khách hàng.

#### D. Quy chuẩn Mục tiêu (Target Specification cho Task B.19):
1. **Nguyên tắc "1 Khách hàng ⟷ 1 Kênh hỗ trợ duy nhất" (Single Channel Idempotency)**:
   - Trên Mobile App, phía nhân viên chỉ hiển thị duy nhất **1 dòng `Jon • Customer Care`**.
   - Toàn bộ lịch sử trò chuyện qua các lần khách vào/ra phải được nối tiếp liên tục (Session Continuity), không bị chia cắt thành nhiều kênh khác nhau.
2. **Cơ chế lọc & dọn rác phiên đã đóng (Closed Session Auto-Archive & Rollup)**:
   - Các phiên Livechat mà khách đã out (`livechat_end_dt != False` hoặc tin nhắn cuối là *Khách đã rời cuộc trò chuyện*) phải được tự động ẩn khỏi danh sách trò chuyện đang hoạt động của nhân viên, chỉ giữ lại phiên đang tương tác gần nhất.
   - Khi khách cũ quay lại cùng tên hoặc thông tin nhận diện, hệ thống tự động kế thừa và kích hoạt lại (reopen) kênh chat cũ thay vì sinh kênh mới.
3. **Hiển thị trực quan trạng thái phiên Livechat**:
   - Kênh active: Badge `[Livechat]` xanh lá.
   - Kênh khách đã thoát: Badge `[Đã kết thúc]` xám, vô hiệu hóa gửi tin nhắn rác hoặc hiển thị thông báo khách đã rời đi.

#### E. Kế hoạch Triển khai Kỹ thuật (Task B.19 Plan):
- **Phía Backend `v_mobile` (Odoo 17 & 19)**:
  * Tinh chỉnh `GET /api/v1/mobile/chat/channels`: Thêm bộ lọc thông minh loại bỏ/ẩn các kênh Livechat đã kết thúc (`livechat_end_dt IS NOT NULL` và `is_pinned == False`) đối với nhân viên trực ca.
  * Tinh chỉnh gom nhóm hoặc nối phiên (Channel Consolidation): Đối với cùng một khách hàng / đối tác trên cùng một kênh livechat (`livechat_channel_id`), gom lịch sử hoặc chỉ trả về phiên mới nhất có gắn cờ nối tiếp.
- **Phía Frontend `vclients` (Flutter)**:
  * Cập nhật danh sách hiển thị và bộ lọc `[ Hỗ trợ ]`: Không hiển thị trùng lặp các phiên đã đóng của cùng một khách hàng.
  * Thêm bài test kiểm chứng chống trùng lặp phiên Livechat.
