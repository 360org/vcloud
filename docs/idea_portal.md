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

