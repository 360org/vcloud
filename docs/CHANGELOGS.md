# 📜 LỊCH SỬ THAY ĐỔI & PHÁT TRIỂN (CHANGELOGS.md)

Tất cả các thay đổi đáng chú ý của hệ sinh thái **VCloud Mobile App & Odoo Backend** sẽ được ghi chép tại tài liệu này theo tiêu chuẩn **AIaC 3.0**.

---

## [v2.5.0+79] — 2026-08-20

> [!IMPORTANT]
> **Nhánh làm việc chung cho phiên bản v2.5.0+79 (Dành cho các AI Agent khác / Claude Code / Codex tiếp quản)**:
> - **Frontend (`vclients`)**: Nhánh `fix/app-chat-stabilization`
>   ```bash
>   cd /media/tanma/DATA/save/mobile/vclients
>   git fetch origin && git checkout fix/app-chat-stabilization && git pull origin fix/app-chat-stabilization
>   ```
> - **Backend (`v_mobile`)**: Nhánh `fix/app-chat-stabilization`
>   ```bash
>   cd /media/tanma/DATA/save/mobile/v_mobile
>   git fetch origin && git checkout fix/app-chat-stabilization && git pull origin fix/app-chat-stabilization
>   ```

### 🎨 [IMPROVE] Tối Ưu UI/UX Bộ Lọc Chat Chuẩn Mobile & Đếm Đúng Tổng Số Chats
- **Tái Thiết Kế Bộ Lọc Chat Chuẩn Mobile (Mobile-First Filter)**:
  - **Xóa bỏ thanh filter ngang**: Loại bỏ hoàn toàn thanh ChoiceChips ngang dàn trải gây chiếm diện tích và phong cách web trên màn hình Trò chuyện.
  - **Nút Filter Icon & Modal BottomSheet**: Tích hợp 1 nút Icon Bộ Lọc (`LucideIcons.slidersHorizontal`) bo góc 14px nằm cùng hàng với ô Tìm kiếm. Khi chạm mở BottomSheet bo góc 24px gồm 5 tùy chọn (*Tất cả, Chưa đọc, Nội bộ, Nhóm, Kênh*) kèm badge số lượng thời gian thực và dấu checkmark nhận diện.
  - **Active Filter Mini Indicator**: Hiển thị chip chỉ báo mini thanh thoát (28px) kèm nút `[x]` xóa lọc nhanh 1 chạm khi đang bật 1 bộ lọc khác mặc định.
- **Nâng Cấp Widget Home — Đếm Đúng 100% Tổng Số Cuộc Trò Chuyện**:
  - **Frontend**: Sửa logic `fallbackChatCount` và `HomeSummary` trong `home_screen.dart` và `home_summary_controller.dart`, ưu tiên lấy con số tổng từ Server Dashboard (`dashboard.recentConversationCount` / `total_channel_count`) thay vì bị kẹp cố định ở độ dài mảng RAM local (`loadedChatChannels.length`).
  - **Backend**: Nâng cấp `controllers/chat.py` bỏ giới hạn cứng `limit = 300/500`, cho phép tải linh hoạt toàn bộ kênh khi không truyền `limit` hoặc truyền `limit=0/all`. Đồng bộ domain đếm `_get_total_channel_count` trong `controllers/dashboard.py` khớp 100% với danh sách kênh.

- **Fix Đồng Bộ Giờ & Lần Log Gần Nhất Cho Task Detail (Timesheet Modal)**:
  - **Backend**: Cập nhật `all_project_tasks` và `task_detail` trong `v_mobile/controllers/project.py`, loại bỏ điều kiện kẹp cứng `max(allocated - effective, 0.0)` giúp hiển thị chính xác số giờ âm khi vượt thời gian cho phép (như `-3 giờ`); đồng thời truy vấn bản ghi mới nhất từ `account.analytic.line` để trả về `last_log_hours`, `last_log_date`, `last_log_note`.
  - **Frontend**: Nâng cấp `Task` model, `task_repository.dart`, và `timesheet_list_screen.dart` để hiển thị chính xác các chỉ số *"Lần log gần nhất"*, *"Tổng thời gian cho phép"*, *"Tổng thời gian đã làm"*, và *"Còn lại"*.
- **Lấy Cấu Hình Ca Làm Việc Động Từ Backend API (Dynamic Shift Configuration & Work Schedule)**:
  - **Backend (`v_mobile/controllers/attendance.py`)**:
    - Xóa bỏ việc phụ thuộc vào cấu hình tĩnh; bổ sung hàm `_get_shift_config(employee, target_date)` tự động đọc lịch làm việc thực tế của nhân viên từ `employee.resource_calendar_id` (hoặc `company_id.resource_calendar_id`).
    - Bóc tách chính xác các mốc thời gian: Giờ bắt đầu/kết thúc ca sáng (`morning_target_minutes`, `morningTimeRange`), Giờ nghỉ trưa (`lunchTimeRange`), Giờ ca chiều (`afternoon_target_minutes`, `afternoonTimeRange`), Tổng mục tiêu ngày (`target_work_minutes`, `targetHoursFormatted`).
    - Trả về đối tượng `shift_config` trong endpoint `/api/v1/mobile/attendance/today` và cung cấp endpoint độc lập `/api/v1/mobile/attendance/config`.
  - **Frontend (`vclients`)**:
    - Nâng cấp model `ShiftConfig` (`shift_calculator.dart`): Bổ sung constructor `ShiftConfig.fromMap(Map<String, dynamic> map)`, `toMap()`, `copyWith(...)` để parse dữ liệu thời gian thực từ API backend, giữ fallback an toàn `ShiftConfig.forDate(...)`.
    - Thêm `shiftConfigProvider` và `currentShiftConfigProvider` trong `attendance_controller.dart` và cập nhật `AttendanceRepository` cache cấu hình ca làm việc.
    - Cập nhật Widget **`_DetailedShiftBreakdownCard`** (màn hình Chấm công) và **`_GreetingHeader`** (màn hình Trang chủ) đọc ca làm việc động từ Riverpod Provider, tự động hiển thị chính xác 100% khung giờ ca sáng, nghỉ trưa, ca chiều và thanh tiến độ theo dữ liệu Odoo.
    - Tính toán thời lượng nghỉ trưa linh hoạt (`lunchMinutes` và `lunchFormatted`) từ `config.lunchStart` và `config.lunchEnd` thay vì giá trị cố định.
  - **Unit Tests**:
    - Thêm `vclients/test/features/attendance/shift_config_api_test.dart` (4 test cases).
    - Thêm `v_mobile/tests/test_attendance_shift_config_contract.py` (3 test cases).
    - Đạt **195/195 tests Flutter PASS 100%**, `flutter analyze` 0 errors, 0 warnings.
- **Tối Ưu Độ Phủ Dữ Liệu Lịch Sử Chấm Công (Attendance History & Calendar Scope)**:
  - **Backend (`v_mobile/controllers/attendance.py`)**: Nâng trần tham số `limit` trong endpoint `/api/v1/mobile/attendance/history` từ `100` lên `500` bản ghi; đảm bảo trả về trọn vẹn toàn bộ lịch sử vào/ra ca của nhân viên cho các chu kỳ chấm công nhiều tháng/cả năm.
  - **Frontend (`vclients`)**: Nâng default query `limit` trong `AttendanceRepository.watchRecent()` lên `500` bản ghi, giúp màn hình **Lịch sử chấm công** (`attendance_history_screen.dart`) và Calendar View luôn sẵn sàng dữ liệu đầy đủ khi lật qua lại giữa các tháng trước/sau mà không bị giới hạn cục bộ.
- **Bộ Kiểm Thử Hiệu Năng Mobile & Tiêu Chuẩn Giới Hạn SLA (Performance Budgets)**:
  - **Quy chuẩn SLA Hiệu Năng Mobile**:
    * 🟢 **Tức thì (RAM/Local Cache Instant Read)**: `<= 50ms` (Không gây độ trễ mắt người).
    * 🟢 **API đơn lẻ (Chấm công, Ticket, Timesheet, Shift Config)**: `<= 1,000ms - 1,500ms` (Đạt chuẩn trải nghiệm di động).
    * 🟡 **API danh sách lớn (Chats 899 kênh, Tasks 100+ items)**: `<= 2,000ms` (Chấp nhận được).
    * 🔴 **Vi Phạm Ngưỡng Hiệu Năng (SLA Breach / Chậm)**: `> 3,000ms` (Bắt buộc phải áp dụng Local Cache tức thì và phân trang/lazy loading).
  - **Bộ Test Hiệu Năng Frontend (`vclients/test/performance/home_load_performance_benchmark_test.dart`)**:
    * Test nạp & parse 1,026 đối tượng JSON đồng thời (899 Channels + 107 Tasks + 20 Tickets) đạt `< 150ms`.
    * Test truy xuất Local Cache tức thì đạt `< 50ms`.
    * Test lọc & tìm kiếm trên 899 kênh đạt `< 30ms`.
    * Test 1,000 phép tính ShiftCalculator đạt `< 50ms`.
  - **Công Cụ Đo Latency Live Server Odoo (`tools/benchmark_home_apis.py`)**:
    * Tự động đo P50, Min, Max Latency của 5 API trang chủ thời gian thực và xuất báo cáo trực quan màu sắc.
  - **Hợp Đồng Kiểm Thử Backend SLA (`v_mobile/tests/test_performance_sla_benchmark.py`)**:
    * Xác nhận cấu trúc xử lý 1,000 kênh trên backend không suy thoái thuật toán O(n²).
- **Hỗ Trợ Kênh Thảo Luận Công Khai / Kênh Internal & Tìm Kiếm Trực Tiếp Từ Server**:
  - **Backend (`v_mobile/controllers/chat.py`)**:
    - Tự động bao gồm tất cả các kênh công khai nội bộ (`channel_type = 'channel'`) cho toàn bộ nhân viên nội bộ (`not user.share`), cho phép hiển thị các kênh công ty như `#Internal` ngay cả khi user chưa được add thủ công vào member trước đó.
    - Sắp xếp kênh ưu tiên theo hoạt động mới nhất: `order="write_date desc, id desc"`.
    - Hỗ trợ tham số `search` trong `/api/v1/mobile/chat/channels` với domain `('name', 'ilike', search_term)` để quét toàn bộ cơ sở dữ liệu.
    - Bỏ giới hạn cứng `limit = 300/500`, cho phép tải linh hoạt toàn bộ kênh khi không truyền `limit` hoặc truyền `limit=0/all`.
    - Tự động thêm quyền và join member (`add_members`) cho nhân viên nội bộ khi truy cập `channel_messages` hoặc gửi tin nhắn `send_message`.
  - **Frontend (`vclients`)**:
    - Nâng cấp `ChatV2ChannelsNotifier` gọi `repo.getChannels()` tải toàn bộ danh sách kênh về máy.
    - Tích hợp **Server-Side Debounced Search (350ms)**: Khi gõ từ khóa vào thanh tìm kiếm, ứng dụng vừa lọc tức thì trên RAM vừa gửi query tìm kiếm trực tiếp lên Odoo Server để nạp bổ sung kênh ngay lập tức.
    - Chuẩn hóa tìm kiếm: Tự động normalize loại bỏ ký tự tiền tố `#`, không phân biệt hoa thường, tìm kiếm đa chiều theo tên kênh, tên thành viên (`memberNames`), đối tác trực tiếp (`directPartnerName`) và nội dung tin nhắn.
- **Attachment Authorization Relaxing (Mobile API Backend)**:
  - **Cả 2 bên xem file (Chat 1-1 & Group Chat)**: Cập nhật hàm `_check_attachment_authorization` trong `v_mobile/controllers/attachments.py` để cả người gửi (`msg.author_id`) và người nhận (`msg.partner_ids`, `msg.notified_partner_ids`, `msg.notification_ids`) đều có toàn quyền tải và xem tệp đính kèm (`.pdf`, `.docx`, `.xlsx`...).
  - **Internal User Access**: Nới lỏng phân quyền cho toàn bộ nhân viên nội bộ (`user.has_group('base.group_user')` hoặc `not user.share`) để mở và tải các tài liệu nghiệp vụ được chia sẻ trong hệ thống.
  - Khắc phục triệt để lỗi `403 Forbidden: Access Denied` khi click mở file trên Web và Mobile.
- **Fix Lỗi Sai Khung Giờ Tin Nhắn Cuối (Chat List & Detail Sync)**:
  - **Backend**: Cập nhật câu SQL `last_msgs_by_channel` trong `v_mobile/controllers/chat.py` sử dụng regex strip HTML `REGEXP_REPLACE(m.body, '<[^>]*>', '', 'g')` và loại bỏ hoàn toàn điều kiện `OR m.message_type = 'comment'` độc lập; đảm bảo chỉ chọn các tin nhắn có nội dung văn bản thực tế hoặc có attachment làm `last_message`, loại trừ các bản ghi notification rỗng sinh ra sau đó làm lệch giờ hiển thị.
  - **Frontend**: Trong `_ChannelListItem`, ưu tiên lấy `effectiveLastDate` từ tin nhắn thực tế trong `ChatV2MessageLocalCache` để hiển thị thời gian chính xác 100% khớp với nội dung tin nhắn trong phòng chat.
- **Fix Lỗi Đã Xem Tin Nhắn Nhưng Quay Lại Vẫn Báo Chưa Đọc**:
  - **Backend**: Nâng cấp endpoint `mark_read` (`/api/v1/mobile/chat/channels/<id>/mark-read`), tự động tạo `discuss.channel.member` nếu người dùng chưa có bản ghi member và cập nhật `seen_message_id = last_msg.id`.
  - **Frontend**: Thêm hàm `ChatV2ChannelLocalCache.markChannelAsRead(channelId)` để lập tức reset `unreadCount = 0` trong local cache ngay khi vào xem; đồng thời điều chỉnh `isChannelUnread` trong `ChatV2ReadStateNotifier` với buffer 2 giây tránh jitter, đảm bảo khi quay lại danh sách hội thoại badge đỏ biến mất ngay lập tức.
- **Last Message Resolution & Attachment Support (Task #16450 - P1)**:
  - **Backend**: Nâng cấp câu lệnh SQL `last_msgs_by_channel` trong `v_mobile/controllers/chat.py`, hỗ trợ tra cứu tệp đính kèm từ cả 2 nguồn `ir_attachment` (`res_model='mail.message'`) và `message_attachment_rel`, đồng thời lọc bỏ các tin nhắn thông báo rỗng của hệ thống (`notification` không có body/attachment).
  - **Frontend**: Hiển thị chính xác nội dung tin nhắn cuối cùng (Text, `[Hình ảnh]`, `[Tập tin]`, `[Bình chọn]`) trên danh sách hội thoại, chấm dứt tình trạng hiển thị sai dòng mặc định *"Nhấn để bắt đầu trò chuyện"*.
- **Self Message Elimination from Unread Filter (Task #16451 - P1)**:
  - **Backend**: Tự động cập nhật `seen_message_id = msg.id` cho bản ghi `discuss.channel.member` của người gửi ngay sau khi gửi tin nhắn trong `send_message`. Trong `list_channels`, tự động gán `unread_count = 0` nếu `last_author_id == partner.id`.
  - **Frontend**: Khóa chặt điều kiện `isMine = isFirstMsgMine || isMineFromTracker || isLastMessageFromMe(...)` trong bộ lọc `_selectedFilterIndex == 0` (Chưa đọc) và `chatV2TotalUnreadProvider`. Hội thoại do người dùng gửi tin nhắn cuối (`Bạn: ...`) tuyệt đối không bao giờ bị xếp vào mục "Chưa đọc".
- **Avatar Leak Prevention (Task #16446 - P1)**:
  - Khắc phục triệt để lỗi hiển thị nhầm avatar người dùng hiện tại lên AppBar đối phương.
  - Lấy an toàn trường `name` từ JWT token Odoo, bổ sung điều kiện loại trừ `!m.isMine && m.authorId != currentPartnerId && m.authorId != currentUserId`.
  - Fallback chữ cái đầu tiên khi đối phương chưa cập nhật avatar.
- **Group Filter & Channel Categorization (Task #16447 - P1)**:
  - Sửa logic phân loại bộ lọc: loại bỏ điều kiện chặn cứng `channelType == 'channel'`, phân loại nhóm chính xác bằng `getActualIsGroup(currentUserName)` và `channelType == 'group'`.
  - Tab "Nhóm" hiển thị đầy đủ và chính xác tất cả các nhóm thảo luận.
- **Attachment Upload & Optimistic Status (Task #16448 - P2)**:
  - Khắc phục lỗi hiển thị dấu chấm than đỏ (thất bại giả) khi gửi hình ảnh trong phòng chat.
  - Khóa chặt mapping optimistic message `tempId` ➔ `sentMsg.id`, xóa sạch tin nhắn tạm trước khi chèn tin nhắn đã commit từ Odoo, ngăn ngừa race condition giữa upload và polling.
- **Expected Singleton & Fast-Path Navigation (Task #16449 - P3)**:
  - Backend: Bổ sung `.with_user(uid).sudo()` và hỗ trợ `channel_get(partners_to=[target_partner_id])` trong route `/api/v1/mobile/chat/direct` (`v_mobile/controllers/chat.py`), triệt tiêu vĩnh viễn lỗi `Expected singleton: res.users()`.
  - Frontend: Thêm **Optimistic Fast-Path Navigation (0ms latency)** trong `NewChatScreen`: khi bấm vào người đã có cuộc trò chuyện, chuyển màn hình tức thì bằng RAM Cache mà không có độ trễ chờ đợi mạng.

### 🗂️ [REFACTOR] Quy hoạch & Phân Loại Thư Mục Task
- Tách bạch cấu trúc thư mục quản lý Task thành 2 phân vùng rõ ràng:
  - `docs/tasks/pending/`: Lưu trữ các task chưa fix / đang chờ xử lý (P1 ➔ P4).
  - `docs/tasks/completed/`: Lưu trữ các task đã hoàn thành và kiểm thử thành công 100%.
- Cập nhật script tự động hóa `tools/fetch_tasks_vuahethong.py` tự động phân loại task vào đúng thư mục con theo trạng thái `stage_name`.

### 🟢 [NEW] Tính năng mới & Bộ công cụ tự động hóa
- **Task Fetcher Tool (`tools/fetch_tasks.sh` & `fetch_tasks_vuahethong.py`)**:
  - Tự động đăng nhập Odoo `vuahethong.net` qua JWT API.
  - Quét và tải toàn bộ task, phân tích HTML mô tả và bóc tách hình ảnh lỗi (`BUG`) vs hình ảnh kỳ vọng (`EXPECTED`).
  - Xuất ra các file tài liệu Markdown chi tiết trong `docs/tasks/` và đồng bộ tự động vào `docs/IDEA.md`.
- **Thư mục Công cụ Tập trung (`tools/`)**:
  - Quy hoạch toàn bộ scripts và tools vào `tools/` kèm `tools/README.md`.
- **Task Priority Roadmap (`docs/TASK_PRIORITY_ROADMAP.md`)**:
  - Thiết lập ma trận phân cấp ưu tiên 4 tầng (P1 Quick Wins ➔ P2 Frontend Fixes ➔ P3 Feature & Data ➔ P4 Fullstack Backend).

### ⚡ [IMPROVE] Cải tiến giao diện & Trải nghiệm người dùng (UI/UX)
- **Timesheet Label (Task #16443)**:
  - Đổi tiêu đề *"Thời gian dự kiến"* thành **"Tổng thời gian cho phép"** trên màn hình Timesheet.
- **Chat Add Button (Task #16438)**:
  - Nâng cấp icon sang `LucideIcons.messageSquarePlus`, mở rộng vùng chạm chuẩn 44x44pt (Apple HIG / Material 3).
- **Home Chat Count Sync (Task #16434)**:
  - Đồng bộ số lượng kênh trò chuyện tức thì giữa `chatV2ChannelsProvider` và Widget Chats trên Trang Chủ.

### 🛡️ [FIX] Sửa lỗi & Tăng cường an toàn
- **Ticket Attachment Authorization (Task #16447)**:
  - Khắc phục triệt để lỗi `access_denied` khi tải tệp đính kèm Ticket (`helpdesk.ticket`) từ app và browser.
  - Bổ sung xác thực quyền đọc target model và fallback ORM ACL trong `_check_attachment_authorization`.
  - Tự động gán `partner_id` khi tạo ticket từ user hiện tại.
  - Chuẩn hoá `_AttachmentTile` phía Flutter sử dụng `attachment.downloadUrl` và `attachment.accessToken`.
- **Layout Bong bóng Chat (Task #16440)**:
  - Thêm `TextOverflow.ellipsis` cho tên người gửi dài, chống tràn hàng.
  - Giới hạn chiều cao và padding cho khung trích dẫn tin nhắn (`_QuotedReplyBox`).
- **Attachment URL Authentication (Task #16442)**:
  - Đính kèm token JWT qua `odooApiClient.authenticatedUrl` khi mở hoặc tải tệp đính kèm, triệt tiêu hoàn toàn lỗi 403 Forbidden.
- **Timesheet Remaining Hours Calculation (Task #16445)**:
  - Tự động tính toán `remaining_hours = allocated_hours - spent_hours` khi backend trả về null/0.
  - Hỗ trợ hiển thị giờ âm trực quan khi vượt thời gian cho phép (`_formatHours`).

### 🧪 [TEST] Kiểm thử & Độ tin cậy
- Bổ sung `test/performance/home_load_performance_benchmark_test.dart` gồm 4 test cases kiểm thử hiệu năng parse 1,026 models, local cache read, search 899 channels và shift calculation.
- Bổ sung `v_mobile/tests/test_performance_sla_benchmark.py` gồm 2 test cases kiểm tra hợp đồng SLA backend và độ phức tạp tính toán 1,000 kênh.
- Bổ sung công cụ Live Server Benchmark `tools/benchmark_home_apis.py` đo P50/Min/Max latency của 5 API trang chủ.
- Bổ sung `test/features/attendance/shift_config_api_test.dart` gồm 4 test cases kiểm tra parse payload JSON động từ backend, tính toán tiến độ ca làm việc và offline mapping.
- Bổ sung `v_mobile/tests/test_attendance_shift_config_contract.py` gồm 3 test cases kiểm tra hợp đồng API backend về trích xuất `resource.calendar` và endpoint `/api/v1/mobile/attendance/config` & `/today`.
- Bổ sung `test/chat_v2_search_and_filter_test.dart` gồm 7 test cases kiểm tra phân loại kênh Internal, chuẩn hóa dấu `#`, tìm kiếm từ khóa và sắp xếp ngày tháng.
- Bổ sung `v_mobile/tests/test_chat_search_and_channels_contract.py` kiểm tra hợp đồng API backend về kênh nội bộ công khai, sắp xếp `write_date desc` và search query.
- Bổ sung `test/ticket_attachment_verification_test.dart` kiểm tra toàn diện hợp đồng token download attachment.
- Bổ sung `test/task_priority_features_test.dart` kiểm tra toàn diện hợp đồng dữ liệu và bộ lọc.
- Bổ sung `test/features/chat_v2/` kiểm tra tính năng bộ lọc mobile và realtime.
- Đạt **199/199 tests Mobile PASS 100%**, `flutter analyze` 0 errors, 0 warnings.
- Kiểm thử bảo mật & Contract Backend Python PASS 100% (9/9 tests PASS).

---

## [v2.5.0+78] — 2026-08-19

### 🚀 Phát Hành Bản Dựng TestFlight & Ổn Định Hệ Thống
- Hoàn thiện bản dựng phát hành chính thức `v2.5.0+78` cho iOS TestFlight & App Store.
- Đồng bộ toàn diện hệ thống mã nguồn giữa GitLab và GitHub.
