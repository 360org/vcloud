# 💡 Ý TƯỞNG & ĐỊNH HƯỚNG TỔNG QUAN DỰ ÁN (IDEA.md)

Tài liệu ghi nhận toàn bộ bối cảnh, bài toán cốt lõi, danh mục các yêu cầu/lỗi từ Sếp Tân và bản đồ ưu tiên thực thi cho hệ sinh thái **VCloud Mobile App & Odoo Backend**.

---

## ⏳ 1. DANH MỤC TASK CHƯA FIX (PENDING BACKLOG)

```text
 🟢 P1: Quick Wins (Last Message & Bộ Lọc Chưa Đọc) ➔ LÀM ĐẦU TIÊN
 🔴 P4: Fullstack / Backend Odoo API (LÀM SAU CÙNG)
```

| Ưu tiên | Task ID | Tên Nhiệm Vụ / Lỗi | Mức độ | Layer | Thời gian | Chi Tiết Tài Liệu | Trạng thái |
|:---:|:---:|---|:---:|:---:|:---:|:---:|:---:|
| **#1** | **#16455** | Tính năng Gọi thoại chuẩn Zalo/Telegram (Enterprise Voice Call) | 🟢 **P1** | Fullstack + WebRTC/Audio | 3 giờ | Tài liệu task lịch sử không còn trong repository | 💡 **IDEA / PROPOSAL** |
| **#2** | **#16454** | Hoàn thiện bộ ba tính năng quản trị chat (Ghim 📌, Tắt thông báo 🔕, Ẩn/Hiện cuộc trò chuyện 🗄️) | 🟢 **P1** | Fullstack | 2.5 giờ | Tài liệu task lịch sử không còn trong repository | ✅ **DONE** |
| **#3** | **#16453** | Tính năng Ghi âm & Tin nhắn Thoại chuẩn Zalo/Telegram/WhatsApp (Voice Messaging) | 🟢 **P1** | Frontend + Audio | 3 giờ | Tài liệu task lịch sử không còn trong repository | ✅ **DONE** |
| **#4** | **#16450** | Khắc phục lỗi chưa hiển thị tin nhắn cuối (Last Message) trên danh sách hội thoại | 🟢 **P1** | Fullstack | 20 phút | Tài liệu task lịch sử không còn trong repository | ✅ **DONE** |
| **#5** | **#16451** | Khắc phục lỗi tin nhắn do chính mình gửi lại lọt vào mục "Chưa đọc" | 🟢 **P1** | Fullstack | 20 phút | Tài liệu task lịch sử không còn trong repository | ✅ **DONE** |
| **#6** | **#16452** | Làm tính năng xem chi tiết người thả Reaction giống Zalo Mobile (Reaction Details BottomSheet) | 🟢 **P1** | Frontend UI | 2 giờ | Tài liệu task lịch sử không còn trong repository | ✅ **DONE** |
| **#7** | **#16436** | Khắc phục hardcode chi tiết ca làm việc, lấy số giờ từ API Odoo | 🔴 **P4** | Backend Odoo + App | 2 giờ | Tài liệu task lịch sử không còn trong repository | ⏳ **BACKLOG** |

---

## ✅ 2. DANH MỤC TASK ĐÃ FIX & ĐÃ NGHIỆM THU (COMPLETED TASKS)

| Task ID | Tên Nhiệm Vụ | Mức độ | Layer | Chi Tiết Tài Liệu | Trạng thái |
|:---:|---|:---:|:---:|:---:|:---:|
| **#16446** | Sửa lỗi hiển thị nhầm avatar con mèo của User vào đối phương (Bùi Tuấn Kiệt) | 🟢 **P1** | Frontend UI/Header | Tài liệu task lịch sử không còn trong repository | ✅ **DONE** |
| **#16447** | Sửa bộ lọc "Nhóm" bị 0 & hiển thị đầy đủ danh sách nhóm đã tạo | 🟢 **P1** | Frontend Filter/Model | Tài liệu task lịch sử không còn trong repository | ✅ **DONE** |
| **#16448** | Sửa lỗi gửi ảnh hiện chấm than đỏ (thất bại giả) dù Odoo đã nhận thành công | 🟡 **P2** | Frontend Controller | Tài liệu task lịch sử không còn trong repository | ✅ **DONE** |
| **#16449** | Sửa lỗi `Expected singleton: res.users()` khi tạo chat 1-1 & Tối ưu tốc độ mở chat | 🟠 **P3** | Backend + Frontend | Tài liệu task lịch sử không còn trong repository | ✅ **DONE** |
| **#16443** | Đổi tiêu đề thời gian dự kiến ở timesheet thành "Tổng thời gian cho phép" | 🟢 **P1** | Frontend UI | Tài liệu task lịch sử không còn trong repository | ✅ **DONE** |
| **#16438** | Fix lại btn thêm ở chat sao cho chuẩn ui/ux, đổi icon phù hợp | 🟢 **P1** | Frontend UI | Tài liệu task lịch sử không còn trong repository | ✅ **DONE** |
| **#16433** | Hoàn thiện tiêu đề tab "Trực tiếp" & phản ứng bộ đếm unread | 🟢 **P1** | Frontend UI | Tài liệu task lịch sử không còn trong repository | ✅ **DONE** |
| **#16440** | Tên hiển thị bị cắt mất và tin nhắn trả lời nó đang bị vỡ layout | 🟡 **P2** | Frontend UI | Tài liệu task lịch sử không còn trong repository | ✅ **DONE** |
| **#16444** | Đổi lọc cá nhân thành nội bộ, thêm lọc kênh (channel) và mặc định Tất cả | 🟡 **P2** | Frontend Riverpod | Tài liệu task lịch sử không còn trong repository | ✅ **DONE** |
| **#16435** | Sửa lỗi đếm số lượng Nhóm trong nút lọc Chat bị trùng lặp với Tất cả | 🟡 **P2** | Frontend Controller | Tài liệu task lịch sử không còn trong repository | ✅ **DONE** |
| **#16434** | Đồng bộ số lượng cuộc trò chuyện giữa nút lọc "Tất cả" và Trang Chủ | 🟡 **P2** | Frontend Controller | Tài liệu task lịch sử không còn trong repository | ✅ **DONE** |
| **#16445** | Ở time sheet hiển thị chưa đúng ở phần thời gian còn lại (remaining hours) | 🟠 **P3** | Frontend Data/Format | Tài liệu task lịch sử không còn trong repository | ✅ **DONE** |
| **#16442** | [BUG/FIX] Khắc phục lỗi chưa xem và đọc được file đính kèm | 🟠 **P3** | Frontend Attachment | Tài liệu task lịch sử không còn trong repository | ✅ **DONE** |

---

## 💡 3. Ý TƯỞNG ĐỊNH TUYẾN ĐĂNG NHẬP ĐA MÔI TRƯỜNG TỰ ĐỘNG (DUAL-DOMAIN SMART SEAMLESS ROUTING)
*Được Sếp Tân định hướng & phê duyệt ngày 27/08/2026*

### 3.1. Bối Cảnh & Bài Toán Cốt Lõi
- **Mục tiêu**: Hỗ trợ người dùng đăng nhập song song vào 2 hệ thống Odoo độc lập mà không làm thay đổi giao diện chuẩn nguyên bản:
  * 🟢 **Production (`https://vuahethong.net`)**: Môi trường làm việc chính thức chứa tài khoản nhân sự thật (`tanmnn@360.org.vn`...).
  * 🟠 **Demo Server (`https://demo.vuahethong.com`)**: Môi trường Sandbox trải nghiệm thử nghiệm dành cho khách hàng & bán hàng chứa các tài khoản mẫu (`demo / demo`, `morpheus / morpheus`...).
- **Yêu cầu UI/UX từ Sếp Tân**:
  * **Giao diện chuẩn nguyên bản 100%**: Logo Vua Hệ Thống ➔ Chào mừng trở lại 👋 ➔ Ô Email ➔ Ô Mật khẩu ➔ Nút Đăng nhập ➔. Tuyệt đối không thêm nút chọn server, dropdown hay toggle làm rối mắt người dùng.
  * **Phân luồng thông minh, tự động, trong suốt (Seamless Auto-Routing)**: Người dùng nhập bất kỳ tài khoản nào thuộc DB nào thì hệ thống tự động xác thực và chuyển hướng vào đúng máy chủ đó.
  * **Cô lập dữ liệu tuyệt đối (Single Source of Truth)**: Không để xảy ra tình trạng "râu ông nọ cắm cằm bà kia" — Toàn bộ Chat, Tin nhắn, Công việc, Ảnh đại diện, Refresh Token và FCM Push Device Token phải gắn chặt vào đúng domain của phiên đăng nhập đó.
  * **Giải phóng hoàn toàn khi Đăng xuất (Clean Logout)**: Khi người dùng bấm Đăng xuất, toàn bộ `baseUrl`, Token và Cache được giải phóng sạch sẽ 100%, cho phép người dùng tự do đăng nhập tài khoản khác của bất kỳ domain nào ở lần kế tiếp.

### 3.2. Cơ Chế Xác Thực & Phân Luồng Thông Minh Phía Sau (Smart Auto-Fallback Engine)
1. **Kiểm tra theo chuỗi ưu tiên (Production ➔ Demo Fallback)**:
   - **Bước 1**: App gửi thông tin đăng nhập tới Production (`https://vuahethong.net`). Nếu tìm thấy user trong bảng `res.users` của DB `vuahethong` ➔ Đăng nhập thành công, khóa `OdooSession.baseUrl = https://vuahethong.net`.
   - **Bước 2**: Nếu `vuahethong.net` trả về lỗi 401 (không có user trong DB `vuahethong`) ➔ App tự động gửi thông tin sang Demo Server (`https://demo.vuahethong.com`). Nếu tìm thấy user trong bảng `res.users` của DB `demo` (`demo`, `morpheus`...) ➔ Đăng nhập thành công, khóa `OdooSession.baseUrl = https://demo.vuahethong.com`.
   - **Bước 3**: Nếu cả 2 server đều không tìm thấy ➔ Báo lỗi "Tài khoản hoặc mật khẩu không chính xác".
2. **Quy trình Đăng xuất Sạch (Clean Session Teardown)**:
   - Hủy đăng ký FCM Push Device Token trên server hiện tại (`_unregisterPushDevice()`).
   - Xóa sạch `_session` trong RAM và xóa `vcloud_odoo_session` trong `FlutterSecureStorage`.
   - Xóa sạch cache tin nhắn và tệp đính kèm cục bộ (`ChatV2ChannelLocalCache.clear()` và `LocalAttachmentCache.clearAllCache()`).
   - Trả `_activeBaseUrl()` về trạng thái tự do ban đầu.

### 3.3. Các Tình Huống Giả Lập Biên (Edge Cases) & Bộ 4 Giải Pháp Kỹ Thuật Đột Phá
*Nhằm bảo đảm 100% không crash app, không giảm hiệu năng và không gây nhầm lẫn dữ liệu:*
1. **Chống Nhầm Lẫn Tài Khoản Trùng Tên (Smart Format Hint)**:
   - Nếu nhập email công ty / có dấu `@` (VD: `tanmnn@360.org.vn`): App xác định 100% là Production, chỉ gửi duy nhất tới `vuahethong.net`. Nếu gõ sai mật khẩu thì dừng và báo lỗi ngay, **tuyệt đối không bao giờ fallback sang Demo**.
   - Nếu nhập username ngắn không có `@` (VD: `demo`, `morpheus`, `guest`): App ưu tiên gửi thẳng sang `demo.vuahethong.com`.
2. **Loại Bỏ Độ Trễ Khi Gõ Sai Mật Khẩu (Parallel Speculative Probing)**:
   - Đối với các tài khoản mở rộng (email ngoài), App gửi 2 request song song cùng lúc (`Future.wait`). Server nào 200 OK trước sẽ được chọn ngay lập tức; nếu cả 2 đều 401 thì báo lỗi trong **~200ms**, triệt tiêu hoàn toàn hiện tượng chậm gấp đôi (x2 lag).
3. **Chống Treo Khi 1 Server Bảo Trì (Fast-Fail Timeout 3.0s)**:
   - Cài đặt Circuit Breaker với Timeout tối đa 3.0 giây. Nếu server Demo tắt hoặc lỗi mạng 502/503, App tự ngắt và thông báo nhẹ nhàng qua Toast thay vì để màn hình quay tròn hoặc crash app.
4. **Phân Biệt Rõ Ràng Môi Trường Khi Đã Vào App (Subtle Sandbox Tag)**:
   - Màn hình Login giữ nguyên 100% form chuẩn sạch đẹp như Ảnh 1.
   - Khi vào môi trường Demo, hiển thị một huy hiệu nhỏ màu cam thanh lịch `🧪 Sandbox Demo` trên Header để người dùng phân biệt rõ ràng mà không làm mất tính thẩm mỹ.

### 3.4. Điều Kiện Tiên Quyết Triển Khai (Prerequisites)
- **Backend `demo.vuahethong.com`**: Cài đặt module `v_mobile` vào database `demo` để mở các endpoint REST API `/api/v1/mobile/*` và cấu hình CORS đầy đủ.

---

## 💡 4. ĐỊNH HƯỚNG CHUẨN HOÁ HỆ THỐNG CSKH & HỖ TRỢ KỸ THUẬT (ODOO LIVE CHAT & SESSIONS)
*Được chuẩn hóa ngày 2026-10-14 theo chỉ đạo của Sếp Tân & Ban Điều Hành 360 CORP (Chi tiết: [docs/idea_portal.md](../../docs/idea_portal.md))*

### 4.1. Bối Cảnh & Bài Toán Cốt Lõi
- **Hiện trạng lệch chuẩn**: Tin nhắn từ khách hàng Portal trên mobile đang rơi vào `Direct messages` (1-1 với Admin), khiến nhân viên trực ca không nhìn thấy và chỉ số `Sessions` tại `/home/livechat` luôn bằng 0.
- **Mục tiêu chuẩn hoá**: Kế thừa 100% module Live Chat (`im_livechat`) và Discuss (`mail.discuss`) có sẵn của Odoo Core.
  - **Kênh CSKH (Customer Care)**: Tiếp nhận tư vấn dịch vụ, hợp đồng, báo giá ➔ Tích hợp tạo nhanh `crm.lead`.
  - **Kênh Kỹ Thuật (Technical Support)**: Tiếp nhận hỗ trợ kỹ thuật, sự cố phần mềm ➔ Tích hợp tạo `helpdesk.ticket`.

### 4.2. Những Điểm Sai Bị Loại Bỏ Hoàn Toàn (Deprecated)
- ❌ **Loại bỏ**: Cơ chế Chat 1-1 (`channel_type: 'chat'`) với cá nhân Admin.
- ❌ **Loại bỏ**: Tự tạo kênh nhóm (`channel_type: 'group'`) rồi hardcode add user tĩnh bằng script, làm phá vỡ cơ chế xoay ca trực của Live Chat.
- ❌ **Loại bỏ**: Gộp chung 1 kênh không phân loại nhu cầu của khách hàng.
- ❌ **Loại bỏ**: Tự chế hardcode tên kênh ("Chăm Sóc Khách Hàng 360") & tích xanh MXH tự chế. Tên kênh và avatar bắt buộc lấy động 100% từ Odoo `im_livechat.channel`; trạng thái trực ca dùng chấm xanh trực tuyến 🟢 (Online Indicator).
- ❌ **Loại bỏ**: Triệt tiêu tên người trực (ép hiển thị logo vô danh). Odoo chuẩn bảo mật danh tính bằng trường `livechat_username` trong User Profile (hoặc `OdooBot`).

### 4.3. Cơ Chế Live Chat Session Chuẩn
- Khách hàng Portal chọn 1 trong 2 kênh hỗ trợ: **Customer Care** hoặc **Technical Support**.
- **Tên kênh động & Nhận diện chuẩn**: Header hiển thị avatar và tên kênh lấy trực tiếp từ `im_livechat.channel` trên Odoo, kèm chấm xanh trực tuyến 🟢 khi có Operator online.
- **Tên người phản hồi**: Hiển thị `OdooBot` hoặc bí danh `livechat_username` do nhân viên trực cấu hình trên Odoo.
- **Đồng bộ phiên (Session Continuity)**: Kế thừa toàn bộ tin nhắn từ phiên Web Live Chat sang App Mobile khi khách hàng đăng nhập Portal.
- Backend `v_mobile` gọi phương thức chuẩn của Odoo Live Chat để tạo **Live Chat Session** (`discuss.channel` có `channel_type: 'livechat'`).
- Tự động phân bổ phiên chat tới các Operator đang online trong mục **`Looking for help`** của ca trực.
- Tự động đếm và ghi nhận số lượng **Sessions** tại `/home/livechat` phục vụ báo cáo KPI và đánh giá chất lượng phản hồi.



