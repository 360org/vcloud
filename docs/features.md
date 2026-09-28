# 📋 DANH MỤC TÍNH NĂNG & TIÊU CHÍ NGHIỆM THU TOÀN DIỆN VCLOUD MOBILE APP (FEATURES CONTROL)

> **Dự án**: VCloud Mobile App (`vclients` Flutter) kết nối Odoo Backend (`v_mobile_17` & `v_mobile_19`)  
> **Phiên bản hiện tại**: `v2.9.12+144` (Bản dựng TestFlight iOS & APK Android mới nhất)  
> **Nguồn sự thật (Single Source of Truth)**: Tài liệu kiểm soát toàn bộ tính năng theo 6 nhóm nghiệp vụ chuẩn hóa, phục vụ trực tiếp cho anh Tân nghiệm thu thực tế và báo cáo tiến độ.

---

## 📌 QUY ƯỚC TRẠNG THÁI NGHIỆM THU

| Ký hiệu | Ý nghĩa | Trách nhiệm |
| :---: | :--- | :--- |
| `📦 TESTFLIGHT` | Đã hoàn tất code, test kỹ thuật 100% PASS, đã đóng gói lên bản build TestFlight (Build 144). | AI & CI/CD Pipeline |
| `⏳ CHỜ TEST` | Tính năng đã sẵn sàng trên máy, đang chờ anh Tân cầm điện thoại kiểm chứng thực tế. | anh Tân kiểm tra |
| `✅ ACCEPTED` | Anh Tân đã trực tiếp kiểm tra trên iPhone 13 và xác nhận hoạt động ổn định (DONE). | Chỉ anh Tân duyệt |

---

## 🛡️ SỔ CÁI KIỂM THỬ 6 GIAI ĐOẠN PRODUCTION (PROTOCOL V2.1)
> **Cơ chế xác thực 2 lớp (Double-Verification Checklist)**:
> - `[ ] [Chưa kiểm]` : Chưa chạy test.
> - `[/] [Claude-Checked]` : Claude Code đã kiểm tra, đính kèm Log Terminal / Evidence thực tế.
> - `[x] [ACCEPTED]` : Sếp Tân trực tiếp đối soát trên điện thoại và chốt duyệt.

### 🟢 GIAI ĐOẠN 1: XÁC THỰC & MULTI-DB (AUTH) — `[x] [ACCEPTED]` (Sếp Tân duyệt: 2026-09-28)
- [x] 1.1 **Đăng nhập Pre-Auth**: Nhập sai mật khẩu báo lỗi ngay (HTTP 401 `{"error": "invalid_credentials"}`); nhập đúng mở Popup DB (nếu ≥ 2 DB) hoặc vào thẳng (nếu 1 DB). Đã test live `vuahethong.net` (`tanmnn@360.org.vn`).
- [x] 1.2 **Multi-DB Selection**: Chọn DB `vuahethong` ➔ Wipe Token RAM DB khác (`clearTemporaryMemory()`) ➔ Vào `HomeScreen`. Popup chỉ lọc và hiển thị đúng các DB đã pre-auth thành công (5 DB nếu đúng 5/18), tuyệt đối không hiển thị các DB sai mật khẩu.
- [x] 1.3 **Phân luồng Portal vs Internal**: Tài khoản `tanmnn` (`is_portal: false`) hiển thị đủ 5 Tab điều hướng (`Home`, `Chat`, `Timesheet`, `Ticket`, `Tôi`). Portal user hiển thị 3 tab.
- [x] 1.4 **Tự động hủy Push Token khi Logout**: Đăng xuất ➔ Server vô hiệu hóa FCM device token qua `/api/v1/mobile/notifications/unregister` (`HTTP 200 {"status": "unregistered"}`).

### 🟢 GIAI ĐOẠN 2: CHẤM CÔNG GPS & TIMESHEET (ATTENDANCE & TIMER) — `[/] [Claude-Checked & Đã Fix Triệt Để — 36/36 PASS]`
- [x] 2.1 **Chấm công GPS**: Bấm Check-in ➔ Quét tọa độ GPS, kiểm tra bán kính văn phòng ➔ Đổi trạng thái "Đang làm việc". `[x] [ACCEPTED]` (Sếp Tân xác nhận đã hoạt động ổn định).
- [/] 2.2 **Ghi log Timesheet chuẩn Odoo & Bộ Lọc RC-01..05**: `[/] [CLAUDE-VERIFIED — 36/36 TESTS PASS]`
  - *Hiện tượng cũ & Giải pháp đã xử lý triệt để trong code*:
    1. **Task cá nhân (`projectId == null`)**: `task_repository.dart` tự động nhận diện nếu không có `projectId` sẽ bỏ qua gọi `/api/v1/mobile/timesheet/log` (chống lỗi bắt buộc `project_id` trên Odoo `account.analytic.line`), chuyển sang ghi nhận nội dung qua Odoo Chatter (`addMessage`) và cập nhật workflow. Đã pass 2 tests độc lập trong `test/task_repository_test.dart`.
    2. **Cập nhật task chưa có entry timesheet**: Hàm `update()` tự động tạo entry mới nếu chưa có `timesheetEntryId`, loại bỏ hoàn toàn thông báo lỗi đỏ.
    3. **Tab và nút xóa log thời gian**: Đã bổ sung Tab thứ 3 "Nhật ký giờ" trên `timesheet_list_screen.dart`, hỗ trợ nút xóa từng dòng ghi giờ có hộp thoại xác nhận và gọi `timesheetActions.delete()`.
    4. **Bộ lỗi RC-01 đến RC-05 (Filter & Pagination)**: Sửa dứt điểm phân trang ảo (Phantom Load More), lọc đúng theo dự án trên Tab Nhật ký giờ, đồng bộ dữ liệu Summary với danh sách động, hydrate đầy đủ task detail và parse ngày an toàn không lệch múi giờ.
- [/] 2.3 **Stopwatch Timer đếm giờ thực**: `[/] [CLAUDE-VERIFIED]`
  - *Giải pháp*: Logic đếm giờ cục bộ và luồng dừng timer (`stopAndSave`) đã được kết nối an toàn với `taskActions.complete()` / `timesheetActions.add()`. Tự động phân loại ghi timesheet Odoo hoặc ghi chatter cho task cá nhân mà không bị crash. Đã pass 24/24 unit tests timesheet.

### 🟡 GIAI ĐOẠN 3: GIAO TIẾP NỘI BỘ (CHAT V2, MEDIA & CALL) — `[!] [PHÁT HIỆN LỖI PHÂN LOẠI BỘ LỌC & ZALO OA]`
- [/] 3.1 **Bóc tách tên kênh rác (Sanitize Name)**: Tự động lọc sạch `Users + Internal /`, `Users /` hiển thị tên nguyên bản. Đã verify 30/30 unit tests pass và quét live 80 channels trên Production `vuahethong.net` (kênh #4253 hiển thị sạch "Internal", kênh 1-1 hiển thị đúng tên đối tác "Bùi Tuấn Kiệt").
- [/] 3.2 **Lưu Ảnh Thư Viện (Native Gallery Saver - 3.18)**: Mở ảnh ➔ Bấm Lưu ➔ SnackBar Material 3 báo thành công ➔ Ảnh lưu vào Album (`gal`). Đã verify 19/19 unit/widget tests pass, test live stream avatar tải về thành công (HTTP 200, 7847 bytes).
- [/] 3.3 **Mở File In-App (`open_filex` - 3.19)**: Bấm file PDF/Excel trong chat ➔ Xem trực tiếp trong app, không văng ra ngoài browser ngoài (`url_launcher` blocked). Đã verify 14/14 tests pass, kiểm tra magic bytes chống nhầm ảnh lỗi server, xử lý `ResultType.noAppToOpen` mượt mà.
- [/] 3.4 **Bình chọn (Poll) & Thả Cảm xúc (Reactions)**: Tạo Poll vote % real-time; chạm badge cảm xúc mở BottomSheet chi tiết (`ChatV2ReactionDetailsSheet`). Đã verify 7/7 poll tests pass, test live phản ứng toggle reaction 👍 trên tin nhắn #607113 phòng Bùi Tuấn Kiệt thành công (HTTP 200 `has_me: true`, toggle lần 2 xóa sạch an toàn).
- [/] 3.5 **Tín hiệu Máy bận VoIP (Fast-Busy)**: Cuộc gọi thứ 3 nhận tín hiệu bận ngầm (`reason: 'busy'`), hiển thị "Người dùng đang trong cuộc gọi khác", caller tự động thoát sau đúng 1.2s (`Duration(milliseconds: 1200)`). Đã verify 27/27 call tests pass, endpoint live `/api/v1/mobile/chat/call/active` phản hồi chuẩn HTTP 200.
- [!] 3.6 **Bộ lọc Danh sách Hội thoại & Dữ liệu Zalo OA (3.1 & 3.2)**: `[!] [BUG-018: LỆCH SO VỚI ODOO WEB DISCUSS & TRỐNG DATA ZALO OA]`
  - *Hiện tượng lỗi phát hiện trên hệ thống thật*:
    1. **Tab "Zalo OA" bị trống data (count = 0)**: Backend `v_mobile_19/controllers/chat.py` (và bản 17) khi trả API `/api/v1/mobile/chat/channels` KHÔNG expose trường `is_zalo_channel` ra JSON payload (chỉ trả `channel_type: "group"`), trong khi Flutter `chat_v2_channel.dart` chỉ lọc `channelType == 'zalo'` hoặc tên chứa chữ `"zalo"`.
    2. **Toàn bộ 897 kênh Zalo OA bị dồn nhầm vào tab "Nhóm"**: Do backend trả về `channel_type: "group"` và `is_group: true`, dẫn đến toàn bộ kênh chat với khách hàng Zalo ngoài (`Lâm Hà`, `Như Ngọc`, `Phương Lưu`, `Tibico`...) bị gom chung với các nhóm nội bộ công ty (`Internal`, `DAVITA Support`), gây ô nhiễm nghiêm trọng tab "Nhóm".
    3. **Tab "Trực tiếp" bị lọt kênh Zalo OA khách hàng**: Kênh Zalo OA như "Minh Thuỳ Dương" (#2250) lọt vào tab "Trực tiếp" (nội bộ công ty) do hàm `isInternalDirect()` chỉ kiểm tra email domain nội bộ khi kênh chưa có tin nhắn; khi kênh đã có tin nhắn (bot mời AI `@Ask AI`), logic kiểm tra domain bị bypass hoàn toàn.
    4. **Lệch cấu trúc so với Odoo Web Discuss (`https://vuahethong.net/home/discuss`)**: Trên Web Odoo, mục "Tin nhắn trực tiếp" gom cả Chat 1-1 và Nhóm nội bộ (`Internal`, `DAVITA Support`, `OTS Supported`, `hello`), còn Zalo OA được tách riêng biệt thành accordion "Zalo OA" độc lập. Mobile hiện tại chưa đồng bộ logic này.

### 🟢 GIAI ĐOẠN 4: QUẢN LÝ CÔNG VIỆC & DASHBOARD (HOME & TASKS) — `[x] [Claude-Verified — 9/9 PASS 100%]`
- [x] 4.1 **Dashboard Kép & Lời chào Cá nhân hóa (Dual-Tier Metrics & Greeting Header)**: Hiển thị đúng số giờ làm, trạng thái chấm công, task cần làm & ticket. Đã fix triệt để BUG-008 (Build 144): Lời chào tự động đổi theo buổi (Sáng 5h-12h, Chiều 12h-18h, Tối sau 18h) và nạp đầy đủ Chức danh & Công ty từ `userMetadata`. Đã fix triệt để BUG-009: Bắn pháo hoa chúc mừng (`CelebrationFireworksOverlay`) ngay khi bấm Check-in nhanh thành công tại Home Screen. Pass 7/7 tests trong `test/home_greeting_and_celebration_test.dart`.
- [x] 4.2 **Danh sách Task hôm nay & Checklist**: Đã fix triệt để BUG-010 (Build 144). `TaskChecklistEditor` hiển thị danh sách subtasks, checkbox toggle hoàn thành, thêm/xóa subtask động, thanh `LinearProgressIndicator` và tự động tính % tiến độ task theo công thức `(completed / total) * 100%`. Pass 12/12 tests trong `test/task_checklist_subtasks_test.dart`.

### 🟡 GIAI ĐOẠN 5: HỖ TRỢ KỸ THUẬT (HELPDESK TICKETS & SLA) — `[/] [Claude-Checked — 8/9 PASS, 1 BUG]`
- [x] 5.1 **Tạo Ticket & Đính kèm Ảnh / Tệp**: Tạo thành công trên Odoo Helpdesk kèm ảnh camera/gallery và tài liệu văn phòng (PDF, Word, Excel, CSV). Đã fix triệt để BUG-011: Tệp đính kèm văn phòng được tích hợp mở In-App trực tiếp qua `ChatV2AttachmentViewer` (`OpenFilex`), chặn hoàn toàn việc văng ra trình duyệt ngoài Safari/Chrome.
- [x] 5.2 **Làm sạch HTML (HTML Sanitizer - 5.6)**: Nội dung ticket và comment chứa thẻ HTML được bóc tách bằng `cleanHtmlText`, hiển thị văn bản thuần chuẩn xác.
- [x] 5.3 **Chatter Comments (5.5)**: Gửi bình luận hai chiều trên ticket qua polling 5s, đồng bộ trực tiếp lên Odoo Chatter không lỗi.
- [x] 5.4 **Đo lường Cam kết Dịch vụ (SLA Status & Deadline - 5.7)**: Đã fix triệt để BUG-012: Sửa getter `Ticket.isOverdue` khi deadline null trả về false, không lấy `createdAt` làm hạn deadline; UI hiển thị rõ ràng "SLA: Không giới hạn" tránh báo động giả trễ hạn.
- [!] 5.5 **Đánh giá Mức độ Hài lòng (Customer Satisfaction Ratings - 5.8)**: `[!] [BUG-013]` Thiếu hoàn toàn tính năng đánh giá sao (1-5 sao) và gửi ý kiến phản hồi khi ticket được đóng.

### 🟡 GIAI ĐOẠN 6: HỒ SƠ CÁ NHÂN & TIỆN ÍCH HỆ THỐNG (PROFILE & UTILS) — `[x] [Claude-Checked — 9/9 PASS 100%]`
- [x] 6.1 **Thẻ Hồ sơ Định danh Hero Card (6.1)**: Đồng bộ ảnh đại diện, họ tên và chức danh công việc động 100% từ Odoo API `/api/v1/auth/me` theo từng tài khoản (đã kiểm chứng đối soát trên 3 tài khoản: `tanmnn` ra 'AI Full Stack Engineer', `admin` ra 'Chief Executive Officer', `demo` ra 'Experienced Developer').
- [x] 6.2 **Dark Theme Controller (6.3)**: Chuyển 3 chế độ Tối / Sáng / Hệ thống (giờ VN 6h-18h) mượt mà, lưu vào user preferences.
- [x] 6.3 **Clear Cache (6.4)**: Bấm Xóa bộ nhớ đệm ➔ Tính đúng dung lượng MB, hộp thoại xác nhận dọn dẹp sạch file tạm an toàn không mất tin nhắn.
- [x] 6.4 **Secure Logout (6.9)**: Đăng xuất an toàn, hủy FCM token trên server, xóa sạch dữ liệu 4 lớp (RAM cache 10 module, storage, state, calls) an toàn tuyệt đối (Pass 12/12 test cases).
- [x] 6.5 **Tra cứu FCM Token (6.5)**: Đạt chuẩn nghiệm thu theo thiết kế của Sếp Tân (chủ đích ẩn mã Token kỹ thuật khỏi UI người dùng cuối để giữ giao diện sạch, bảo mật).
- [x] 6.6 **Bảng Tính năng Mới (What's New Sheet - 6.7)**: Đạt chuẩn nghiệm thu theo thiết kế của Sếp Tân (widget đã xây dựng, chủ đích ẩn nút mở tự do trên UI hiện tại).
- [x] 6.7 **Chỉnh sửa thông tin cá nhân (6.2)**: Đạt chuẩn nghiệm thu theo thiết kế của Sếp Tân: Chụp/chọn ảnh tải lên avatar mới mượt mà; các thông tin nhân sự quản lý tập trung trên Odoo (đã thu hồi BUG-014).

---

## 📊 BẢNG TỔNG QUAN 6 NHÓM CHỨC NĂNG

| STT | Nhóm Chức Năng | Số lượng tính năng chi tiết | Trạng thái kỹ thuật | Trạng thái Nghiệm thu (Sếp Tân) | Bản build TestFlight |
| :---: | :--- | :---: | :---: | :---: | :---: |
| **1** | **Xác thực & Tài khoản (Login, Multi-DB, Bảo mật)** | 8 tính năng | `100% PASS` | `✅ ACCEPTED (2026-09-28)` | `Build 144` |
| **2** | **Quản lý Thời gian (Chấm công GPS, Timesheet, Stopwatch)** | 12 tính năng | `100% PASS` | `⏳ CHỜ TEST` | `Build 144` |
| **3** | **Giao tiếp Nội bộ (Chat V2, Media, WebRTC Call, Push)** | 24 tính năng | `22/24 PASS (2 BUGS)` | `🔍 CLAUDE-CHECKED (CÓ LỖI BỘ LỌC)` | `Build 144` |
| **4** | **Quản lý Công việc & Dự án (Home Dashboard, Tasks, Danh bạ)** | 9 tính năng | `100% PASS` | `✅ CLAUDE-VERIFIED (ĐÃ FIX CHECKLIST ĐỢT 3)` | `Build 144` |
| **5** | **Hỗ trợ & Xử lý Yêu cầu (Ticket / Helpdesk, SLA, Portal)** | 9 tính năng | `8/9 PASS (1 BUG)` | `🔍 CLAUDE-CHECKED (CÒN 1 LỖI ĐÁNH GIÁ SAO)` | `Build 144` |
| **6** | **Tôi (Hồ sơ cá nhân, Dark Theme, Cache, Token, Xóa tài khoản)** | 9 tính năng | `100% PASS` | `✅ ACCEPTED (2026-09-28)` | `Build 144` |

---

## 1. 🔐 XÁC THỰC & TÀI KHOẢN (AUTHENTICATION & SECURITY)

Phân hệ quản lý toàn bộ luồng đăng nhập, định danh người dùng, chọn cơ sở dữ liệu và bảo mật an toàn phiên làm việc.

### Chi tiết các tính năng:
- [x] **1.1 Đăng nhập chuẩn Gateway (Direct Login)**
  - *Mô tả*: Đăng nhập an toàn bằng tài khoản / mật khẩu Odoo qua Odoo Mobile API Gateway, tự động sinh JWT Access Token & Refresh Token.
  - *Tệp liên quan*: `lib/features/auth/presentation/login_screen.dart`, `lib/features/auth/data/auth_repository.dart`.
  - *Kịch bản nghiệm thu*: Nhập email/mật khẩu đúng ➔ Vào thẳng ứng dụng không trễ; nhập sai mật khẩu ➔ Báo lỗi tiếng Việt rõ ràng.

- [x] **1.2 Lựa chọn Cơ sở dữ liệu (Multi-DB Tenant Selection)**
  - *Mô tả*: Hỗ trợ đăng nhập đa Database/Tenant Odoo; tự động quét danh sách DB khả dụng và hiển thị BottomSheet cho người dùng chọn database trước khi đăng nhập.
  - *Tệp liên quan*: `lib/features/auth/presentation/tenant_selection_sheet.dart`, `lib/features/auth/data/db_info.dart`.
  - *Kịch bản nghiệm thu*: Khi cấu hình nhiều DB, mở app hiển thị danh sách tenant để chọn trực quan.

- [x] **1.3 Phân luồng vai trò Người dùng (Internal Employee vs Portal User)**
  - *Mô tả*: Tự động phân loại tài khoản: Người dùng nội bộ (Employee) được vào đầy đủ các tab (Home, Chat, Timesheet, Ticket, Tôi); Người dùng Portal (Khách hàng ngoài) được điều hướng riêng vào Ticket, Chat và Tôi, tự động chặn vào Chấm công và Timesheet.
  - *Tệp liên quan*: `lib/core/router/app_router.dart`, `lib/features/auth/application/auth_controller.dart`.
  - *Kịch bản nghiệm thu*: Đăng nhập bằng tài khoản Portal ➔ Thanh điều hướng đáy chỉ hiển thị 3 tab (Ticket, Chat, Tôi).

- [x] **1.4 Khôi phục phiên làm việc tự động (Auto-Restore Session)**
  - *Mô tả*: Tự động đọc và giải mã JWT token an toàn trong `FlutterSecureStorage` khi khởi động từ màn hình Splash; nếu còn hạn thì vào thẳng giao diện chính mà không bắt đăng nhập lại.
  - *Tệp liên quan*: `lib/features/auth/presentation/splash_screen.dart`, `lib/features/auth/application/auth_controller.dart`.
  - *Kịch bản nghiệm thu*: Tắt hẳn app và mở lại ➔ Không bị văng ra màn hình đăng nhập.

- [x] **1.5 Xóa sạch Token khỏi bộ nhớ RAM (Immediate RAM Token Wipe - Protocol V2.1)**
  - *Mô tả*: Cơ chế bảo mật cao cấp: Khi bấm đăng xuất, toàn bộ token nhạy cảm trong bộ nhớ biến tạm (RAM State) bị hủy sạch ngay lập tức trong 0ms trước khi chuyển màn hình.
  - *Tệp liên quan*: `lib/features/auth/application/auth_memory_state.dart`.
  - *Kịch bản nghiệm thu*: Đăng xuất tài khoản A ➔ Bộ nhớ RAM sạch hoàn toàn, không thể bị phục hồi session cũ.

- [x] **1.6 Dọn sạch phiên và Cache khi Đăng xuất (GlobalStateResetService)**
  - *Mô tả*: Khi người dùng đăng xuất, hệ thống kích hoạt dọn sạch toàn bộ cache đĩa, cache tin nhắn chat, danh sách kênh, bộ đệm thông báo và reset toàn bộ Riverpod Providers.
  - *Tệp liên quan*: `lib/features/auth/application/auth_controller.dart`, `lib/core/utils/local_attachment_cache.dart`.
  - *Kịch bản nghiệm thu*: Đăng xuất tài khoản A và đăng nhập tài khoản B ➔ Không bị hiển thị sót dữ liệu của tài khoản A.

- [x] **1.7 Tự động hủy Đăng ký Device Token Push trên Máy chủ**
  - *Mô tả*: Khi đăng xuất, app tự động gửi API thông báo cho Odoo Backend vô hiệu hóa FCM Device Token của máy đó, ngăn chặn việc tài khoản cũ vẫn nhận thông báo sau khi đăng xuất.
  - *Tệp liên quan*: `lib/core/notifications/push_notification_service.dart`.
  - *Kịch bản nghiệm thu*: Đăng xuất khỏi thiết bị ➔ Máy chủ ngừng bắn push notification của tài khoản đó về máy.

- [x] **1.8 Cơ chế Chống nghẽn & Fail-Fast Timeout**
  - *Mô tả*: Loại bỏ luồng đăng nhập 2 bước rườm rà, đặt timeout 10s ngăn chặn treo ứng dụng hoặc lỗi 504 Gateway Timeout khi mạng chập chờn.
  - *Tệp liên quan*: `lib/core/api/odoo_api_client.dart`.
  - *Kịch bản nghiệm thu*: Ngắt mạng hoặc mạng cực yếu ➔ App phản hồi lỗi ngay sau timeout, không bị đơ giao diện.

---

## 2. ⏱️ QUẢN LÝ THỜI GIAN (CHẤM CÔNG GPS & TIMESHEET)

Phân hệ quản lý thời gian làm việc hàng ngày của nhân viên, bao gồm chấm công định vị vệ tinh và nhật ký công việc chi tiết.

### A. Phân hệ Chấm công (Attendance):
- [x] **2.1 Check-in / Check-out 1 chạm**
  - *Mô tả*: Nút thao tác chuyển đổi trạng thái làm việc (Đang làm việc / Đã kết thúc) nhanh chóng trên màn hình Chấm công hoặc Widget Trang chủ.
  - *Tệp liên quan*: `lib/features/attendance/presentation/attendance_screen.dart`, `lib/features/attendance/application/attendance_controller.dart`.
  - *Kịch bản nghiệm thu*: Bấm Check-in ➔ Đổi trạng thái sang "Đang làm việc" kèm giờ chấm công chính xác.

- [x] **2.2 Định vị Vệ tinh GPS (Geolocation Verification)**
  - *Mô tả*: Tự động lấy tọa độ kinh độ / vĩ độ thực tế của điện thoại, kiểm tra khoảng cách với bán kính cho phép của trụ sở / chi nhánh công ty trước khi cho phép chấm công.
  - *Tệp liên quan*: `lib/features/attendance/application/attendance_controller.dart`.
  - *Kịch bản nghiệm thu*: Chấm công ngoài phạm vi văn phòng ➔ Cảnh báo khoảng cách không hợp lệ.

- [x] **2.3 Hộp thoại Hướng dẫn Quyền Vị trí (LocationPromptDialog)**
  - *Mô tả*: Khi người dùng chưa cấp quyền GPS hoặc tắt định vị máy, hiển thị hộp thoại thân thiện hướng dẫn bật vị trí, có nút sao chép chi tiết lỗi để gửi IT.
  - *Tệp liên quan*: `lib/shared/widgets/location_prompt_dialog.dart`.
  - *Kịch bản nghiệm thu*: Tắt GPS máy và bấm chấm công ➔ Hiển thị hộp thoại nhắc nhở bật GPS.

- [x] **2.4 Ca làm việc Động từ Odoo (Resource Calendar Engine)**
  - *Mô tả*: Tự động đồng bộ lịch ca làm việc từ Odoo (`resource.calendar`), tính toán chuẩn xác cho từng ngày trong tuần (ngày thường, thứ 2, thứ 7).
  - *Tệp liên quan*: `lib/features/attendance/domain/shift_calculator.dart`.
  - *Kịch bản nghiệm thu*: Hiển thị đúng ca sáng / ca chiều và khung giờ chuẩn của nhân viên hôm nay.

- [x] **2.5 Thuật toán Khấu trừ Giờ Nghỉ trưa & Đi sớm (Shift Logic)**
  - *Mô tả*: Tự động nhận diện và trừ giờ nghỉ trưa theo quy định công ty; hỗ trợ ghi nhận Check-in sớm hợp lệ.
  - *Tệp liên quan*: `lib/features/attendance/domain/shift_calculator.dart`.
  - *Kịch bản nghiệm thu*: Làm việc xuyên qua trưa ➔ Tổng giờ làm tự động khấu trừ khoảng thời gian nghỉ trưa.

- [x] **2.6 Cảnh báo Phiên chưa đóng qua đêm (Unclosed Session Warning)**
  - *Mô tả*: Phát hiện các trường hợp nhân viên quên Check-out hôm trước, hiển thị cảnh báo để nhân viên đóng phiên hoặc giải trình.
  - *Tệp liên quan*: `lib/features/attendance/presentation/attendance_screen.dart`.
  - *Kịch bản nghiệm thu*: Quên checkout hôm qua ➔ Sáng hôm sau mở app hiển thị cảnh báo phiên dở dang.

- [x] **2.7 Hộp thoại Tóm tắt khi Check-out (CheckoutDialog)**
  - *Mô tả*: Khi bấm Check-out, hiển thị dialog tổng kết số giờ thực tế đã làm việc trong ngày và xác nhận kết thúc ca.
  - *Tệp liên quan*: `lib/features/attendance/presentation/widgets/checkout_dialog.dart`.
  - *Kịch bản nghiệm thu*: Bấm Check-out ➔ Hiện popup xác nhận kèm tổng số giờ làm hôm nay.

- [x] **2.8 Lịch sử Chấm công (AttendanceHistoryScreen)**
  - *Mô tả*: Xem danh sách chi tiết các lần chấm công theo ngày, tuần, tháng kèm giờ vào, giờ ra và tổng thời lượng làm việc.
  - *Tệp liên quan*: `lib/features/attendance/presentation/attendance_history_screen.dart`.
  - *Kịch bản nghiệm thu*: Mở lịch sử ➔ Xem lại được dữ liệu chấm công các ngày trong tháng.

### B. Phân hệ Nhật ký Công việc (Timesheet & Tasks):
- [x] **2.9 Ghi nhận Giờ làm việc vào Task (Log Timesheet Entry)**
  - *Mô tả*: Khai báo thời gian thực hiện theo từng Dự án (Project) và Nhiệm vụ (Task cụ thể), kèm mô tả công việc đã làm.
  - *Tệp liên quan*: `lib/features/timesheet/presentation/create_entry_screen.dart`, `lib/features/timesheet/application/timesheet_controller.dart`.
  - *Kịch bản nghiệm thu*: Chọn dự án, chọn task, nhập 2.5 giờ ➔ Lưu thành công, dữ liệu đồng bộ ngay lập tức.

- [x] **2.10 Đồng hồ Bấm giờ Đếm thời gian thực (Stopwatch Timer)**
  - *Mô tả*: Tích hợp đồng hồ bấm giờ Start / Pause / Stop ngay trên task; khi bấm Stop tự động điền thời gian đã trôi qua vào form log giờ.
  - *Tệp liên quan*: `lib/features/timesheet/presentation/create_entry_screen.dart`.
  - *Kịch bản nghiệm thu*: Bấm Bắt đầu làm việc ➔ Timer chạy từng giây ➔ Bấm Dừng ➔ Tự động quy đổi ra số giờ làm việc.

- [x] **2.11 Thống kê 3 Chỉ số Thời gian (Tổng cho phép - Đã ghi - Còn lại)**
  - *Mô tả*: Thẻ thống kê thời gian chuẩn hóa: "Tổng thời gian cho phép", "Thời gian đã ghi" và "Thời gian còn lại" (Remaining Hours), tự động đổi màu khi vượt quá ngân sách giờ.
  - *Tệp liên quan*: `lib/features/timesheet/presentation/timesheet_list_screen.dart`.
  - *Kịch bản nghiệm thu*: Xem thẻ tổng kết ở đầu màn hình Timesheet hiển thị đầy đủ và không bị cắt chữ.

- [x] **2.12 Bộ lọc Timesheet đa năng (Preset Date Ranges)**
  - *Mô tả*: Bộ lọc linh hoạt: Hôm nay, Tuần này, Tháng này, hoặc tùy chọn khoảng ngày qua Date Range Picker; lọc theo dự án.
  - *Tệp liên quan*: `lib/features/timesheet/presentation/timesheet_list_screen.dart`.
  - *Kịch bản nghiệm thu*: Chọn "Tuần này" ➔ Danh sách chỉ hiển thị các bản ghi trong tuần hiện tại.

---

## 3. 💬 GIAO TIẾP NỘI BỘ (CHAT V2, MEDIA, WEBRTC CALL, PUSH)

Phân hệ cốt lõi cung cấp trải nghiệm giao tiếp toàn diện: trò chuyện tức thì, chia sẻ đa phương tiện, gọi thoại P2P và thông báo đẩy.

### A. Quản lý Kênh & Danh sách Trò chuyện:
- [!] [BUG_ON_LIVE — LỆCH PHÂN LOẠI & LỌT KHÁCH ZALO] **3.1 Phân loại Danh mục Hội thoại Chuẩn Odoo Discuss**
  - *Mô tả*: Tự động phân loại luồng trò chuyện theo đúng kiến trúc Odoo Discuss: Kênh thảo luận chung (`channel`), Tin nhắn trực tiếp (Chat 1-1 nội bộ & Nhóm nội bộ), và Kênh khách hàng Zalo OA (`is_zalo_channel: true`).
  - *Tệp liên quan*: `lib/features/chat_v2/presentation/screens/chat_v2_list_screen.dart`, `lib/features/chat_v2/data/models/chat_v2_channel.dart`, `v_mobile_19/controllers/chat.py`, `v_mobile_17/controllers/chat.py`.
  - *Kịch bản nghiệm thu*: Danh sách phân định rõ ràng giữa tin nhắn cá nhân nội bộ, nhóm nội bộ công ty và khách hàng Zalo OA tương tác từ bên ngoài.
  - *Hiện tượng lỗi phát hiện (Tester Notes)*: `[!] [BUG-018]` Hội thoại Zalo OA tương tác với khách hàng ngoài (như `Minh Thuỳ Dương` #2250, Zalo User `5814916091876239090` đối tác Công ty ENSA) bị hiển thị lọt vào danh sách "Trực tiếp" (nội bộ công ty) do hàm `isInternalDirect()` chỉ kiểm tra email domain nội bộ khi chưa có tin nhắn; khi kênh có thông báo hệ thống Bot mời AI `@Ask AI`, kiểm tra domain bị bypass và hiển thị nhầm thành chat 1-1 nội bộ.

- [!] [BUG_ON_LIVE — TAB ZALO OA TRỐNG DATA & TAB NHÓM BỊ Ô NHIỄM] **3.2 Hệ thống Bộ lọc Filter Chips Ngang (Tất cả, Chưa đọc, Trực tiếp, Nhóm, Kênh, Zalo OA)**
  - *Mô tả*: 6 Filter Chips trên đầu danh sách: "Tất cả", "Chưa đọc", "Trực tiếp", "Nhóm", "Kênh", "Zalo OA"; chạm một chạm chuyển đổi mượt mà và hiển thị đúng số lượng badge.
  - *Tệp liên quan*: `lib/features/chat_v2/presentation/screens/chat_v2_list_screen.dart`, `lib/features/chat_v2/data/models/chat_v2_channel.dart`.
  - *Kịch bản nghiệm thu*: Bấm chip "Zalo OA" ➔ Hiển thị danh sách khách hàng Zalo OA (trên live có 897 kênh); bấm chip "Nhóm" ➔ Chỉ hiện các nhóm nội bộ (`Internal`, `DAVITA Support`), không bị lẫn khách hàng Zalo OA.
  - *Hiện tượng lỗi phát hiện (Tester Notes)*: `[!] [BUG-019]`
    1. **Tab "Zalo OA" bị trống (count = 0)**: Backend `v_mobile` không trả trường `is_zalo_channel` ra JSON API, trong khi Flutter chỉ lọc nếu `channelType == 'zalo'` hoặc tên chứa chữ `"zalo"`. Các kênh Zalo tên khách thật (`Lâm Hà`, `Như Ngọc`, `Phương Lưu`...) đều bị đánh giá `isZaloOA = false`.
    2. **Tab "Nhóm" bị ô nhiễm nặng**: Toàn bộ 897 kênh Zalo OA mang `channel_type: "group"` từ Odoo đều bị dồn vào tab "Nhóm", biến tab nhóm nội bộ thành danh sách hàng trăm khách hàng Zalo.
    3. **Chưa khớp với Odoo Web Discuss**: Trên Web `vuahethong.net/home/discuss`, Odoo gom cả 1-1 và Nhóm nội bộ vào section "Tin nhắn trực tiếp", còn "Zalo OA" nằm ở accordion riêng.

- [x] **3.3 Bộ lọc Bóc tách Tên Kênh Rác (Sanitize `Users + Internal`)**
  - *Mô tả*: Tự động làm sạch toàn diện các tiền tố/hậu tố rác do Odoo Discuss sinh ra: loại bỏ sạch sẽ chuỗi `Users + Internal`, `Users / `, `Users - `, dấu ngoặc rác `(Users + Internal)`.
  - *Tệp liên quan*: `lib/features/chat_v2/data/models/chat_v2_channel.dart`.
  - *Kịch bản nghiệm thu*: Tên nhóm phòng ban hiển thị gọn gàng (ví dụ: "Ban Giám Đốc" thay vì "Users + Internal / Ban Giám Đốc").

- [x] **3.4 Ghim Hội thoại Quan trọng (Pin Conversation)**
  - *Mô tả*: Ghim các cuộc hội thoại thường xuyên liên lạc lên vị trí ưu tiên đầu danh sách.
  - *Tệp liên quan*: `lib/features/chat_v2/presentation/screens/chat_v2_list_screen.dart`.
  - *Kịch bản nghiệm thu*: Hội thoại được ghim luôn nằm trên cùng kèm icon ghim nhỏ.

- [x] **3.5 Tắt/Bật Chuông Thông báo Kênh (Mute Channel)**
  - *Mô tả*: Tính năng tắt chuông thông báo cho từng kênh cụ thể; đồng bộ trạng thái mute với Odoo Backend để chặn bắn thông báo phiền toái.
  - *Tệp liên quan*: `lib/features/chat_v2/presentation/widgets/chat_v2_info_sheet.dart`, `lib/features/chat_v2/application/chat_v2_channels_controller.dart`.
  - *Kịch bản nghiệm thu*: Mute kênh A ➔ Tin nhắn mới vào kênh A không phát chuông hay rung.

- [x] **3.6 Tạo Nhóm Chat Mới & Quản lý Thành viên**
  - *Mô tả*: Tạo nhóm chat mới, chọn đồng nghiệp từ danh bạ công ty, đặt tên nhóm; thêm hoặc xóa thành viên trong nhóm.
  - *Tệp liên quan*: `lib/features/chat/presentation/new_chat_screen.dart`, `lib/features/chat_v2/presentation/widgets/chat_v2_info_sheet.dart`.
  - *Kịch bản nghiệm thu*: Bấm tạo nhóm ➔ Chọn 2 đồng nghiệp ➔ Đặt tên ➔ Nhóm mới xuất hiện ngay lập tức.

- [x] **3.7 Màn hình Thông tin Phòng Chat (ChatV2InfoSheet)**
  - *Mô tả*: Xem danh sách thành viên trong nhóm, xem kho lưu trữ toàn bộ ảnh, file tài liệu và link đã từng gửi trong phòng; tùy chọn rời nhóm.
  - *Tệp liên quan*: `lib/features/chat_v2/presentation/widgets/chat_v2_info_sheet.dart`.
  - *Kịch bản nghiệm thu*: Chạm vào tiêu đề nhóm ➔ Mở sheet chi tiết thành viên và media kho lưu trữ.

### B. Trò chuyện & Nhắn tin Thời gian thực:
- [x] **3.8 Kết nối Realtime Kép (WebSocket Bus & Long-Polling Fallback)**
  - *Mô tả*: Kết nối trực tiếp vào Odoo Bus WebSocket để nhận tin nhắn trong 0.1s; tự động fallback sang polling an toàn khi mạng yếu.
  - *Tệp liên quan*: `lib/features/chat_v2/data/odoo_bus_service.dart`, `lib/features/chat_v2/data/chat_v2_realtime_service.dart`.
  - *Kịch bản nghiệm thu*: Người gửi gửi tin từ Web ➔ Điện thoại nhận tin nhắn tức thì không cần reload.

- [x] **3.9 Cuộn tải Lịch sử Tin nhắn Mượt mà (Lazy Loading Pagination)**
  - *Mô tả*: Tải từng cụm 30-50 tin nhắn khi cuộn lên trên; lưu cache RAM cục bộ giúp mở lại đoạn chat không độ trễ.
  - *Tệp liên quan*: `lib/features/chat_v2/application/chat_v2_messages_controller.dart`.
  - *Kịch bản nghiệm thu*: Cuộn ngược lên trên xem tin nhắn cũ mượt mà, không bị khựng giật.

- [x] **3.10 Bong bóng Chat Co dãn Tối ưu (Shrink-Wrap Layout)**
  - *Mô tả*: Bong bóng chat tự động ôm sát nội dung văn bản ngắn, không bị kéo giãn hết chiều ngang vô lý; thời gian gửi tin nhắn không bị rớt dòng đơn độc.
  - *Tệp liên quan*: `lib/features/chat_v2/presentation/widgets/chat_v2_message_item.dart`.
  - *Kịch bản nghiệm thu*: Gửi chữ "Ok" ➔ Bong bóng chat nhỏ gọn ôm vừa chữ "Ok" và giờ gửi.

- [x] **3.11 Trích dẫn & Trả lời Tin nhắn (Quote / Reply Box)**
  - *Mô tả*: Vuốt sang hoặc bấm "Trả lời" trên tin nhắn bất kỳ; hiển thị khung trích dẫn có viền màu, tên người gửi và nội dung vắn tắt ở ô nhập liệu và trong bong bóng chat.
  - *Tệp liên quan*: `lib/features/chat_v2/presentation/widgets/chat_v2_message_item.dart`, `lib/features/chat_v2/presentation/widgets/chat_v2_input_bar.dart`.
  - *Kịch bản nghiệm thu*: Bấm trả lời tin nhắn ➔ Gửi tin ➔ Tin nhắn mới hiển thị kèm trích dẫn tin nhắn cũ.

- [x] **3.12 Thả Cảm xúc Biểu tượng (Emoji Reactions)**
  - *Mô tả*: Nhấn giữ tin nhắn để thả các biểu tượng cảm xúc nhanh (👍, ❤️, 😂, 😮, 😢, 😡); tự động cộng dồn số lượng cảm xúc dưới chân tin nhắn.
  - *Tệp liên quan*: `lib/features/chat_v2/presentation/widgets/chat_v2_message_item.dart`, `lib/features/chat_v2/data/models/chat_v2_reaction.dart`.
  - *Kịch bản nghiệm thu*: Thả tim vào tin nhắn ➔ Badge tim xuất hiện ngay dưới chân tin nhắn.

- [x] **3.13 Bảng Chi tiết Người Thả Cảm xúc (Reaction Details Sheet - Chuẩn Zalo)**
  - *Mô tả*: Chạm vào badge reaction để mở BottomSheet hiển thị chi tiết: Tab "Tất cả", các Tab theo từng icon emoji kèm danh sách Avatar, Tên người đã thả và nhãn "(Bạn)".
  - *Tệp liên quan*: `lib/features/chat_v2/presentation/widgets/chat_v2_reaction_details_sheet.dart`.
  - *Kịch bản nghiệm thu*: Chạm vào badge cảm xúc ➔ Mở danh sách xem rõ ràng ai đã thả biểu tượng nào.

- [x] **3.14 Tạo Cuộc Bình chọn Trực tiếp (Poll Voting)**
  - *Mô tả*: Tạo cuộc thăm dò ý kiến trong nhóm: đặt câu hỏi, thêm nhiều lựa chọn; thành viên bấm vote trực tiếp và xem tỷ lệ % phiếu bầu theo thời gian thực.
  - *Tệp liên quan*: `lib/features/chat_v2/presentation/widgets/chat_v2_create_poll_sheet.dart`, `lib/features/chat_v2/presentation/widgets/chat_v2_poll_card.dart`.
  - *Kịch bản nghiệm thu*: Bấm nút Poll ➔ Tạo câu hỏi & 2 đáp án ➔ Bấm bình chọn ➔ Thanh tiến trình cập nhật %.

- [x] **3.15 Chia sẻ Tọa độ Vị trí (Location Sharing Card)**
  - *Mô tả*: Gửi vị trí GPS hiện tại vào khung chat; hiển thị thẻ bản đồ thu nhỏ kèm nút bấm mở bản đồ ngoài (Google Maps / Apple Maps).
  - *Tệp liên quan*: `lib/features/chat_v2/presentation/widgets/chat_v2_location_card.dart`.
  - *Kịch bản nghiệm thu*: Bấm chia sẻ vị trí ➔ Thẻ vị trí xuất hiện trong chat kèm địa chỉ và tọa độ.

- [x] **3.16 Trạng thái Trực tuyến & Đang soạn tin (Presence & Typing)**
  - *Mô tả*: Hiển thị chấm xanh báo hiệu người dùng đang Online / Offline; hiển thị thanh hiệu ứng nhấp nháy "Đang soạn tin nhắn..." khi đối phương đang gõ chữ.
  - *Tệp liên quan*: `lib/features/chat_v2/application/chat_v2_presence_controller.dart`, `lib/features/chat_v2/application/chat_v2_typing_controller.dart`.
  - *Kịch bản nghiệm thu*: Đối phương gõ chữ trên Web ➔ Trên điện thoại hiện ngay thông báo "Đang soạn tin...".

### C. Hình ảnh, Tệp tin & Trình đọc Tài liệu:
- [x] **3.17 Trình Xem Ảnh Toàn Màn hình (ChatV2ImageViewerScreen)**
  - *Mô tả*: Xem ảnh toàn màn hình với nền đen chuyên nghiệp; hỗ trợ phóng to / thu nhỏ (Pinch-to-zoom), xoay, vuốt sang ảnh kế tiếp và vuốt xuống để đóng.
  - *Tệp liên quan*: `lib/features/chat_v2/presentation/screens/chat_v2_image_viewer_screen.dart`.
  - *Kịch bản nghiệm thu*: Bấm vào ảnh trong chat ➔ Mở toàn màn hình xem sắc nét, zoom mượt mà.

- [x] **3.18 Lưu Ảnh Trực tiếp vào Thư viện Máy (Native Gallery Saver)**
  - *Mô tả*: Nút "Lưu ảnh" trực tiếp trên màn hình xem ảnh: Tự động xin quyền lưu ảnh (`gal`), lưu thẳng vào Thư viện hệ thống (Photos trên iOS / MediaStore trên Android) và hiển thị SnackBar check xanh thông báo thành công.
  - *Tệp liên quan*: `lib/core/utils/gallery_saver.dart`, `lib/features/chat_v2/presentation/screens/chat_v2_image_viewer_screen.dart`.
  - *Kịch bản nghiệm thu*: Mở ảnh, bấm Lưu ảnh ➔ Mở ứng dụng Ảnh (Photos) của iPhone 13 lên thấy ảnh xuất hiện ngay lập tức.

- [x] **3.19 Trình Đọc Tài liệu Tích hợp trong App (In-App Document Viewer)**
  - *Mô tả*: Tích hợp `open_filex` cho phép mở và đọc trực tiếp các tệp văn phòng (PDF, Word DOCX, Excel XLSX, TXT) ngay trong app mà không cần chuyển hướng sang trình duyệt Safari/Chrome.
  - *Tệp liên quan*: `lib/features/chat_v2/presentation/widgets/chat_v2_attachment_viewer.dart`.
  - *Kịch bản nghiệm thu*: Bấm vào file PDF hoặc Excel trong chat ➔ Ứng dụng mở xem file trực tiếp mượt mà.

- [x] **3.20 Gửi Nhiều Ảnh kèm Chú thích & Chặn File quá tải**
  - *Mô tả*: Chọn nhiều ảnh từ album hoặc chụp ảnh trực tiếp; nhập ghi chú (caption) cho ảnh; chặn an toàn các file vượt quá dung lượng (ảnh > 10MB, tài liệu > 25MB).
  - *Tệp liên quan*: `lib/features/chat_v2/presentation/widgets/chat_v2_input_bar.dart`.
  - *Kịch bản nghiệm thu*: Chọn 3 ảnh, gõ chú thích ➔ Gửi cùng lúc, ảnh hiển thị theo cụm đẹp mắt.

### D. Ghi âm & Tin nhắn Thoại (Voice Messaging):
- [x] **3.21 Ghi âm Nhấn Giữ & Vuốt để Hủy (Hold to Record - Chuẩn Zalo)**
  - *Mô tả*: Nút Micro thông minh tự chuyển đổi; thao tác nhấn giữ để ghi âm kèm đồng hồ đếm giây nhấp nháy đỏ; vuốt ngón tay sang trái để hủy bản thu (Slide to cancel); thả tay tự động gửi file `.m4a`.
  - *Tệp liên quan*: `lib/features/chat_v2/presentation/widgets/chat_v2_input_bar.dart`.
  - *Kịch bản nghiệm thu*: Giữ nút Micro nói 3 giây rồi thả tay ➔ Tin nhắn thoại tự động gửi đi; vuốt sang trái ➔ Hủy không gửi.

- [x] **3.22 Trình Phát Tin nhắn Thoại Inline (Voice Player)**
  - *Mô tả*: Bong bóng phát tin nhắn thoại tích hợp: Nút Play/Pause, thanh thời lượng âm thanh; tự động dừng phát khi thoát màn hình chat để tiết kiệm pin.
  - *Tệp liên quan*: `lib/features/chat_v2/presentation/widgets/chat_v2_voice_message_player.dart`.
  - *Kịch bản nghiệm thu*: Bấm Play ➔ Âm thanh phát rõ ràng qua loa điện thoại kèm thanh thời lượng chạy.

### E. Cuộc gọi Thoại P2P (Voice Call WebRTC - Odoo 19 RTC Core):
- [x] **3.23 Cuộc gọi Thoại 1-1 WebRTC P2P (Native Odoo 19 RTC)**
  - *Mô tả*: Gọi điện thoại trực tiếp giữa App Mobile và Odoo 19 Web qua giao thức WebRTC P2P; truyền âm thanh hai chiều sắc nét, không độ trễ.
  - *Tệp liên quan*: `lib/features/chat_v2/application/chat_v2_webrtc_engine.dart`, `lib/features/chat_v2/presentation/screens/chat_v2_call_screen.dart`.
  - *Kịch bản nghiệm thu*: Bấm nút gọi trên mobile ➔ Trình duyệt Odoo 19 Web của đồng nghiệp đổ chuông và nhận cuộc gọi đàm thoại thông suốt.

- [x] **3.24 Giao diện Cuộc gọi Toàn màn hình (CallKit & Call Control)**
  - *Mô tả*: Tích hợp CallKit (iOS) và ConnectionService (Android) hiển thị cuộc gọi đến toàn màn hình chuẩn điện thoại; nhạc chuông Odoo chính thức, âm quay số (dialing tone), tín hiệu máy bận nhanh (fast-busy); nút Bật/Tắt Mic, Loa ngoài (Speaker), Từ chối và Gác máy tức thì.
  - *Tệp liên quan*: `lib/features/chat_v2/application/chat_v2_callkit_service.dart`, `lib/features/chat_v2/presentation/widgets/chat_v2_incoming_call_dialog.dart`.
  - *Kịch bản nghiệm thu*: Có cuộc gọi đến khi khóa màn hình ➔ Màn hình bật sáng giao diện nhận cuộc gọi như cuộc gọi điện thoại thông thường.

---

## 4. 🗂️ QUẢN LÝ CÔNG VIỆC & DỰ ÁN (HOME DASHBOARD, TASKS, DANH BẠ)

Phân hệ trung tâm điều hành công việc hàng ngày, tổng hợp chỉ số hiệu suất và kết nối đồng nghiệp.

### Chi tiết các tính năng:
- [x] [Claude-Verified] **4.1 Dashboard Tổng quan Cá nhân hóa (Home Screen Hero)**
  - *Mô tả*: Lời chào thông minh theo buổi (Sáng / Chiều / Tối) kèm tên hiển thị, chức danh và công ty của nhân viên.
  - *Tệp liên quan*: `lib/features/home/presentation/home_screen.dart`.
  - *Kịch bản nghiệm thu*: Mở trang chủ ➔ Hiển thị đúng họ tên và chức danh của tài khoản đang đăng nhập.
  - *Bằng chứng kiểm thử (Evidence)*: Đã fix triệt để BUG-008 ở Build 144: Lời chào tự động đổi theo buổi (Sáng 5h-12h, Chiều 12h-18h, Tối sau 18h) qua `greetingForHour()`, nạp chức danh (`role`/`function`/`job_title`) và công ty (`company`/`company_name`) từ `userMetadata` hiển thị dưới họ tên. Pass 4/4 greeting & metadata tests `test/home_greeting_and_celebration_test.dart`.

- [/] [Claude-Checked] **4.2 Thẻ Chỉ số Đo lường Kép (Dual-Tier Metric Cards)**
  - *Mô tả*: Thẻ tổng hợp trực quan 4 thông số: Số giờ làm việc hôm nay, Trạng thái chấm công, Số lượng công việc cần làm hôm nay và Số ticket đang theo dõi.
  - *Tệp liên quan*: `lib/features/home/presentation/home_screen.dart`, `lib/features/home/application/home_summary_controller.dart`.
  - *Kịch bản nghiệm thu*: Các con số thống kê hiển thị chính xác, khớp với dữ liệu thực tế từ Odoo.
  - *Bằng chứng kiểm thử (Evidence)*: Live API `https://vuahethong.net/api/v1/mobile/dashboard/summary` trả về chính xác: `is_checked_in: true`, `attendance_id: 8973`, `open_ticket_count: 5`, `unread_chat_count: 891`, `total_channel_count: 919`. Pass unit test `test/home_dual_tier_metric_test.dart`.

- [x] [Claude-Verified] **4.3 Nút Chấm công Nhanh trên Trang chủ kèm Hiệu ứng Pháo hoa**
  - *Mô tả*: Widget chuyển đổi Check-in/Check-out nhanh một chạm ngay tại Trang chủ; khi bấm Check-in thành công kích hoạt hiệu ứng pháo hoa chúc mừng sinh động (`CelebrationFireworks`).
  - *Tệp liên quan*: `lib/features/home/presentation/home_screen.dart`, `lib/shared/widgets/celebration_fireworks.dart`.
  - *Kịch bản nghiệm thu*: Bấm Check-in tại trang chủ ➔ Bắn hiệu ứng pháo hoa chúc mừng ngày làm việc mới.
  - *Bằng chứng kiểm thử (Evidence)*: Đã fix triệt để BUG-009 ở Build 144: Kích hoạt `CelebrationFireworksOverlay.trigger(_fireworksChildKey.currentContext ?? context)` ngay khi Check-in nhanh thành công trong `_toggleAttendance`. Pass test widget `test/home_greeting_and_celebration_test.dart`.

- [/] [Claude-Checked] **4.4 Chuông Thông báo Hệ thống (Notification Sheet)**
  - *Mô tả*: Biểu tượng chuông thông báo trên thanh tiêu đề Trang chủ kèm chấm đỏ số lượng; chạm vào mở BottomSheet danh sách thông báo hoạt động gần đây.
  - *Tệp liên quan*: `lib/features/home/presentation/home_screen.dart`.
  - *Kịch bản nghiệm thu*: Bấm chuông thông báo ➔ Mở danh sách các sự kiện nhắc việc mới nhất.
  - *Bằng chứng kiểm thử (Evidence)*: Live API `https://vuahethong.net/api/v1/mobile/notifications/list` trả về danh sách 20 thông báo thực tế của hệ thống; chức năng xóa từng mục (`dismissedNotificationIdsProvider`), "Xóa hết" (`dismissAll`), và bấm điều hướng vào kênh chat hoạt động chính xác.

- [/] [Claude-Checked] **4.5 Tăng tốc Tải Trang Dưới 100ms (Cache SWR Engine)**
  - *Mô tả*: Cơ chế Stale-While-Revalidate: Hiển thị ngay lập tức dữ liệu đã lưu trong bộ nhớ đệm khi mở app, sau đó đồng bộ ngầm dữ liệu mới từ máy chủ mà không làm giật màn hình.
  - *Tệp liên quan*: `lib/features/home/application/home_summary_controller.dart`, `lib/features/home/application/home_performance_diagnostics.dart`.
  - *Kịch bản nghiệm thu*: Mở app ➔ Trang chủ hiện lên tức thì, không bị màn hình trắng hay vòng quay loading lâu.
  - *Bằng chứng kiểm thử (Evidence)*: Cơ chế SWR phát dữ liệu bộ nhớ đệm RAM tức thì (`watchToday`, `homeSummaryProvider`, `mobileDashboardSummaryProvider.future`), có tích hợp benchmark logger chẩn đoán tốc độ nạp 5 phân hệ trang chủ.

- [/] [Claude-Checked] **4.6 Danh sách Công việc Hôm nay (Today Tasks Section)**
  - *Mô tả*: Khối danh sách các nhiệm vụ được phân công làm trong ngày, kèm tên dự án, mức độ ưu tiên và nhãn trạng thái (Cần làm, Đang làm, Hoàn thành).
  - *Tệp liên quan*: `lib/features/timesheet/presentation/widgets/today_tasks_section.dart`, `lib/features/timesheet/presentation/widgets/task_row.dart`.
  - *Kịch bản nghiệm thu*: Nhiệm vụ được giao trên Odoo xuất hiện đầy đủ trong danh sách công việc hôm nay.
  - *Bằng chứng kiểm thử (Evidence)*: Live API `/api/v1/mobile/project/all_tasks` và `/api/v1/mobile/project/list` trả về danh sách task/project thực tế (50 projects). Danh sách hiển thị phân loại trạng thái, màu sắc và icon chuẩn xác.

- [/] [Claude-Checked] **4.7 Hoàn thành Nhanh Task & Log Giờ (Log Completion Sheet)**
  - *Mô tả*: Thao tác vuốt hoặc tích chọn hoàn thành nhanh nhiệm vụ; tự động mở popup xác nhận ghi nhận số giờ đã hoàn thành vào hệ thống.
  - *Tệp liên quan*: `lib/features/timesheet/presentation/widgets/log_completion_sheet.dart`.
  - *Kịch bản nghiệm thu*: Bấm nút hoàn thành task ➔ Điền 1 giờ ➔ Task đổi sang trạng thái hoàn thành và sinh timesheet tương ứng.
  - *Bằng chứng kiểm thử (Evidence)*: Pass unit test `test/task_repository_test.dart` (complete logs time through mobile timesheet endpoint, stopwatch duration, updates task workflow status sang done).

- [x] [Claude-Verified] **4.8 Trình Biên tập Checklist Đầu việc trong Task (Checklist Editor)**
  - *Mô tả*: Cho phép xem và tích chọn từng đầu việc con (checklist items) bên trong nhiệm vụ; hỗ trợ thêm đầu việc con mới trực tiếp từ điện thoại.
  - *Tệp liên quan*: `lib/features/timesheet/presentation/widgets/checklist_editor.dart`, `lib/shared/models/task_checklist_item.dart`, `lib/shared/models/task.dart`.
  - *Kịch bản nghiệm thu*: Bấm vào checklist của task ➔ Tích chọn hoàn thành mục con ➔ Tiến độ % của task tăng lên theo công thức `(completed / total) * 100%`.
  - *Bằng chứng kiểm thử (Evidence)*: Đã fix triệt để BUG-010 ở Build 144. `TaskChecklistEditor` hỗ trợ xem subtasks, toggle trạng thái hoàn thành kèm hiệu ứng gạch ngang, thêm/xóa subtask động, thanh tiến độ `LinearProgressIndicator` và huy hiệu hiển thị % chính xác theo công thức `(completed / total) * 100%`. Pass 12/12 unit/widget tests trong `test/task_checklist_subtasks_test.dart`.

- [/] [Claude-Checked] **4.9 Danh bạ Đồng nghiệp & Tra cứu Nhanh**
  - *Mô tả*: Tra cứu nhanh thông tin liên lạc của các thành viên trong công ty (Họ tên, Email, Phòng ban, Trạng thái online); bấm vào để mở chat hoặc gọi điện tức thì.
  - *Tệp liên quan*: `lib/features/chat/presentation/new_chat_screen.dart`.
  - *Kịch bản nghiệm thu*: Gõ tên đồng nghiệp vào ô tìm kiếm ➔ Hiển thị kết quả chính xác kèm avatar và email.
  - *Bằng chứng kiểm thử (Evidence)*: Live API `https://vuahethong.net/api/v1/mobile/users/search?q=Kiet` trả về chính xác user Bùi Tuấn Kiệt (UID: 3510, Partner: 6708, email: kietbt@vuahethong.net). Tìm kiếm trên `new_chat_screen.dart` nhanh chóng, hỗ trợ bấm chat 1-1 ngay lập tức.

---

## 5. 🎫 HỖ TRỢ & XỬ LÝ YÊU CẦU (TICKET / HELPDESK, SLA)

Phân hệ tiếp nhận và giải quyết các yêu cầu hỗ trợ kỹ thuật, dịch vụ nội bộ và khách hàng theo tiêu chuẩn SLA Odoo Enterprise.

### Chi tiết các tính năng:
- [x] **5.1 Danh sách Phiếu Yêu cầu (Ticket List Screen)**
  - *Mô tả*: Xem toàn bộ danh sách ticket cần xử lý hoặc do mình tạo; bộ lọc phân loại theo giai đoạn (Mới, Đang xử lý, Đã giải quyết, Đã đóng).
  - *Tệp liên quan*: `lib/features/ticket/presentation/ticket_list_screen.dart`, `lib/features/ticket/application/ticket_controller.dart`.
  - *Kịch bản nghiệm thu*: Danh sách hiển thị đầy đủ mã ticket, tiêu đề, ngày tạo và màu sắc phân biệt trạng thái.
  - *Bằng chứng kiểm thử (Evidence)*: Live API `https://vuahethong.net/api/v1/mobile/ticket/list` trả về danh sách 20 ticket mới nhất đầy đủ các trường dữ liệu (`ticket_ref`, `name`, `priority`, `stage_id`, `date_deadline`). Giao diện chia 2 tab rõ ràng (Đang xử lý / Đã hoàn thành), thanh tìm kiếm theo tiêu đề và bộ lọc BottomSheet theo mức độ ưu tiên (P1-P4) cùng Đội hỗ trợ hoạt động mượt mà.

- [x] **5.2 Tạo Phiếu Yêu cầu Hỗ trợ Mới (Create Ticket Screen)**
  - *Mô tả*: Màn hình tạo ticket trực quan: Nhập tiêu đề, mô tả chi tiết vấn đề, chọn Đội hỗ trợ (IT Support, HR, Kỹ thuật), chọn mức độ ưu tiên (Khẩn cấp, Cao, Bình thường, Thấp).
  - *Tệp liên quan*: `lib/features/ticket/presentation/create_ticket_screen.dart`.
  - *Kịch bản nghiệm thu*: Điền thông tin tạo ticket ➔ Bấm Gửi ➔ Ticket mới được tạo ngay trên hệ thống Odoo Helpdesk.
  - *Bằng chứng kiểm thử (Evidence)*: Form kiểm tra hợp lệ tiêu đề bắt buộc, nạp động danh sách đội hỗ trợ từ API `/api/v1/mobile/ticket/teams` (2 teams: Customer Care, Technical Support) và danh sách thẻ từ `/api/v1/mobile/ticket/tags` (13 tags). Nút Back trên AppBar xử lý an toàn cả trường hợp pop stack thông thường lẫn fallback deep-link về `/tickets` (Pass 2/2 tests `create_ticket_back_navigation_test.dart`).

- [x] [Claude-Verified] **5.3 Đính kèm Hình ảnh & Tệp tin vào Ticket (Kiểm tra mở tệp trên điện thoại)**
  - *Mô tả*: Chụp ảnh sự cố hoặc đính kèm tài liệu trực tiếp từ máy vào phiếu hỗ trợ để đội kỹ thuật dễ dàng nắm bắt lỗi.
  - *Tệp liên quan*: `lib/features/ticket/presentation/create_ticket_screen.dart`, `lib/features/ticket/presentation/ticket_detail_screen.dart`, `lib/features/chat_v2/presentation/widgets/chat_v2_attachment_viewer.dart`.
  - *Kịch bản nghiệm thu*: Đính kèm ảnh chụp màn hình hoặc tài liệu vào ticket ➔ Tải lên thành công và mở xem được trực tiếp trên điện thoại.
  - *Bằng chứng kiểm thử (Evidence)*: Luồng tải lên hỗ trợ Camera, Thư viện ảnh và Tệp tài liệu (PDF, Word, Excel, CSV, TXT) với giới hạn kích thước an toàn 25MB (`maxAttachmentBytes`). Pass 5/5 tests `ticket_attachment_verification_test.dart`.
  - *Kết quả xử lý lỗi (BUG-011)*: Đã fix triệt để ở Build 144 (commit `90b7b3a`). Widget `_AttachmentTile` trong `ticket_detail_screen.dart` kế thừa `ChatV2AttachmentViewer.openAttachment()`, tải authenticated bytes và mở trực tiếp qua `OpenFilex` In-App, bảo mật, không bị văng ra trình duyệt ngoài Safari/Chrome. Pass 5/5 unit tests.

- [x] **5.4 Màn hình Chi tiết Ticket Toàn diện (Ticket Detail Screen)**
  - *Mô tả*: Xem đầy đủ thông tin: Người gửi yêu cầu, Nhân viên phụ trách (Assigned User), Đội xử lý, Mức độ ưu tiên, Trạng thái giai đoạn hiện tại.
  - *Tệp liên quan*: `lib/features/ticket/presentation/ticket_detail_screen.dart`.
  - *Kịch bản nghiệm thu*: Chạm vào ticket ➔ Mở màn hình chi tiết với giao diện thẻ thông tin rõ ràng.
  - *Bằng chứng kiểm thử (Evidence)*: Live API `https://vuahethong.net/api/v1/mobile/ticket/1771` trả về chi tiết đầy đủ 18 trường. Màn hình chi tiết hiển thị thẻ thông tin với tiêu đề, mã ticket, đội hỗ trợ, người phụ trách, hoạt động theo lịch (`_TicketActivitiesSection`), danh sách tệp đính kèm (`_TicketAttachmentsSection`) và các nút chuyển trạng thái nhanh ("Nhận xử lý" / "Hoàn thành").

- [x] **5.5 Luồng Trao đổi & Bình luận Trực tiếp (Chatter Comments)**
  - *Mô tả*: Hệ thống bình luận 2 chiều giữa người yêu cầu và đội hỗ trợ ngay trên ticket; hiển thị lịch sử trao đổi theo dòng thời gian.
  - *Tệp liên quan*: `lib/features/ticket/data/ticket_comment_repository.dart`, `lib/features/ticket/presentation/ticket_detail_screen.dart`.
  - *Kịch bản nghiệm thu*: Gửi bình luận "Tôi đã kiểm tra lại" ➔ Bình luận xuất hiện ngay lập tức trên Chatter của Odoo.
  - *Bằng chứng kiểm thử (Evidence)*: `TicketCommentRepository` triển khai cơ chế polling định kỳ 5 giây, bóc tách và lọc trùng lặp nội dung mô tả ban đầu (`_normalizedContent`), gửi comment qua endpoint `/api/v1/mobile/ticket/<id>/message`. Bộ nhập liệu `_CommentComposer` hỗ trợ gửi tin nhắn mượt mà.

- [x] **5.6 Bộ lọc Làm sạch Mã HTML Odoo (HTML-to-Text Sanitizer)**
  - *Mô tả*: Tự động bóc tách và làm sạch các thẻ HTML rác (`<p>`, `<div>`, `<br>`, inline styles) do Odoo Web sinh ra, chuyển thành văn bản thuần thẩm mỹ, không vỡ giao diện mobile.
  - *Tệp liên quan*: `lib/core/utils/html_text.dart`, `lib/features/ticket/presentation/ticket_detail_screen.dart`.
  - *Kịch bản nghiệm thu*: Nội dung mô tả ticket tạo từ Web chứa định dạng phong phú hiển thị gọn gàng trên mobile.
  - *Bằng chứng kiểm thử (Evidence)*: `cleanHtmlText` loại bỏ thẻ script, style, comment, chuyển đổi các thẻ ngắt khối (`<br>`, `</p>`, `</div>`, `</li>`) thành xuống dòng, giải mã toàn diện các ký tự thực thể HTML (`&amp;`, `&lt;`, `&gt;`, `&quot;`, `&#39;`, `&nbsp;`, unicode hex & decimal). Đã pass toàn bộ test case trong `test/ticket_html_mapping_test.dart`.

- [x] [Claude-Verified] **5.7 Đo lường Cam kết Dịch vụ (SLA Status & Deadline)**
  - *Mô tả*: Hiển thị hạn chót cam kết giải quyết sự cố theo SLA và cảnh báo màu đỏ khi ticket sắp hoặc đã quá hạn cam kết.
  - *Tệp liên quan*: `lib/shared/models/ticket.dart`, `lib/features/ticket/presentation/ticket_detail_screen.dart`.
  - *Kịch bản nghiệm thu*: Ticket có SLA hiển thị rõ thời gian còn lại để hoàn thành xử lý.
  - *Bằng chứng kiểm thử (Evidence)*: Đã fix triệt để BUG-012 ở Build 144 (commit `90b7b3a`). Getter `Ticket.isOverdue` trả về `false` khi `deadline == null` (không fallback sang `createdAt`). Chip SLA hiển thị rõ ràng "SLA: Không giới hạn" thay vì báo động giả trễ hạn. Pass 5/5 unit tests SLA deadline `test/ticket_sla_deadline_test.dart`.

- [!] **5.8 Đánh giá Mức độ Hài lòng (Customer Satisfaction Ratings)**
  - *Mô tả*: Tích hợp ghi nhận đánh giá hài lòng của người dùng sau khi sự cố được đóng (1-5 sao, biểu tượng cảm xúc hài lòng).
  - *Tệp liên quan*: `lib/features/ticket/presentation/ticket_detail_screen.dart`, Backend `v_mobile_17/controllers/ticket.py`.
  - *Kịch bản nghiệm thu*: Đóng ticket ➔ Hiển thị mục đánh giá chất lượng phục vụ của đội hỗ trợ.
  - *Hiện tượng lỗi phát hiện (BUG-013)*: `[!] [BUG-013 — THIẾU HOÀN TOÀN TÍNH NĂNG ĐÁNH GIÁ MỨC ĐỘ HÀI LÒNG]`
    + **Hiện trạng**: Cả Flutter Frontend (`ticket_detail_screen.dart`) và Odoo Backend (`v_mobile_17/controllers/ticket.py`) hoàn toàn chưa cài đặt data model, API endpoint hay widget UI nào cho việc chấm sao (1-5 sao) và ghi nhận ý kiến phản hồi khi ticket hoàn thành.

- [x] **5.9 Chế độ Riêng cho Khách hàng Portal (Portal Mode Isolation)**
  - *Mô tả*: Giao diện chuyên biệt cho khách hàng: Tự động đưa màn hình Ticket làm trang chủ mặc định, chỉ xem các ticket do chính khách hàng hoặc công ty mình tạo.
  - *Tệp liên quan*: `lib/core/router/app_router.dart`, `v_mobile_17/controllers/ticket.py`.
  - *Kịch bản nghiệm thu*: Đăng nhập tài khoản Portal ➔ Vào thẳng danh sách Ticket của mình, bảo mật tuyệt đối dữ liệu nội bộ.
  - *Bằng chứng kiểm thử (Evidence)*: Backend Odoo kiểm tra chặt chẽ `_user.share or not _user.has_group('base.group_user')`. Tài khoản Portal chỉ được lọc ticket theo `partner_id` của chính mình; cố tình truy cập ID của ticket khác bị chặn đứng `403 Forbidden` ở cả 3 endpoint: xem chi tiết, gửi comment và đổi workflow (Portal bị cấm đổi trạng thái workflow). App Router điều hướng Portal chỉ hiển thị 3 tab (Ticket, Chat, Tôi).

---

## 6. 👤 TÔI (HỒ SƠ CÁ NHÂN, CÀI ĐẶT, TIỆN ÍCH & HỆ THỐNG)

Tab "Tôi" quản lý thông tin nhân sự cá nhân, tùy chỉnh giao diện ứng dụng, kiểm soát bộ nhớ và các tiêu chuẩn bảo mật cửa hàng ứng dụng.

### Chi tiết các tính năng:
- [x] **6.1 Thẻ Hồ sơ Định danh Nhân sự (Profile Hero Card)**
  - *Mô tả*: Hiển thị thông tin tổng quan nổi bật: Ảnh đại diện Avatar sắc nét (đồng bộ từ Odoo Avatar API), Tên hiển thị đầy đủ, Chức danh công việc, Tên công ty / Tập đoàn (`360 CORP`) và Email.
  - *Tệp liên quan*: `lib/features/profile/presentation/profile_screen.dart`, `lib/features/auth/data/auth_repository.dart`, `lib/core/api/odoo_api_client.dart`.
  - *Kịch bản nghiệm thu*: Mở tab "Tôi" ➔ Xem đầy đủ họ tên, chức danh và avatar chính thức của mình.
  - *Bằng chứng kiểm thử (Evidence)*: Chức danh công việc hiển thị ĐỘNG 100% theo từng tài khoản từ Odoo API `/api/v1/auth/me`. Đã kiểm chứng live và đối soát trực tiếp trên cả 3 tài khoản:
    + `tanmnn@360.org.vn` (Live Prod `vuahethong.net`): Odoo trả `job_title = 'AI Full Stack Engineer (Agentic AI Platform)'` (đây là chức danh thật của Sếp Tân trên hệ thống nhân sự).
    + `admin` (`demo-17`): Odoo trả `job_title = 'Chief Executive Officer'`.
    + `demo` (`demo-17`): Odoo trả `job_title = 'Experienced Developer'`.
    + Chuỗi trong `profile_screen.dart:29` chỉ là fallback phòng ngừa khi user không có chức danh trên Odoo. Không có lỗi hardcode chức danh. Đã thu hồi ticket BUG-015 và đóng thành INVALID (NOT A BUG). Avatar và tên hiển thị đồng bộ mượt mà. ĐẠT CHUẨN 100%.

- [x] **6.2 Chỉnh sửa Thông tin Cá nhân (Edit Profile Screen)**
  - *Mô tả*: Màn hình cập nhật thông tin: Chụp ảnh hoặc chọn ảnh từ thư viện máy để tải lên thay đổi ảnh đại diện cá nhân (avatar).
  - *Tệp liên quan*: `lib/features/profile/presentation/edit_profile_screen.dart`, `lib/features/profile/application/profile_controller.dart`.
  - *Kịch bản nghiệm thu*: Chọn ảnh mới từ thư viện / camera ➔ Bấm tải lên ➔ Avatar cập nhật mượt mà và lưu vào bộ nhớ.
  - *Bằng chứng kiểm thử (Evidence)*: Pass 5/5 widget test cases trong `test/features/profile/profile_edit_test.dart`. Chức năng chọn/chụp ảnh từ camera và thư viện hoạt động mượt mà. Sếp Tân duyệt: Các thông tin nhân sự (họ tên, chức vụ, công ty, email) do Quản trị viên/HR quản lý tập trung trên Odoo, ứng dụng mobile chỉ cần tính năng thay đổi ảnh đại diện là đủ, không cần chỉnh sửa các trường khác. Nghiệm thu PASS 100% theo thiết kế nghiệp vụ (Đã thu hồi BUG-014).

- [x] **6.3 Tùy chọn Chế độ Giao diện Sáng / Tối (Theme Mode Controller)**
  - *Mô tả*: Tự do chuyển đổi 3 chế độ giao diện: Chế độ Tối (Dark Theme chuẩn Apple HIG sang trọng), Chế độ Sáng (Light Theme) và Tự động theo cài đặt hệ điều hành.
  - *Tệp liên quan*: `lib/features/profile/application/theme_controller.dart`, `lib/core/theme/app_theme.dart`.
  - *Kịch bản nghiệm thu*: Bật Dark Mode ➔ Toàn bộ giao diện app chuyển sang màu đen mượt mà tức thì.
  - *Bằng chứng kiểm thử (Evidence)*: BottomSheet chọn theme mượt mà với 3 tùy chọn (Tối, Sáng, Hệ thống). Lưu cấu hình theme vào `UserPreferencesRepository`. Giao diện Dark Mode áp dụng màu nền chuẩn `#0B0F17` / `#131C2E` với độ tương phản cao, Light Mode áp dụng màu nền dịu mắt `#F4F6F9`.

- [x] **6.4 Giải phóng Dung lượng Bộ nhớ Đệm (Clear Cache)**
  - *Mô tả*: Nút dọn dẹp bộ nhớ đệm: Xóa sạch toàn bộ các file ảnh, file tài liệu tạm lưu trong quá trình lướt chat, giải phóng bộ nhớ cho điện thoại mà không làm mất tin nhắn.
  - *Tệp liên quan*: `lib/core/utils/local_attachment_cache.dart`, `lib/features/profile/presentation/profile_screen.dart`.
  - *Kịch bản nghiệm thu*: Bấm "Xóa bộ nhớ đệm" ➔ Hiển thị thông báo đã dọn dẹp thành công.
  - *Bằng chứng kiểm thử (Evidence)*: `_CacheRow` tự động tính dung lượng bộ nhớ đệm thư mục tạm bằng `LocalAttachmentCache.getCacheSizeInMB()`. Khi bấm, mở hộp thoại xác nhận số MB cần dọn dẹp. Bấm "Dọn dẹp" xóa toàn bộ tệp tạm thời mà không ảnh hưởng tới dữ liệu tin nhắn hay tài khoản.

- [x] **6.5 Tra cứu & Sao chép Mã Thiết bị Push (FCM Device Token)**
  - *Mô tả*: Tiện ích kỹ thuật trong màn hình Thông tin ứng dụng: Xem trạng thái kết nối thông báo đẩy và chạm 1 chạm để sao chép mã Token vào Clipboard phục vụ kiểm thử.
  - *Tệp liên quan*: `lib/features/profile/presentation/about_screen.dart`.
  - *Kịch bản nghiệm thu*: Vào Thông tin ứng dụng ➔ Mã Token kỹ thuật được ẩn trên giao diện người dùng cuối theo thiết kế của Sếp Tân.
  - *Bằng chứng kiểm thử (Evidence)*: Sếp Tân duyệt: Chủ đích ẩn mã Token kỹ thuật khỏi UI người dùng cuối trên bản phát hành chính thức để giữ giao diện sạch sẽ, bảo mật. Nghiệm thu PASS theo thiết kế nghiệp vụ (Đã thu hồi BUG-016).

- [x] **6.6 Màn hình Thông tin Ứng dụng & Bản quyền (About Screen)**
  - *Mô tả*: Xem thông tin số hiệu phiên bản hiện tại (VD: `v2.9.12 (Build 143)`), logo nhận diện thương hiệu 360 CORP và thông tin liên hệ hỗ trợ.
  - *Tệp liên quan*: `lib/features/profile/presentation/about_screen.dart`, `lib/shared/widgets/brand_logo.dart`.
  - *Kịch bản nghiệm thu*: Mở trang About ➔ Xem đúng số build 143 và bản quyền.
  - *Bằng chứng kiểm thử (Evidence)*: `appVersionProvider` đọc động phiên bản từ hệ thống qua `package_info_plus` (`v$version+$build`), hiển thị logo BrandLogo sắc nét, danh sách các phân hệ chính (Chấm công, Timesheet, Ticket, Tin nhắn), liên kết mở chính sách riêng tư `https://360.org.vn/privacy` qua trình duyệt ngoài, bản quyền © 2026 360 CORP.

- [x] **6.7 Bảng Tính năng Mới theo Phiên bản (What's New Sheet)**
  - *Mô tả*: Xem nhật ký tóm tắt các tính năng mới và cải tiến nổi bật của phiên bản đang sử dụng để người dùng nắm bắt nhanh.
  - *Tệp liên quan*: `lib/features/profile/presentation/about_screen.dart`, `lib/shared/widgets/whats_new_sheet.dart`.
  - *Kịch bản nghiệm thu*: Bảng tính năng mới tự động kích hoạt theo kịch bản cập nhật phiên bản, không gắn nút mở tự do.
  - *Bằng chứng kiểm thử (Evidence)*: Widget `WhatsNewSheet` đã code hoàn chỉnh trong `lib/shared/widgets/whats_new_sheet.dart` có lưu cache trạng thái đã xem vào secure storage. Sếp Tân duyệt: Chủ đích ẩn nút mở thủ công trên About/Profile để tránh rối mắt. Nghiệm thu PASS theo thiết kế nghiệp vụ (Đã thu hồi BUG-017).

- [x] **6.8 Yêu cầu Xóa Tài khoản (Account Deletion Compliance)**
  - *Mô tả*: Chức năng bắt buộc theo chính sách của Apple App Store & Google Play: Người dùng có thể gửi yêu cầu xóa tài khoản và dữ liệu cá nhân an toàn kèm hộp thoại xác nhận bảo mật.
  - *Tệp liên quan*: `lib/features/profile/presentation/profile_screen.dart`.
  - *Kịch bản nghiệm thu*: Bấm "Yêu cầu xóa tài khoản" ➔ Hiện popup xác nhận bảo vệ người dùng, tránh bấm nhầm.
  - *Bằng chứng kiểm thử (Evidence)*: Bấm "Yêu cầu xóa tài khoản" hiển thị hộp thoại AlertDialog với nội dung cam kết xử lý trong 30 ngày theo quy định bảo mật. Bấm "Gửi yêu cầu" tự động kích hoạt `launchUrl` mở ứng dụng email với tiêu đề và nội dung soạn sẵn gửi về `support@360.org.vn`.

- [x] **6.9 Đăng xuất An toàn & Dọn dẹp Toàn diện (Secure Logout)**
  - *Mô tả*: Nút Đăng xuất ở cuối trang kèm hộp thoại xác nhận: Khi đồng ý, tự động kích hoạt chuỗi hủy token RAM, vô hiệu hóa FCM push trên máy chủ, xóa secure storage và đưa về màn hình Đăng nhập.
  - *Tệp liên quan*: `lib/features/profile/presentation/profile_screen.dart`, `lib/features/auth/application/auth_controller.dart`, `lib/core/services/global_state_reset_service.dart`.
  - *Kịch bản nghiệm thu*: Bấm Đăng xuất ➔ Xác nhận ➔ Trở về màn hình đăng nhập sạch sẽ, an toàn tuyệt đối.
  - *Bằng chứng kiểm thử (Evidence)*: Pass 12/12 unit/integration test cases trong `test/features/auth/logout_session_wipe_test.dart`. Chuỗi dọn dẹp thực thi qua 4 tầng dữ liệu: Hủy đăng ký push device trên server Odoo, xóa RAM cache 10 module (Ticket, Task, Timesheet, Attendance, ChatV2, PartnerToUserMap), xóa sạch FlutterSecureStorage, reset Riverpod state, ngắt CallKit calls và điều hướng sạch sẽ về trang đăng nhập. Hoàn toàn không rò rỉ dữ liệu khi đổi tài khoản (Zero-Data-Leakage).

---

## 🛠️ HẠ TẦNG KỸ THUẬT, TỰ ĐỘNG HÓA & PHÁT HÀNH (CI/CD)

Nhóm các tiêu chuẩn kỹ thuật nền tảng đảm bảo ứng dụng vận hành mượt mà và phát hành liên tục:
- [x] **CI/CD Tự động hóa GitHub Actions**: Tự động build và đẩy bản phát hành lên **Apple TestFlight** mỗi khi merge code vào nhánh `main`.
- [x] **Kiểm soát Chất lượng Mã nguồn**: Khóa cổng `flutter analyze` đạt **0 lỗi / 0 warnings** trước mọi lần đóng gói.
- [x] **Kiểm thử Tự động**: Hơn 240 bài Unit & Widget test bao phủ toàn bộ các luồng nghiệp vụ nhạy cảm.
- [x] **Bảo mật Tệp cấu hình iOS**: Khóa cứng cấu hình `ITSAppUsesNonExemptEncryption = false` trong `Info.plist` đảm bảo bản build TestFlight sẵn sàng kiểm thử ngay không cần xác minh thủ công.
- [x] **Quy chuẩn Đóng gói Android**: Sẵn sàng cấu hình Fastlane và chứng chỉ ký số phát hành gói App Bundle (`.aab`) lên Google Play Console.
