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
| **#1** | **#16455** | Tính năng Gọi thoại chuẩn Zalo/Telegram (Enterprise Voice Call) | 🟢 **P1** | Fullstack + WebRTC/Audio | 3 giờ | [TASK_16455.md](file:///media/tanma/DATA/save/mobile/docs/tasks/pending/TASK_16455_voice_calling_in_app.md) | 💡 **IDEA / PROPOSAL** |
| **#2** | **#16454** | Hoàn thiện bộ ba tính năng quản trị chat (Ghim 📌, Tắt thông báo 🔕, Ẩn/Hiện cuộc trò chuyện 🗄️) | 🟢 **P1** | Fullstack | 2.5 giờ | [TASK_16454.md](file:///media/tanma/DATA/save/mobile/docs/tasks/completed/TASK_16454_chat_management_pin_mute_archive.md) | ✅ **DONE** |
| **#3** | **#16453** | Tính năng Ghi âm & Tin nhắn Thoại chuẩn Zalo/Telegram/WhatsApp (Voice Messaging) | 🟢 **P1** | Frontend + Audio | 3 giờ | [TASK_16453.md](file:///media/tanma/DATA/save/mobile/docs/tasks/completed/TASK_16453_voice_messaging_audio_record.md) | ✅ **DONE** |
| **#4** | **#16450** | Khắc phục lỗi chưa hiển thị tin nhắn cuối (Last Message) trên danh sách hội thoại | 🟢 **P1** | Fullstack | 20 phút | [TASK_16450.md](file:///media/tanma/DATA/save/mobile/docs/tasks/completed/TASK_16450_fix_loi_chua_hien_thi_tin_nhan_cuoi_last_message.md) | ✅ **DONE** |
| **#5** | **#16451** | Khắc phục lỗi tin nhắn do chính mình gửi lại lọt vào mục "Chưa đọc" | 🟢 **P1** | Fullstack | 20 phút | [TASK_16451.md](file:///media/tanma/DATA/save/mobile/docs/tasks/completed/TASK_16451_fix_loi_tin_nhan_minh_gui_lot_vao_muc_chua_doc.md) | ✅ **DONE** |
| **#6** | **#16452** | Làm tính năng xem chi tiết người thả Reaction giống Zalo Mobile (Reaction Details BottomSheet) | 🟢 **P1** | Frontend UI | 2 giờ | [TASK_16452.md](file:///media/tanma/DATA/save/mobile/docs/tasks/completed/TASK_16452_reaction_details_bottomsheet.md) | ✅ **DONE** |
| **#7** | **#16436** | Khắc phục hardcode chi tiết ca làm việc, lấy số giờ từ API Odoo | 🔴 **P4** | Backend Odoo + App | 2 giờ | [TASK_16436.md](file:///media/tanma/DATA/save/mobile/docs/tasks/pending/TASK_16436_9_bugtimesheet_khắc_phục_đang_hard_code_chi_tiết_c.md) | ⏳ **BACKLOG** |

---

## ✅ 2. DANH MỤC TASK ĐÃ FIX & ĐÃ NGHIỆM THU (COMPLETED TASKS)

| Task ID | Tên Nhiệm Vụ | Mức độ | Layer | Chi Tiết Tài Liệu | Trạng thái |
|:---:|---|:---:|:---:|:---:|:---:|
| **#16446** | Sửa lỗi hiển thị nhầm avatar con mèo của User vào đối phương (Bùi Tuấn Kiệt) | 🟢 **P1** | Frontend UI/Header | [TASK_16446.md](file:///media/tanma/DATA/save/mobile/docs/tasks/completed/TASK_16446_fix_loi_avatar_va_nham_avatar_ca_nhan.md) | ✅ **DONE** |
| **#16447** | Sửa bộ lọc "Nhóm" bị 0 & hiển thị đầy đủ danh sách nhóm đã tạo | 🟢 **P1** | Frontend Filter/Model | [TASK_16447.md](file:///media/tanma/DATA/save/mobile/docs/tasks/completed/TASK_16447_fix_bo_loc_nhom_chat_va_hien_thi_nhom.md) | ✅ **DONE** |
| **#16448** | Sửa lỗi gửi ảnh hiện chấm than đỏ (thất bại giả) dù Odoo đã nhận thành công | 🟡 **P2** | Frontend Controller | [TASK_16448.md](file:///media/tanma/DATA/save/mobile/docs/tasks/completed/TASK_16448_fix_gui_anh_cham_than_do_optimistic_state.md) | ✅ **DONE** |
| **#16449** | Sửa lỗi `Expected singleton: res.users()` khi tạo chat 1-1 & Tối ưu tốc độ mở chat | 🟠 **P3** | Backend + Frontend | [TASK_16449.md](file:///media/tanma/DATA/save/mobile/docs/tasks/completed/TASK_16449_fix_expected_singleton_res_users_va_toi_uu_load_chat.md) | ✅ **DONE** |
| **#16443** | Đổi tiêu đề thời gian dự kiến ở timesheet thành "Tổng thời gian cho phép" | 🟢 **P1** | Frontend UI | [TASK_16443.md](file:///media/tanma/DATA/save/mobile/docs/tasks/completed/TASK_16443_12_đổi_tiêu_đề_thời_gian_dự_kiến_ở_timesheet_thành.md) | ✅ **DONE** |
| **#16438** | Fix lại btn thêm ở chat sao cho chuẩn ui/ux, đổi icon phù hợp | 🟢 **P1** | Frontend UI | [TASK_16438.md](file:///media/tanma/DATA/save/mobile/docs/tasks/completed/TASK_16438_15_fix_lại_btn_thêm_ở_chat_sao_cho_chuẩn_uiux_nhé_.md) | ✅ **DONE** |
| **#16433** | Hoàn thiện tiêu đề tab "Trực tiếp" & phản ứng bộ đếm unread | 🟢 **P1** | Frontend UI | [TASK_16433.md](file:///media/tanma/DATA/save/mobile/docs/tasks/completed/TASK_16433_6_bugui_đổi_tiêu_đề_tab_cá_nhân_sang_trực_tiếp_và_.md) | ✅ **DONE** |
| **#16440** | Tên hiển thị bị cắt mất và tin nhắn trả lời nó đang bị vỡ layout | 🟡 **P2** | Frontend UI | [TASK_16440.md](file:///media/tanma/DATA/save/mobile/docs/tasks/completed/TASK_16440_14_tên_hiển_thị_bị_cắt_mất_và_tin_nhắn_trả_lời_nó_.md) | ✅ **DONE** |
| **#16444** | Đổi lọc cá nhân thành nội bộ, thêm lọc kênh (channel) và mặc định Tất cả | 🟡 **P2** | Frontend Riverpod | [TASK_16444.md](file:///media/tanma/DATA/save/mobile/docs/tasks/completed/TASK_16444_10_đổi_lọc_chỗ_cá_nhân_thành_nội_bộ_và_lọc_những_t.md) | ✅ **DONE** |
| **#16435** | Sửa lỗi đếm số lượng Nhóm trong nút lọc Chat bị trùng lặp với Tất cả | 🟡 **P2** | Frontend Controller | [TASK_16435.md](file:///media/tanma/DATA/save/mobile/docs/tasks/completed/TASK_16435_8_bugchat_sửa_lỗi_đếm_số_lượng_nhóm_trong_nút_lọc_.md) | ✅ **DONE** |
| **#16434** | Đồng bộ số lượng cuộc trò chuyện giữa nút lọc "Tất cả" và Trang Chủ | 🟡 **P2** | Frontend Controller | [TASK_16434.md](file:///media/tanma/DATA/save/mobile/docs/tasks/completed/TASK_16434_7_bugsync_đồng_bộ_số_lượng_cuộc_trò_chuyện_giữa_nú.md) | ✅ **DONE** |
| **#16445** | Ở time sheet hiển thị chưa đúng ở phần thời gian còn lại (remaining hours) | 🟠 **P3** | Frontend Data/Format | [TASK_16445.md](file:///media/tanma/DATA/save/mobile/docs/tasks/completed/TASK_16445_11_ở_time_sheet_hiển_thị_chưa_đúng_ở_phần_thời_gia.md) | ✅ **DONE** |
| **#16442** | [BUG/FIX] Khắc phục lỗi chưa xem và đọc được file đính kèm | 🟠 **P3** | Frontend Attachment | [TASK_16442.md](file:///media/tanma/DATA/save/mobile/docs/tasks/completed/TASK_16442_13_bugfix_khắc_phục_lỗi_chưa_xem_và_đọc_được_file.md) | ✅ **DONE** |

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
   - Xóa sạch cache tin nhắn `ChatV2ChannelLocalCache.clear()`.
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


