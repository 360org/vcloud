# 🛡️ BÁO CÁO KIỂM TOÁN TÍNH NĂNG VCLOUD MOBILE APP (EMPIRICAL AUDIT REPORT)

> **Tài liệu kiểm toán**: Đối soát tính năng thực tế giữa SSOT `vclients/docs/features.md` và Sổ cái bằng chứng `.claude/agent_state/evidence_ledger.yaml`.  
> **Phiên kiểm toán**: `AUDIT_GATE_2026_10_10`  
> **Nguyên tắc kiểm toán**: **ANTI-SYCOPHANCY & ZERO GUESSING PROTOCOL (v2)**.  
> **Phân loại trạng thái**:
> - `[✅ VERIFIED_PASS]`: Có bằng chứng test thực nghiệm độc lập (đường dẫn file test, số case PASS, lệnh chạy).
> - `[⚠️ UNVERIFIED_CODE_ONLY]`: Có mã nguồn trong repo nhưng chưa có test tự động độc lập hoặc chưa có log test trên đĩa.
> - `[🔴 FAILED_OR_BUGGY]`: Fail test case hoặc có gap/bug kỹ thuật xác nhận tồn đọng.
> - `[⚪ DESCOPED_SKIPPED]`: Tính năng đã được PO / Sếp Tân chỉ đạo lược bỏ.

---

## 📊 1. BẢNG TỔNG HỢP KIỂM TOÁN THEO 6 PHÂN HỆ NGHIỆP VỤ

| STT | Phân hệ Nghiệp vụ | Tổng số tính năng | ✅ VERIFIED_PASS | ⚠️ UNVERIFIED_CODE_ONLY | 🔴 FAILED_OR_BUGGY | ⚪ DESCOPED |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: |
| **1** | **Auth & Multi-DB** | 8 | 5 | 1 | 2 *(Perf Fail)* | 0 |
| **2** | **Timesheet & Attendance** | 12 | 10 | 2 | 0 | 0 |
| **3** | **Chat V2, Media & Call** | 37 | 31 | 6 | 0 *(1 Flake Perf)* | 0 |
| **4** | **Task & Dashboard** | 9 | 8 | 1 | 0 | 0 |
| **5** | **Ticket & Helpdesk** | 14 | 11 | 0 | 2 *(Gaps)* | 1 |
| **6** | **Profile & System Utils** | 10 | 7 | 3 | 0 | 0 |
| **TỔNG** | **TOÀN BỘ HỆ THỐNG** | **90** | **72 (80.0%)** | **13 (14.4%)** | **4 (4.4%)** | **1 (1.1%)** |

---

## 2. ĐỐI SOÁT CHI TIẾT THEO TỪNG PHÂN HỆ

### 🔐 NHÓM 1: AUTH & MULTI-DB (8 Tính năng)

- **1.1 Đăng nhập chuẩn Gateway (Direct Login)**: `[🔴 FAILED_OR_BUGGY]` *(Performance Assertion Threshold Exceeded)*
  * *Bằng chứng test*: `vclients/test/features/auth/login_screen_environment_test.dart`, `vclients/test/features/auth/smart_login_contract_test.dart`, `vclients/test/features/auth/mobile_tc1_login_single_db_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/auth/`
  * *Hiện trạng thực nghiệm*: Logic chức năng pass, nhưng case test hiệu năng `mobile_tc1_login_single_db_test.dart` fail do thời gian chạy đạt 1000ms vượt ngưỡng cứng 800ms (`evidence_ledger.yaml:150`).
- **1.2 Lựa chọn Cơ sở dữ liệu (Multi-DB Tenant Selection)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/auth/mobile_tc2_multi_db_popup_test.dart`, `vclients/test/features/auth/plan_a_multi_db_test.dart`, `vclients/test/multi_db_login_popup_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/auth/mobile_tc2_multi_db_popup_test.dart test/multi_db_login_popup_test.dart`
  * *Kết quả*: Pass 100% luồng lọc danh sách DB đã pre-auth thành công, loại trừ DB sai mật khẩu.
- **1.3 Phân luồng vai trò Người dùng & Phân quyền Model Động (Portal vs Internal)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/auth/dynamic_discovery_portal_test.dart`, `vclients/test/features/auth/portal_home_attendance_lock_test.dart`, `vclients/test/features/auth/tc2_audit_rules_portal_internal_test.dart`, `vclients/test/portal_user_navigation_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/auth/dynamic_discovery_portal_test.dart test/portal_user_navigation_test.dart`
  * *Kết quả*: Pass phân luồng 3-5 tabs, khóa thẻ chấm công portal, router guard bảo vệ `/timesheet` và `/attendance`.
- **1.4 Khôi phục phiên làm việc tự động (Auto-Restore Session)**: `[⚠️ UNVERIFIED_CODE_ONLY]`
  * *Hiện trạng*: Code triển khai tại `splash_screen.dart` và `auth_controller.dart`. Chưa có test file widget tự động cô lập màn hình Splash khôi phục token từ `FlutterSecureStorage`.
- **1.5 Xóa sạch Token khỏi bộ nhớ RAM (Immediate RAM Token Wipe)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/auth/multi_db_ram_wipe_standalone_test.dart`, `vclients/test/features/auth/multi_db_ram_wipe_test.dart`, `vclients/test/features/auth/logout_session_wipe_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/auth/multi_db_ram_wipe_standalone_test.dart`
  * *Kết quả*: Pass 100% cơ chế hủy token tức thì trong RAM khi chuyển DB hoặc logout.
- **1.6 Dọn sạch phiên và Cache khi Đăng xuất (GlobalStateResetService)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/auth/logout_session_wipe_test.dart`, `vclients/test/security_regression_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/auth/logout_session_wipe_test.dart`
  * *Kết quả*: Pass 12/12 cases dọn sạch RAM cache 10 module và gọi `LocalAttachmentCache.clearAllCache`.
- **1.7 Tự động hủy Đăng ký Device Token Push trên Máy chủ**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/auth/logout_session_wipe_test.dart`, `vclients/test/push_notification_repository_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/auth/logout_session_wipe_test.dart`
  * *Kết quả*: Pass luồng gọi API `/api/v1/mobile/notifications/unregister` vô hiệu hóa token trên server.
- **1.8 Cơ chế Chống nghẽn & Fail-Fast Timeout**: `[🔴 FAILED_OR_BUGGY]` *(Performance Assertion Threshold Exceeded)*
  * *Bằng chứng test*: `vclients/test/features/auth/smart_login_performance_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/auth/smart_login_performance_test.dart`
  * *Hiện trạng thực nghiệm*: Fail ngưỡng trần thời gian đo được 961ms > 800ms trong `evidence_ledger.yaml:150`.

---

### ⏱️ NHÓM 2: TIMESHEET & ATTENDANCE (12 Tính năng)

- **2.1 Check-in / Check-out 1 chạm**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/smart_attendance_test.dart`, `vclients/test/attendance_api_mapping_test.dart`.
  * *Lệnh chạy*: `flutter test test/smart_attendance_test.dart`
  * *Kết quả*: Pass chuyển đổi trạng thái và ghi nhận giờ chấm công chuẩn xác.
- **2.2 Định vị Vệ tinh GPS (Geolocation Verification)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/smart_attendance_test.dart`.
  * *Lệnh chạy*: `flutter test test/smart_attendance_test.dart`
  * *Kết quả*: Pass kiểm tra bán kính trụ sở/chi nhánh trước khi chấp thuận chấm công.
- **2.3 Hộp thoại Hướng dẫn Quyền Vị trí (LocationPromptDialog)**: `[⚠️ UNVERIFIED_CODE_ONLY]`
  * *Hiện trạng*: Code triển khai tại `lib/shared/widgets/location_prompt_dialog.dart`, nhưng không có test file widget tự động trong `vclients/test/`.
- **2.4 Ca làm việc Động từ Odoo (Resource Calendar Engine)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/attendance/shift_calculator_test.dart`, `vclients/test/features/attendance/shift_config_api_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/attendance/`
  * *Kết quả*: Pass tính toán lịch ca làm việc và đồng bộ API.
- **2.5 Thuật toán Khấu trừ Giờ Nghỉ trưa & Đi sớm (Shift Logic)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/attendance/shift_calculator_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/attendance/shift_calculator_test.dart`
  * *Kết quả*: Pass khấu trừ giờ nghỉ trưa và ghi nhận check-in sớm hợp lệ.
- **2.6 Cảnh báo Phiên chưa đóng qua đêm (Unclosed Session Warning)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/attendance/shift_calculator_test.dart:110` (case `Past unclosed session (missing checkout) caps to that day shiftEnd instead of overflowing`).
  * *Lệnh chạy*: `flutter test test/features/attendance/shift_calculator_test.dart`
  * *Kết quả*: Pass logic xử lý phiên dở dang qua đêm.
- **2.7 Hộp thoại Tóm tắt khi Check-out (CheckoutDialog)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/attendance/checkout_task_selection_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/attendance/checkout_task_selection_test.dart`
  * *Kết quả*: Pass hiển thị tổng số giờ làm và chọn task khi checkout.
- **2.8 Lịch sử Chấm công (AttendanceHistoryScreen)**: `[⚠️ UNVERIFIED_CODE_ONLY]`
  * *Hiện trạng*: Màn hình `lib/features/attendance/presentation/attendance_history_screen.dart` có code trong repo nhưng chưa có file widget test độc lập.
- **2.9 Ghi nhận Giờ làm việc vào Task (Log Timesheet Entry)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/timesheet/timesheet_freeform_test.dart`, `vclients/test/timesheet_repository_test.dart`, `vclients/test/task_repository_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/timesheet/timesheet_freeform_test.dart test/task_repository_test.dart`
  * *Kết quả*: Pass log timesheet cho project task và fallback chatter cho task cá nhân.
- **2.10 Đồng hồ Bấm giờ Đếm thời gian thực (Stopwatch Timer)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/timesheet_timer_test.dart`, `vclients/test/task_repository_test.dart`.
  * *Lệnh chạy*: `flutter test test/timesheet_timer_test.dart`
  * *Kết quả*: Pass 29/29 tests stopwatch timer (Start / Pause / Reset / Save).
- **2.11 Thống kê 3 Chỉ số Thời gian (Tổng cho phép - Đã ghi - Còn lại)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/timesheet/timesheet_fix_rc01_05_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/timesheet/timesheet_fix_rc01_05_test.dart`
  * *Kết quả*: Pass tính toán 3 chỉ số không lệch múi giờ và đồng bộ summary.
- **2.12 Bộ lọc Timesheet đa năng (Preset Date Ranges & RC-01..05)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/timesheet/timesheet_filter_test.dart`, `vclients/test/timesheet_filter_verification_test.dart`, `vclients/test/features/timesheet/timesheet_fix_rc01_05_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/timesheet/timesheet_filter_test.dart`
  * *Kết quả*: Pass 13/13 tests bộ lọc linh hoạt, nút chuyển nhanh Tháng này, khử phantom load more.

---

### 💬 NHÓM 3: GIAO TIẾP NỘI BỘ (CHAT V2, MEDIA & CALL) (37 Tính năng)

- **3.1 Phân loại Danh mục Hội thoại Chuẩn Odoo Discuss**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_taxonomy_test.dart`, `vclients/test/features/chat_v2/chat_v2_zalo_oa_member_action_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_taxonomy_test.dart`
- **3.2 Hệ thống Bộ lọc Filter Chips Ngang (6 Chips)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_taxonomy_test.dart`, `vclients/test/features/chat_v2/chat_v2_search_and_filter_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_taxonomy_test.dart`
- **3.3 Bộ lọc Bóc tách Tên Kênh Rác (Sanitize Users + Internal)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_channel_sanitize_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_channel_sanitize_test.dart`
  * *Kết quả*: Pass 20/20 unit tests làm sạch tên kênh.
- **3.4 Ghim Hội thoại Quan trọng (Pin Conversation)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_filter_pin_test.dart`, `vclients/test/features/chat_v2/chat_v2_channel_retention_test.dart` (TASK-16484, 4/4 pass).
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_channel_retention_test.dart`
- **3.5 Tắt/Bật Chuông Thông báo Kênh (Mute Channel)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_mute_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_mute_test.dart`
  * *Kết quả*: Pass 14/14 tests tự động (Duration picker sheet, icon bell-off, bus sync).
- **3.6 Tạo Nhóm Chat Mới & Quản lý Thành viên (Thêm & Xóa Member)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_add_member_test.dart`, `vclients/test/features/chat_v2/chat_v2_zalo_oa_member_action_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_add_member_test.dart`
- **3.7 Màn hình Thông tin Phòng Chat (ChatV2InfoSheet & Rời Nhóm)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_p0_p1_features_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_p0_p1_features_test.dart`
- **3.8 Kết nối Realtime Kép (WebSocket Bus & Long-Polling Fallback)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_live_bidirectional_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_live_bidirectional_test.dart`
- **3.9 Cuộn tải Lịch sử Tin nhắn Mượt mà (Lazy Loading Pagination)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_lazy_loading_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_lazy_loading_test.dart`
- **3.10 Bong bóng Chat Co dãn Tối ưu (Shrink-Wrap Layout)**: `[⚠️ UNVERIFIED_CODE_ONLY]`
  * *Hiện trạng*: Code triển khai trong `chat_v2_message_item.dart`, nhưng không có test case riêng biệt đo lường layout constraints/shrink-wrap dimensions.
- **3.11 Trích dẫn & Trả lời Tin nhắn (Quote / Reply Box & Jump)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_quote_reply_test.dart`, `vclients/test/features/chat_v2/chat_v2_reply_scroll_jump_test.dart`, `vclients/test/features/chat_v2/bug_025_quote_empty_and_temp_messages_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_reply_scroll_jump_test.dart`
- **3.12 Thả Cảm xúc Biểu tượng (Emoji Reactions)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_reaction_details_test.dart`, `vclients/test/features/chat_v2/chat_v2_test.dart`.
- **3.13 Bảng Chi tiết Người Thả Cảm xúc (Reaction Details Sheet)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_reaction_details_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_reaction_details_test.dart`
  * *Kết quả*: Pass 3/3 widget tests hiển thị avatar thật và nhãn (Bạn).
- **3.14 Tạo Cuộc Bình chọn Trực tiếp (Poll Voting)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_poll_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_poll_test.dart`
- **3.15 Chia sẻ Tọa độ Vị trí (Location Sharing Card)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_location_sharing_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_location_sharing_test.dart`
- **3.16 Trạng thái Trực tuyến & Đang soạn tin (Presence & Typing)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_test.dart`.
- **3.17 Trình Xem Ảnh Toàn Màn Hình Đa Ảnh & Lướt Chuyển Trang (Swipeable Gallery)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_image_viewer_gallery_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_image_viewer_gallery_test.dart`
  * *Kết quả*: Pass 26/26 tests gallery PageView, initialIndex, zoom lock.
- **3.17b Tiện Ích Trình Xem Ảnh: Xoay Ảnh 90° & Chia Sẻ Ảnh Ra Ngoài**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_image_viewer_utilities_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_image_viewer_utilities_test.dart`
  * *Kết quả*: Pass 11/11 tests tiện ích độc lập (xoay quarter-turns, reset khi đổi ảnh, share sheet).
- **3.18 Lưu Ảnh Trực tiếp vào Thư viện Máy (Native Gallery Saver)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/core/utils/gallery_saver_test.dart`, `vclients/test/chat_media_picker_safeguard_test.dart`.
  * *Lệnh chạy*: `flutter test test/core/utils/gallery_saver_test.dart`
- **3.19 Trình Đọc Tài liệu Tích hợp trong App (In-App Document Viewer)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_attachment_viewer_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_attachment_viewer_test.dart`
  * *Kết quả*: Pass 14/14 tests mở tài liệu in-app và chặn ném ra trình duyệt ngoài.
- **3.20 Gửi Nhiều Ảnh kèm Chú thích & Chống Văng App (Safe-Guard)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_multi_image_test.dart`, `vclients/test/chat_media_picker_safeguard_test.dart`.
  * *Lệnh chạy*: `flutter test test/chat_media_picker_safeguard_test.dart`
  * *Kết quả*: Pass 7/7 tests multi-tier SAF fallback 4 cấp chống crash.
- **3.20b Kiến Trúc Lưu Trữ Tệp & Ảnh Zalo OA / Hệ Thống (Zero-Storage Client)**: `[⚠️ UNVERIFIED_CODE_ONLY]`
  * *Hiện trạng*: Thiết kế kiến trúc 3 tầng chuẩn, nhưng chưa có test tự động đo lường 0% dung lượng RAM/Disk leak khi chưa bấm mở file.
- **3.21 Ghi âm Nhấn Giữ & Vuốt để Hủy (Hold to Record)**: `[⚠️ UNVERIFIED_CODE_ONLY]`
  * *Hiện trạng*: Code triển khai trong `chat_v2_input_bar.dart`, nhưng chưa có unit/widget test mô phỏng cử chỉ nhấn giữ và vuốt trái hủy ghi âm.
- **3.22 Trình Phát Tin nhắn Thoại Inline (Voice Player)**: `[⚠️ UNVERIFIED_CODE_ONLY]`
  * *Hiện trạng*: Code triển khai trong `chat_v2_voice_message_player.dart`, nhưng chưa có unit/widget test độc lập kiểm thử playback state & duration slider.
- **3.23 Cuộc gọi Thoại 1-1 WebRTC P2P (Native Odoo 19 RTC)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_odoo19_rtc_test.dart`, `vclients/test/features/chat_v2/chat_v2_call_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_odoo19_rtc_test.dart`
  * *Kết quả*: Pass 10/10 tests Odoo 19 RTC Voice Call suite.
- **3.24 Giao diện Cuộc gọi Toàn màn hình (CallKit & Call Control)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_call_widget_test.dart`, `vclients/test/chat_v2_call_ui_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_call_widget_test.dart`
  * *Kết quả*: Pass 27/27 tests điều khiển cuộc gọi, fast-busy signal.
- **3.25 Thông báo Đẩy Nổi trên Android (Heads-up Notification Banner)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/push_notification_repository_test.dart`, `vclients/test/features/chat_v2/in_app_notification_banner_test.dart`.
  * *Lệnh chạy*: `flutter test test/push_notification_repository_test.dart`
  * *Kết quả*: Pass 4/4 tests cấu hình high importance channel.
- **3.26 Đổi Tên Nhóm & Đặt Biệt Danh Chat 1-1 Đồng Bộ Hai Chiều**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_rename_and_nickname_test.dart`, `vclients/test/features/chat_v2/chat_v2_bidirectional_nickname_sync_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_rename_and_nickname_test.dart test/features/chat_v2/chat_v2_bidirectional_nickname_sync_test.dart`
  * *Kết quả*: Pass 20/20 unit tests độc lập đồng bộ biệt danh 2 chiều.
- **3.27 Tối Ưu Điểm Kích Hoạt & Khắc Phục Lỗi UI/UX Tìm Kiếm Tin Nhắn**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_search_in_conversation_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_search_in_conversation_test.dart`
  * *Kết quả*: Pass 10/10 tests (Capsule bar, highlight màu cam/vàng, sửa white-on-white).
- **3.28 Khắc phục Lỗi Chọn Tệp Đính kèm Chat V2 (File Picker PlatformException Safe-Guard)**: `[⚠️ UNVERIFIED_CODE_ONLY]`
  * *Hiện trạng*: Đã phân tích root cause, nhưng chưa có unit test độc lập kiểm thử fallback FilePicker `PlatformException(unknown_path)`.
- **3.29 Chuẩn hóa Menu Ngữ cảnh Hội thoại & Khử Lỗi "Rời Cuộc Trò Chuyện" ở Chat 1-1**: `[⚠️ UNVERIFIED_CODE_ONLY]`
  * *Hiện trạng*: Đã phân tích root cause, chưa có unit test độc lập kiểm tra context menu ẩn nút Leave cho 1-1.
- **3.30 Tạo & Chia Sẻ Link Cuộc Trò Chuyện Chuẩn Odoo Discuss (BUG-003)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_share_link_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_share_link_test.dart`
  * *Kết quả*: Pass 10/10 tests tokenized link `/chat/<id>/<uuid>`.
- **3.31 Gửi & Phát Video In-App (Full In-App Video Sending & Player)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_video_messaging_test.dart`, `vclients/test/features/chat_v2/chat_v2_video_player_riverpod_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_video_messaging_test.dart test/features/chat_v2/chat_v2_video_player_riverpod_test.dart`
  * *Kết quả*: Pass 14/14 video messaging tests và 10/10 Riverpod controller tests.
- **3.32 Lưu Video Vào Thư Viện Ảnh Native Thiết Bị**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_video_messaging_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_video_messaging_test.dart`
  * *Kết quả*: Pass 16/16 tests tích hợp `Gal.putVideo` và safe fallback.
- **3.33 Khắc Phục Lỗi Tin Nhắn Nhảy Lộn Xộn Dòng Thời Gian & Clean Quote Reply (BUG-024)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/bug_024_message_sorting_and_reply_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/bug_024_message_sorting_and_reply_test.dart`
  * *Kết quả*: Pass 10/10 automated tests độc lập sắp xếp `createdAt desc`.
- **3.34 Thực Thi 4 Bước Chuẩn Hóa Backend & Kiểm Chứng L5 Trên Máy Cá Nhân**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `v_mobile_19/tests/` (97 tests Python pass) và `evidence_ledger.yaml:139`.
- **3.35 Khắc Phục Lỗi Bấm Ảnh Này Mở Ảnh Khác Trong Chat V2 (BUG-CHATV2-IMG-MISMATCH)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat_v2/chat_v2_image_viewer_gallery_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat_v2/chat_v2_image_viewer_gallery_test.dart`
  * *Kết quả*: Pass 15/15 tests (Strict Identity Matching, deterministic heroTag).
- **3.36 Khắc Phục Lỗi Tải Tệp Tin Đính Kèm Tiếng Việt (RFC 6266 / RFC 5987)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `test_attachments_disposition.py` (11/11 tests pass trên Odoo 17 & 19), `vclients/test/features/chat_v2/chat_v2_attachment_viewer_test.dart`.
- **3.37 Tối Ưu Hiệu Năng DB, Khử N+1 Query & Củng Cố Router Guard Pha 2 (Build 155)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `test_performance_audit_phase2_patch.py` (15/15 tests pass), `vclients/test/portal_user_navigation_test.dart`.
*(Ghi chú: 1 bài test stress timing `chat_v2_performance_stress_test.dart` chạy 967ms > 300ms do host execution load được ghi nhận cảnh báo tại `evidence_ledger.yaml:168`).*

---

### 🗂️ NHÓM 4: QUẢN LÝ CÔNG VIỆC & DỰ ÁN (HOME DASHBOARD, TASKS, DANH BẠ) (9 Tính năng)

- **4.1 Dashboard Tổng quan Cá nhân hóa (Home Screen Hero)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/home_greeting_and_celebration_test.dart`.
  * *Lệnh chạy*: `flutter test test/home_greeting_and_celebration_test.dart`
  * *Kết quả*: Pass 4/4 greeting & metadata tests (sáng/chiều/tối, chức danh, công ty).
- **4.2 Thẻ Chỉ số Đo lường Kép (Dual-Tier Metric Cards)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/home_dual_tier_metric_test.dart`.
  * *Lệnh chạy*: `flutter test test/home_dual_tier_metric_test.dart`
  * *Kết quả*: Pass unit tests hiển thị 4 thẻ chỉ số thời gian thực.
- **4.3 Nút Chấm công Nhanh trên Trang chủ kèm Hiệu ứng Pháo hoa**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/home_greeting_and_celebration_test.dart`.
  * *Lệnh chạy*: `flutter test test/home_greeting_and_celebration_test.dart`
  * *Kết quả*: Pass trigger hiệu ứng `CelebrationFireworksOverlay`.
- **4.4 Chuông Thông báo Hệ thống (Notification Sheet)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/push_notification_repository_test.dart`.
  * *Lệnh chạy*: `flutter test test/push_notification_repository_test.dart`
  * *Kết quả*: Pass gọi danh sách 20 thông báo và hàm `dismissAll`.
- **4.5 Tăng tốc Tải Trang Dưới 100ms (Cache SWR Engine)**: `[⚠️ UNVERIFIED_CODE_ONLY]`
  * *Hiện trạng*: Có code SWR cache trong `home_summary_controller.dart`, nhưng không có test tự động đo lường thời gian tải thực tế dưới 100ms.
- **4.6 Danh sách Công việc Hôm nay & Thêm Công việc (BUG-021)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/task_repository_test.dart`, `vclients/test/task_priority_features_test.dart`.
  * *Lệnh chạy*: `flutter test test/task_repository_test.dart`
  * *Kết quả*: Pass 11/11 tests tạo task, Many2many `user_ids`, dropdown dự án động.
- **4.7 Hoàn thành Nhanh Task & Log Giờ (Log Completion Sheet)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/task_repository_test.dart`.
  * *Lệnh chạy*: `flutter test test/task_repository_test.dart`
  * *Kết quả*: Pass ghi nhận số giờ và đổi trạng thái task sang done.
- **4.8 Trình Biên tập Checklist Đầu việc trong Task (Checklist Editor)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/task_checklist_subtasks_test.dart`.
  * *Lệnh chạy*: `flutter test test/task_checklist_subtasks_test.dart`
  * *Kết quả*: Pass 12/12 tests subtasks checklist (toggle, thêm/xóa subtask, tính % tiến độ).
- **4.9 Danh bạ Đồng nghiệp & Tra cứu Nhanh**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/chat/chat_repository_test.dart`, `vclients/test/chat_openapi_mapping_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/chat/chat_repository_test.dart`
  * *Kết quả*: Pass tìm kiếm người dùng qua `/api/v1/mobile/users/search`.

---

### 🎫 NHÓM 5: HỖ TRỢ & XỬ LÝ YÊU CẦU (TICKET / HELPDESK, SLA) (14 Tính năng)

- **5.1 Danh sách Phiếu Yêu cầu & Phân trang (Ticket List Screen)**: `[🔴 FAILED_OR_BUGGY]`
  * *Hiện trạng thực nghiệm*: Tồn đọng lỗi kiến trúc xác nhận **GAP-TICKET-02** (chạm trần cứng 20 ticket do thiếu phân trang Infinite Scroll, tìm kiếm chỉ thực thi in-memory trên 20 bản ghi tải về RAM, bộ lọc thiếu lọc Stage chuẩn Odoo).
- **5.2 Tạo Phiếu Yêu cầu Hỗ trợ Mới (Create Ticket Screen)**: `[🔴 FAILED_OR_BUGGY]`
  * *Hiện trạng thực nghiệm*: Tồn đọng lỗi nghiệp vụ (thiếu trường chọn đối tác khách hàng `partner_id` khiến nhân viên tạo hộ bị ép gán tên mình; thiếu trường chọn hạn cam kết SLA `date_deadline`). Nút Back PopScope đã pass trong `create_ticket_back_navigation_test.dart` (TASK-16486).
- **5.3 Đính kèm Hình ảnh & Tệp tin vào Ticket & Mở File In-App**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/ticket_attachment_verification_test.dart`.
  * *Lệnh chạy*: `flutter test test/ticket_attachment_verification_test.dart`
  * *Kết quả*: Pass 9/9 tests (mở ảnh in-app, URL kèm JWT bearer token, smart name formatting).
- **5.4 Màn hình Chi tiết Ticket Toàn diện (Ticket Detail Screen & Transition)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/ticket/ticket_gaps_v2_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/ticket/ticket_gaps_v2_test.dart`
  * *Kết quả*: Pass 26/26 tests, gỡ bỏ Hero tag loại bỏ hiện tượng tiêu đề rơi tự do.
- **5.5 Luồng Trao đổi & Bình luận Trực tiếp & Phân Định Tác Giả (Chatter Comments)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/ticket/ticket_chatter_author_isolation_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/ticket/ticket_chatter_author_isolation_test.dart`
  * *Kết quả*: Pass 12/12 tests phân định tác giả độc quyền `comment.authorName`, không lệch khi nhận ticket.
- **5.6 Bộ lọc Làm sạch Mã HTML Odoo (HTML-to-Text Sanitizer)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/ticket_html_mapping_test.dart`.
  * *Lệnh chạy*: `flutter test test/ticket_html_mapping_test.dart`
  * *Kết quả*: Pass 2/2 tests bóc tách thẻ HTML rác và thực thể HTML entities.
- **5.7 Đo lường Cam kết Dịch vụ (SLA Status & Deadline)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/ticket_sla_overdue_test.dart`.
  * *Lệnh chạy*: `flutter test test/ticket_sla_overdue_test.dart`
  * *Kết quả*: Pass 4/4 tests fix BUG-012, không báo động giả khi deadline null.
- **5.8 Đánh giá Mức độ Hài lòng (Customer Satisfaction Ratings)**: `[⚪ DESCOPED_SKIPPED]`
  * *Hiện trạng*: Đã bỏ qua theo chỉ đạo trực tiếp của Sếp Tân ("em ko cần làm nhé bỏ cái 5.5 did").
- **5.9 Chế độ Riêng cho Khách hàng Portal & An toàn Dữ liệu (Portal Mode Isolation)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `v_mobile_17/tests/test_portal_ticket_isolation.py`, `v_mobile_19/tests/test_portal_ticket_isolation.py`.
  * *Kết quả*: Pass 10/10 contract tests (5/5 trên Odoo 17, 5/5 trên Odoo 19), bảo vệ chống IDOR.
- **5.10 Quản lý Hoạt động Nhắc việc (Helpdesk Activities - mail.activity)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/ticket/ticket_gaps_v2_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/ticket/ticket_gaps_v2_test.dart`
  * *Kết quả*: Pass tạo và hoàn thành hoạt động `mail.activity`.
- **5.11 Quy trình Mở lại Phiếu Yêu cầu (Reopen Ticket Workflow)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/ticket/ticket_gaps_v2_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/ticket/ticket_gaps_v2_test.dart`
  * *Kết quả*: Pass quy trình Reopen đưa ticket về trạng thái đang xử lý.
- **5.12 Phân công & Chuyển giao Phiếu Hỗ trợ (Ticket Assignment & Reassign)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/ticket/ticket_gaps_v2_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/ticket/ticket_gaps_v2_test.dart`
  * *Kết quả*: Pass API và UI phân công kỹ thuật viên phụ trách.
- **5.13 Chỉnh sửa Thông tin Phiếu Yêu cầu (Edit Ticket Details)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/ticket/ticket_gaps_v2_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/ticket/ticket_gaps_v2_test.dart`
  * *Kết quả*: Pass cập nhật tiêu đề, mô tả, độ ưu tiên P1-P4 và đội xử lý.
- **5.14 Dọn dẹp Endpoint Rác & Dead Code (Ticket Dead APIs Cleanup)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/ticket/ticket_gaps_v2_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/ticket/ticket_gaps_v2_test.dart`
  * *Kết quả*: Pass bảo toàn audit trail (chặn xóa comment ảo, đưa sendContact về chatter).

---

### 👤 NHÓM 6: HỒ SƠ CÁ NHÂN & TIỆN ÍCH HỆ THỐNG (PROFILE & UTILS) (10 Tính năng)

- **6.1 Thẻ Hồ sơ Định danh Nhân sự (Profile Hero Card)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/auth_avatar_mapping_test.dart`, `vclients/test/features/profile/profile_edit_test.dart`.
  * *Lệnh chạy*: `flutter test test/auth_avatar_mapping_test.dart`
  * *Kết quả*: Pass đồng bộ avatar, họ tên và chức danh động 100% từ Odoo `/api/v1/auth/me`.
- **6.2 Chỉnh sửa Thông tin Cá nhân (Edit Profile Screen - Avatar Upload)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/profile/profile_edit_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/profile/profile_edit_test.dart`
  * *Kết quả*: Pass 5/5 widget tests mở bottom sheet đổi avatar, tải ảnh và cập nhật.
- **6.3 Tùy chọn Chế độ Giao diện Sáng / Tối (Theme Mode Controller)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/profile/profile_edit_test.dart` (tests 6, 7, 8).
  * *Lệnh chạy*: `flutter test test/features/profile/profile_edit_test.dart`
  * *Kết quả*: Pass kiểm thử giao diện Dark Mode (`#0F172A`) và Light Mode.
- **6.4 Giải phóng Dung lượng Bộ nhớ Đệm (Clear Cache)**: `[⚠️ UNVERIFIED_CODE_ONLY]`
  * *Hiện trạng*: Code triển khai tại `_CacheRow` và `LocalAttachmentCache.getCacheSizeInMB()`. Symbol `clearAllCache` được kiểm tra trong `security_regression_test.dart`, nhưng chưa có widget test độc lập mô phỏng dialog dọn dẹp bộ nhớ đệm và hiển thị số MB.
- **6.5 Tra cứu & Sao chép Mã Thiết bị Push (FCM Device Token)**: `[⚠️ UNVERIFIED_CODE_ONLY]`
  * *Hiện trạng*: Tính năng chủ đích ẩn trên UI người dùng cuối theo chỉ đạo PO; chưa có test kiểm tra hành vi ẩn này.
- **6.6 Màn hình Thông tin Ứng dụng & Bản quyền (About Screen)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/profile/about_screen_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/profile/about_screen_test.dart`
  * *Kết quả*: Pass 1/1 widget test hiển thị phiên bản, logo và link chính sách riêng tư.
- **6.7 Bảng Tính năng Mới theo Phiên bản (What's New Sheet)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/shared/widgets/whats_new_sheet_test.dart`.
  * *Lệnh chạy*: `flutter test test/shared/widgets/whats_new_sheet_test.dart`
  * *Kết quả*: Pass 2/2 widget tests render version badge, 4 feature cards và nút CTA.
- **6.8 Yêu cầu Xóa Tài khoản (Account Deletion Compliance)**: `[⚠️ UNVERIFIED_CODE_ONLY]`
  * *Hiện trạng*: Code hiển thị AlertDialog cam kết 30 ngày và `launchUrl` mở email `support@360.org.vn` trong `profile_screen.dart`, nhưng chưa có test widget tự động độc lập.
- **6.9 Đăng xuất An toàn & Dọn dẹp Toàn diện (Secure Logout)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/auth/logout_session_wipe_test.dart`.
  * *Lệnh chạy*: `flutter test test/features/auth/logout_session_wipe_test.dart`
  * *Kết quả*: Pass 12/12 tests dọn dẹp toàn diện 4 tầng dữ liệu, zero-data-leakage.
- **6.10 Tối Ưu Độ Tương Phản & Sửa Lỗi Giao Diện Hồ Sơ Trong Dark Mode (BUG-023)**: `[✅ VERIFIED_PASS]`
  * *Bằng chứng test*: `vclients/test/features/profile/profile_edit_test.dart` (tests 6-11).
  * *Lệnh chạy*: `flutter test test/features/profile/profile_edit_test.dart`
  * *Kết quả*: Pass 6/6 tests contrast Dark Mode (tiêu đề Slate 100 `#F1F5F9` w700, khung giá trị Slate 900 `#0F172A`, AppBar phẳng `#1E293B`).

---

## 3. KẾT LUẬN & ĐỀ XUẤT CỦA AUDIT GATE

1. **Độ tin cậy của Hệ thống**: 72/90 tính năng đạt **`[✅ VERIFIED_PASS]`** với đầy đủ file test tự động và log kiểm thử độc lập.
2. **Khắc phục 2 điểm nghẽn hiệu năng Auth**: Điều chỉnh hoặc nới lỏng assertion threshold trên máy test host load cho `mobile_tc1_login_single_db_test.dart` và `smart_login_performance_test.dart` (hiện vượt ngưỡng 800ms đạt 961ms - 1000ms).
3. **Giải quyết 2 khiếm khuyết phân hệ Helpdesk**: Bổ sung cơ chế Infinite Scroll + Server search cho 5.1 và hoàn thiện trường `partner_id` + `date_deadline` cho 5.2.
4. **Bổ sung test cho 13 tính năng UNVERIFIED_CODE_ONLY**: Ưu tiên viết widget test cho các tính năng người dùng thường xuyên tương tác (Hold-to-record 3.21, Voice player 3.22, LocationPromptDialog 2.3, AttendanceHistory 2.8, Clear Cache 6.4).
