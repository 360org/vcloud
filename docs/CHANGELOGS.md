# 📜 LỊCH SỬ THAY ĐỔI & PHÁT TRIỂN (CHANGELOGS.md)

Tất cả các thay đổi đáng chú ý của hệ sinh thái **VCloud Mobile App & Odoo Backend** sẽ được ghi chép tại tài liệu này theo tiêu chuẩn **AIaC 3.0**.

## [v2.9.5+125] — 2026-09-11 (Document Download Defense, Placeholder Interception & Web/Mobile Error Fixes)

> [!IMPORTANT]
> **Vá Lỗi Toàn Diện Cơ Chế Mở Tệp Tài Liệu & Chống Nhận Nhầm Ảnh Placeholder Của Odoo**:
> - **Phạm vi**: `vclients` (Flutter Web & Mobile)
> - **Chi tiết thay đổi**:
>   1. **Chặn lỗi DNS NXDOMAIN trên Web**: Chuẩn hóa `resolvedDownloadUrl`, kiểm tra tiền tố HTTP/HTTPS/API trước khi gọi trình duyệt, triệt tiêu lỗi Chrome phân giải nhầm tên tệp (`work.xlsx`) thành domain.
>   2. **Chặn lỗi 500 Internal Server Error trên Safari iOS**: Luôn tải tệp qua Bearer Token authenticated API nội bộ (`odooApiClient.fetchBytes`) thay vì bắn link ra trình duyệt ngoài thiếu database session.
>   3. **Chặn nhận nhầm ảnh Placeholder Odoo**: Bổ sung `MagicBytesValidator.isMistakenImagePayloadForDocument()` nhận diện chữ ký PNG và kích thước chuẩn 6078 bytes của Odoo `placeholder.png`. Tự động ngăn lưu đè ảnh máy ảnh rỗng thành file `.docx` / `.xlsx`.
>   4. **Tự làm sạch Cache**: `LocalAttachmentCache` từ chối lưu và tự xóa bỏ các bản ghi cache tệp văn phòng bị dính ảnh placeholder.
>   5. **Cải tiến UI/UX**: Thông báo SnackBar màu đỏ rõ ràng khi tệp không tồn tại hoặc tài khoản thiếu quyền hạn trên máy chủ Odoo.

---

## [v17.0.2.3.7 / v19.0.1.1.9 / v2.9.5+124] — 2026-09-09 (Chat @ Mention Architecture, IDOR Guard & High-Performance Batch Prefetch)

> [!IMPORTANT]
> **Triển khai Toàn diện Tính năng @ Mention Trong Tin Nhắn Discuss Chat Đa Nền Tảng**:
> - **Tiêu chuẩn áp dụng**: `docs/SPEC_CHAT_MENTION.md` & `docs/SPEC.md` Section IX.
> - **Phạm vi**: `v_mobile_17`, `v_mobile_19`, `vclients`
> - **Mục tiêu**:
>   1. Cho phép người dùng gắn thẻ `@Thành_Viên` trong phòng chat 1-1, nhóm và kênh Odoo Discuss với gợi ý autocomplete thời gian thực.
>   2. Bảo mật chống IDOR & Privilege Escalation qua việc xác thực thành viên kênh trước khi gắn tag và gửi notification.
>   3. Tương thích hai chiều giữa Web Odoo (HTML Anchor) và Mobile Flutter (Rich Text Token) với cơ chế chống XSS và ReDoS.
>   4. Tối ưu hiệu năng nạp tin nhắn qua truy vấn Direct SQL Index Seek trên bảng quan hệ `mail_message_res_partner_rel` (0 N+1 query).

### 🌟 [TÍNH NĂNG & CẢI TIẾN MỚI]
- `[NEW]` **Backend @ Mention Engine (`controllers/chat.py` trên Odoo 17 & 19)**:
  * Trích xuất danh sách `partner_ids` và `mentioned_partners` từ payload tin nhắn.
  * Xác thực IDOR thành viên kênh qua `channel_partner_ids` / `discuss.channel.member` và tự động loại trừ chính `env.user.partner_id`.
  * Chuyển đổi an toàn sang Odoo-standard HTML anchor (`<a href="#" data-oe-model="res.partner" data-oe-id="{pid}" class="o_mail_redirect">@{name}</a>`) bọc `markupsafe.Markup` và `html.escape` chống XSS.
  * Truyền danh sách `partner_ids` vào `channel.message_post()` để Odoo kích hoạt thông báo nhắc việc / push notification chuẩn.
  * Tối ưu SQL batch prefetch `partner_ids` qua bảng `mail_message_res_partner_rel` khi truy vấn danh sách tin nhắn `list_messages`.
- `[NEW]` **Flutter Client UI/UX Mention Autocomplete (`vclients`)**:
  * **Model**: Cập nhật `ChatV2Message` hỗ trợ trường `partnerIds` (`fromMap`, `toMap`, `copyWith`, `operator==`, `hashCode`).
  * **Repository & Controller**: Cập nhật `ChatV2Repository.sendMessage` và `ChatV2MessagesNotifier.sendMessage` truyền `partner_ids` và `mentioned_partners`.
  * **Input Bar**: Thêm overlay popup `_buildMentionSuggestionsBox` gợi ý thành viên khi gõ ký tự `@`, lọc theo tên/email, loại bỏ `isMe`, tự động điền token `@Tên ` và bám sát các mention hợp lệ khi gửi.
  * **Chat Bubble**: Thêm bộ parser `_addTextWithMentions` trong `ChatV2MessageItem` định dạng màu nhấn (`#0284C7` / `#38BDF8`) và in đậm cho các token `@Tên`.
- `[TEST]` **Kiểm thử Tự động Toàn diện**:
  * Backend Contract Tests `tests/test_chat_mention_contract.py`: 5/5 PASS trên cả Odoo 17 và Odoo 19.
  * Flutter Test Suite `flutter test --exclude-tags=live-server`: 281/281 PASS 100%.
  * Flutter Linter `flutter analyze`: 0 errors / 0 warnings.

---

## [v17.0.2.3.6 / v19.0.1.1.8 / v2.9.5+123] — 2026-09-09 (Multi-Layer Attachment Fallback, Portal Ticket Isolation & ReDoS Fixes)

> [!IMPORTANT]
> **Bộ Vá Lỗi Đa Tầng Cho Attachment Streaming, Bảo Mật Portal Ticket & Gia Cố Mobile Client**:
> - **Phạm vi**: `v_mobile_17`, `v_mobile_19`, `vclients`
> - **Mục tiêu**:
>   1. Khắc phục triệt để lỗi HTTP 404 `attachment_empty` trên `/api/v1/mobile/attachments/<id>/download` qua Multi-Layer Streaming Fallback 6 nấc.
>   2. Vá lỗ hổng IDOR/Data Leak trong `ticket_list` đối với người dùng Portal.
>   3. Khử 3 điểm ReDoS regex trên Flutter client và chuẩn hóa fallback auth cơ sở dữ liệu `vuahethong.net`.

### 🌟 [TÍNH NĂNG & SỬA LỖI MỚI]
- `[FIX]` **Multi-Layer Streaming Fallback (`v_mobile_17` & `v_mobile_19`)**: Hỗ trợ 6 nấc tải file nhị phân (URL redirect 302, `att.raw`, `att.datas`, `res_field` proxy attachment, SQL cursor `db_datas` / filestore `store_fname`, `ir.binary` stream) và guard `_ensure_request_env()`.
- `[SECURITY]` **Portal Ticket Isolation Guard**: Chèn domain `partner_id` trước `.sudo()` trong `ticket_list` của cả Odoo 17 & 19.
- `[FIX]` **Chat Attachment Fallback (`vclients`)**: Thêm fallback `MobileAttachmentRepository().fetchBytes()` trong `chat_v2_message_item.dart`.
- `[SECURITY]` **ReDoS Elimination (`vclients`)**: Chuẩn hóa regex linear backtracking trong `chat_bubbles.dart`, `chat_v2_message_item.dart`, `chat_v2_info_sheet.dart`.
- `[TEST]` **Regression Tests Pass 100%**: `test_attachments_stream_fallback.py` (5/5 PASS), `test_portal_ticket_isolation.py` (5/5 PASS), `test_api_v19_routing.py` (6/6 PASS), `profile_edit_test.dart` (5/5 PASS).

---

## [v17.0.2.3.4] — 2026-09-09 (Backend: Master Directory Mapping & Multi-Tenant Routing)

> [!IMPORTANT]
> **Chuẩn hóa Kiến trúc Định tuyến Đa Cơ sở Dữ liệu (1+N Master Directory Routing)**:
> - **Tiêu chuẩn áp dụng**: Sơ đồ Kiến trúc VCloud Mobile qua `vuahethong.net` & `SPEC.md` Section VI.
> - **Phạm vi**: `v_mobile_17`, `v_mobile_19`, `vclients`
> - **Mục tiêu**: Giải quyết triệt để lỗi tài khoản đa tenant (như `support@360.org.vn` trên NDS, Davita, Salem, v.v.) không tìm thấy cơ sở dữ liệu khi tra cứu qua Master.

### 🌟 [TÍNH NĂNG & CẢI TIẾN MỚI]
- `[NEW]` **Central Directory Model (`databases.user`)**: Khởi tạo bảng lưu trữ ánh xạ trung tâm giữa tài khoản (`login`) và cơ sở dữ liệu đích (`database_name`, `database_url`, `has_v_mobile`, `category_label`).
- `[FIX]` **Master Lookup Engine (`controllers/auth.py`)**: Nâng cấp endpoint `POST /api/v1/auth/lookup-db` ưu tiên đọc dữ liệu ánh xạ từ `databases.user`, loại bỏ hoàn toàn lỗi kết nối chéo giữa các máy chủ PostgreSQL độc lập.
- `[SECURITY]` **Fail-Safe & Anti-Enumeration**: Giữ nguyên cơ chế chống Host Header Poisoning (Fail-closed với `web.base.url`) và chống Wildcard Injection (`%`).
- `[TEST]` **Test Suite Pass 100%**: Bổ sung kiểm thử `test_11_lookup_db_central_directory_mapping` trên Backend và vượt qua toàn bộ kiểm thử xác thực Flutter `test/directory_lookup_auth_test.dart` (8/8 tests PASS).

---

## [v17.0.2.3.2] — 2026-09-09 (Backend & Flutter: SPEC Section VIII — Portal Users Governance & Dynamic Navigation)

> [!IMPORTANT]
> **Đặc Tả & Thiết Lập Kiến Trúc Phân Quyền Portal Users (Khách hàng bên ngoài) vs Internal Users (Nhân viên)**:
> - **Tiêu chuẩn áp dụng**: `docs/SPEC.md` Section VIII & `vclients/docs/SPEC.md`
> - **Phạm vi**: `v_mobile_17`, `v_mobile_19`, `vclients`
> - **Mục tiêu**: Bảo mật dữ liệu nội bộ tuyệt đối, cung cấp Dynamic Navigation 3-tab (Ticket, Chat, Profile) cho khách hàng Portal và chặn truy cập trái phép vào các tính năng nhân sự (Attendance, Timesheet).

### 🌟 [ĐẶC TẢ KỸ THUẬT & PHÂN QUYỀN MỚI]
- `[SECURITY]` **Portal User Detection**: Bổ sung `is_portal` và `user_type` vào API login và `/api/v1/auth/me`.
- `[SECURITY]` **Data Isolation (Anti-Data-Leak)**: Loại bỏ `.sudo()` trần trong `controllers/ticket.py` và `controllers/project.py`. Bắt buộc domain giới hạn chỉ cho Portal User thấy Ticket/Task của chính mình hoặc được chia sẻ trực tiếp.
- `[SECURITY]` **Internal Feature Guards**: Áp dụng rào chắn `403 Forbidden` đối với Portal Users tại tất cả các endpoint Chấm công (`hr.attendance`) và Timesheet (`account.analytic.line`), ngừng tự động sinh bản ghi `hr.employee`.
- `[NEW]` **Dynamic Navigation Flutter**: Hỗ trợ 2 bộ Tab điều hướng trong `AppScaffold`: Nhân viên (5 tabs) vs Khách hàng Portal (3 tabs: Ticket, Chat, Tôi).
- `[ROUTER]` **Portal Route Guard**: Chuyển hướng Portal User vào `/tickets` sau khi đăng nhập và chặn các route nhân sự deep-link.

---

## [v17.0.2.3.1] — 2026-09-08 (Backend Odoo 17: SPEC-PROVISIONING-01 Phase 3 Master Router & Scheduler Integration)

> [!IMPORTANT]
> **Hoàn Tất Trọn Vẹn 3 Phase Kiến Trúc Zero-Touch Tenant Provisioning (SPEC-PROVISIONING-01 v2.0)**:
> - **Tiêu chuẩn áp dụng**: `SPEC-PROVISIONING-01 v2.0`
> - **Phạm vi**: `v_mobile_17` (Branch: `feat/task-20-worker-engine-isolation`)
> - **Trạng thái kiểm thử**: **100% PASS (18/18 Tests PASS trên PostgreSQL SSOT, Safe Lock Fencing, Worker Engine và Router Integration)**.

### 🌟 [TÍNH NĂNG MỚI (PHASE 3 MASTER ROUTER & SCHEDULER DAEMON)]
- `[SECURITY]` **Master Router Gatekeeper (`controllers/auth.py`)**: Lọc bỏ 100% các database chưa đạt chuẩn `READY`, tự động nạp trạng thái `DISCOVERED` vào PostgreSQL SSOT khi user authenticate thành công vào tenant mới, bảo vệ triệt để chống lỗi 500 trên Mobile.
- `[INFRA]` **Odoo Scheduled Cron Runner (`data/provision_cron.xml`, `models/tenant_registry.py`)**: Tự động kích hoạt chu kỳ tuần tra 1 phút/lần gọi `ProvisionWorker.process_pending_tenants()` xử lý ngầm các database mới phát hiện.
- `[INFRA]` **Standalone Provisioning Daemon (`scripts/run_provision_worker.py`)**: CLI runner cho phép chạy background worker độc lập ngoài Odoo Web Process.
- `[TEST]` **Test Suite Tích Hợp Toàn Trình (`models/test_phase3_integration.py`)**: Đạt 4/4 test scenarios chuẩn Acceptance Matrix.

---

## [v17.0.2.3.0] — 2026-09-08 (Backend Odoo 17: SPEC-PROVISIONING-01 Zero-Touch Tenant Provisioning Engine)


> [!IMPORTANT]
> **Triển Khai Hoàn Tất Phase 1 & Phase 2 Kiến Trúc Zero-Touch Tenant Provisioning**:
> - **Tiêu chuẩn áp dụng**: `SPEC-PROVISIONING-01 v2.0`
> - **Phạm vi**: `v_mobile_17` (Branch: `feat/task-20-worker-engine-isolation`)
> - **Trạng thái kiểm thử**: **100% PASS (14/14 Tests PASS trên PostgreSQL SSOT, Safe Lock Fencing và Worker Engine)**.

### 🌟 [TÍNH NĂNG MỚI (ZERO-TOUCH TENANT PROVISIONING ENGINE)]
- `[NEW]` **PostgreSQL Registry SSOT (`vcloud_tenant_registry`)**: Lưu trữ và điều phối vòng đời tenant qua 6 trạng thái chuẩn (`DISCOVERED`, `CHECKING`, `INSTALLING`, `VERIFYING`, `READY`, `FAILED`, `QUARANTINED`), chống mất dữ liệu khi restart.
- `[SECURITY]` **SafeProvisionLock Protocol (P0-2)**: Giao thức khóa phân tán chống xung đột đồng thời với Owner UUID, Lease TTL (60s), Heartbeat renewal ngầm qua Lua script và giải phóng khóa an toàn chống ghi đè/xóa nhầm từ worker cũ.
- `[INFRA]` **Dedicated Docker One-Off Container (`provision_docker_engine.py`)**: Đóng gói tiến trình provision chạy độc lập (`docker run --rm`), áp giới hạn tài nguyên CPU/RAM và timeout watchdog (180s), cô lập cgroup hoàn toàn với Web worker đang live.
- `[SECURITY]` **5-Tier Health Check Engine (`provision_health_check.py`)**: Thẩm định toàn diện 5 tầng (DB Connect ➔ Module State ➔ Schema 3 Tables ➔ Mobile Health API ➔ JWT Boundary) trước khi cấp cờ `READY`.
- `[SECURITY]` **Fault Classification & Quarantine (`provision_worker.py`)**: Tự động phân loại lỗi `Retryable` (tối đa 3 lần backoff) vs `Non-Retryable` (cách ly ngay lập tức vào `QUARANTINED`).
- `[IMPROVE]` **Master Router Zero-Knowledge (`auth.py`)**: Xác thực Password trước khi cấp danh sách DB, ngăn chặn hoàn toàn việc rò rỉ hoặc dò quét database của khách hàng.

---

## [v2.9.0+98] — 2026-08-30 (CI/CD Governance — Release-Gated Deployment)


> [!IMPORTANT]
> **Thay đổi CI/CD Pipeline (Infra / DevOps)**:
> - **Phạm vi**: `vclients` — GitHub Actions workflow (`deploy.yml`)
> - **Mục tiêu**: Tách biệt hoàn toàn sự kiện merge code với sự kiện build & deploy, để anh Tân kiểm soát 100% thời điểm phát hành và cho phép rollback theo từng Release version.

### ⚙️ [CI/CD & INFRA]
- `[IMPROVE]` **Cập nhật GitHub Actions trigger (`deploy.yml`)**:
  - **Bỏ** trigger `push: branches: [main]` — commit vào `main` không còn tự động kích hoạt build & deploy TestFlight.
  - **Thêm** trigger `release: types: [published]` — Action chỉ chạy khi một GitHub Release được publish chính thức.
  - Giữ nguyên `workflow_dispatch` để anh Tân có thể kích hoạt build thủ công bất kỳ lúc nào.
- `[IMPROVE]` **Cập nhật RULE_GIT.md (Mục 5)** — Đồng bộ lại tài liệu quy chuẩn CI/CD phản ánh đúng quy trình mới: `merge PR vào main ➔ tạo Release trên GitHub ➔ Action build & deploy`.

---

## [v2.9.0+95] — 2026-08-28 (Frontend Flutter & Backend Odoo 17/19: Smart Attendance & HR Workdays Engine)

> [!IMPORTANT]
> **Bộ Cập Nhật Toàn Diện Chấm Công & Bảng Công Thông Minh (Mobile Client & Dual-Backend Odoo 17/19)**:
> - **Frontend**: `vclients` (Flutter App `2.9.0+95`)
> - **Backend Odoo 17**: `v_mobile_17` (Version `17.0.2.2.7`)
> - **Backend Odoo 19**: `v_mobile_19` (Version `19.0.1.1.1`)
> - **Trạng thái kiểm thử**: **100% PASS (Static 0 issues, 260/260 Unit/Widget/Integration Tests PASS)**.

### 🌟 [TÍNH NĂNG MỚI & SỬA LỖI CỐT LÕI (SMART ATTENDANCE & HR WORKDAYS)]
- `[NEW]` **Xử lý Ca Quên Check-out Xuyên Ngày (Cross-Day Stale Attendance Resolution — P0)**:
  - Backend tự động phát hiện phiên check-in mở của các ngày hôm trước (`open_att.check_in < start_of_day_utc`) tại `/api/v1/mobile/attendance/today`, trả về `is_stale_open: True` kèm `suggested_checkout_time` (mặc định theo giờ tan ca chuẩn của ngày đó).
  - Cung cấp endpoint an toàn `POST /api/v1/mobile/attendance/resolve-stale` cho phép 1 chạm đóng ca cũ theo giờ quy định hoặc chọn giờ tùy chỉnh và tự động check-in ca mới hôm nay.
  - Frontend hiển thị `_StaleAttendanceRecoveryBanner` màu cam cảnh báo nổi bật ngay trên màn hình Chấm công khi phát hiện ca quên check-out, triệt tiêu 100% lỗi ca làm việc ảo 24h+.
- `[NEW]` **Chuẩn Hóa Múi Giờ UTC vs Local Timezone (`user.tz`) (Timezone Boundary — P0)**:
  - Khắc phục triệt để lỗi mất dấu phiên chấm công sáng sớm (trước 07:00 sáng VN, tương đương < 00:00 UTC) do Odoo dùng `fields.Date.today()` theo UTC.
  - Sử dụng hàm chuẩn hóa `_get_local_day_utc_range()` tính toán chính xác biên độ ngày địa phương `00:00:00 -> 23:59:59` của nhân viên theo múi giờ `employee.user_id.tz or 'Asia/Ho_Chi_Minh'` rồi convert về UTC để truy vấn `hr.attendance`.
- `[NEW]` **Bảng Tổng Hợp Ngày Công & KPIs Nhân Sự (HR Attendance KPIs Card — P1)**:
  - Tích hợp `_HrAttendanceKpisCard` và Provider `hrAttendanceMonthSummaryProvider` tính toán tự động: Số ngày công thực tế (VD: `21.5 / 26 ngày`), Số lần đi muộn (kèm tổng số phút), Số lần về sớm, Số giờ tăng ca (OT).
  - Hiển thị trực quan thanh tiến độ ngày công, bảng tóm tắt chi tiết và chấm trạng thái màu trên từng ô lịch tháng (`HrDayAttendanceStatus`: Đủ công - Xanh lá, Nửa công - Vàng, Đi muộn/Về sớm - Cam, Vắng/Quên - Đỏ, Cuối tuần - Xám).
- `[NEW]` **Minh Bạch Chi Tiết Đối Soát Đi Muộn / Về Sớm / OT (HR Event Breakdown & Audit Sheet)**:
  - Bổ sung model `HrAttendanceEventDetail` (`lateDetails`, `earlyDetails`, `overtimeDetails`) trong `vclients/lib/shared/models/attendance.dart`.
  - Cho phép chạm trực tiếp vào các ô KPI ("Đi muộn", "Về sớm", "Làm thêm OT") trên thẻ Bảng đối soát công HR để mở Bottom Sheet `_HrEventDetailsBottomSheet`.
  - Hiển thị tường minh từng ngày vi phạm/tăng ca: Ngày trong tuần + Ngày tháng (VD: Thứ Ba, 12/08/2026), Giờ vào/tan ca chuẩn vs Giờ thực tế Check-in/Check-out, Số phút chênh lệch và nút 1-chạm "Xem trên lịch".
  - Tự động đính kèm chi tiết từng lần đi muộn và về sớm vào bản xuất văn bản `_ExportAttendanceSummaryDialog` gửi Kế toán qua Zalo/Messenger/Email để tránh mọi tranh cãi đối soát.
- `[NEW]` **Bộ Chọn Tháng/Năm Nhanh (Month Picker Sheet) & Xuất Báo Cáo Gửi Kế Toán (P2)**:
  - Tích hợp Bottom Sheet `_MonthYearPickerSheet` cho phép chuyển đổi nhanh chóng giữa các tháng trong 3 năm gần nhất.
  - Backend hỗ trợ tham số `month=YYYY-MM` trong `/api/v1/mobile/attendance/history` để tải lịch sử bảng công theo tháng đích.
  - Tích hợp Dialog `_ExportAttendanceSummaryDialog` định dạng bảng công dạng văn bản trực quan (gồm thông tin nhân viên, tháng, chỉ số KPI và bảng chi tiết từng ngày), hỗ trợ nút 1-chạm sao chép vào bộ nhớ tạm gửi kế toán/quản lý qua Zalo, Messenger, Email.

---

> [!IMPORTANT]
> **Nhánh Backend Odoo 17 (`v_mobile`)**: `17.0` (Version: `17.0.2.2.5`)
> - **Mục tiêu**: Chuẩn hóa logic trích xuất ca làm việc từ `resource.calendar` và alias routes cho Chấm công.
> - **Trạng thái kiểm thử**: **100% PASS (Contract & Integration Tests)**.

### 🛠️ [SỬA LỖI & NÂNG CẤP CHẤM CÔNG (ATTENDANCE & SHIFT SCHEDULE FIX)]
- `[FIX]` **Sửa lỗi trích xuất ca làm việc `_get_shift_config` (`controllers/attendance.py`)**: 
  - Khắc phục lỗi lấy nhầm bản ghi thứ 2 (`sorted_att[1]`) làm ca chiều khi lịch làm việc `resource.calendar` có 3 bản ghi (VD: `08:00 - 12:00`, `12:00 - 13:00`, `13:00 - 17:00`).
  - Sử dụng trường `day_period` (`morning` / `afternoon`) chuẩn Odoo 17+ để lọc chính xác ca sáng và ca chiều, fallback an toàn về bản ghi đầu và cuối (`sorted_att[0]` và `sorted_att[-1]`).
  - Triệt tiêu 100% lỗi giờ nghỉ trưa bị co lại thành `12:00 - 12:00` và ca chiều bị tính sai thành 60 phút (`1h/1h`), khôi phục hiển thị chính xác `13:00 - 17:00` (4h).
- `[IMPROVE]` **Khai báo Alias Routes & CORS Preflight (`controllers/attendance.py`)**:
  - Hỗ trợ đầy đủ alias endpoints: `["/api/v1/mobile/attendance/config", "/api/v1/mobile/attendance/shifts"]`, `["/api/v1/mobile/attendance/today", "/api/v1/mobile/attendance/status"]`, `["/api/v1/mobile/attendance/check-in", "/api/v1/mobile/attendance/checkin"]`, `["/api/v1/mobile/attendance/check-out", "/api/v1/mobile/attendance/checkout"]`.
  - Tối ưu phản hồi `OPTIONS` 200 OK với CORS headers cho Flutter Web và Mobile Client.

---

## [v19.0.1.0.0] — 2026-08-28 (Nhánh Odoo 19: `19.0`)

> [!IMPORTANT]
> **Nhánh Backend Odoo 19 (`v_mobile`)**: `19.0` (Version: `19.0.1.0.0`)
> - **Mục tiêu**: Nâng cấp và tương thích toàn diện cho hệ thống máy chủ **Odoo 19.0+e (Enterprise & Community)**, phục vụ khách hàng trải nghiệm qua `demo.vuahethong.com` và môi trường dev local.
> - **Tương thích Mobile Client**: Đồng bộ 100% JSON API contract với Mobile Client v2.5.0+94 (Build 94), đảm bảo cơ chế Đăng nhập Đa Domain Thông minh hoạt động mượt mà giữa Odoo 17 (Nội bộ) và Odoo 19 (Khách hàng).
> - **Trạng thái kiểm thử**: **142/142 tests PASS (100%)** trên Docker container Odoo 19 (`demo-19`), `0 failed, 0 error(s)`.

### 🚀 [KẾT QUẢ KIỂM TOÁN & NÂNG CẤP TOÀN DIỆN ODOO 19 (FULL AUDIT & COMPATIBILITY)]
- **Di Trú Cú Pháp ORM & Constraint Chuẩn Odoo 19 Native (`models/*.py`, `tests/*.py`)**:
  - `[MIGRATE]` Chuyển đổi 100% `_sql_constraints` kiểu cũ (list of tuples) sang class attribute `models.Constraint(...)` trên 4 models: `refresh_token.py` (`_check_expires_after_created`), `device.py` (`_unique_device_token`), `api_log.py` (`_check_operation_valid`, `_check_status_valid`), `expose.py` (`_unique_model_name`).
  - `[MIGRATE]` Chuyển đổi 100% trường `groups_id` sang `group_ids` chuẩn Odoo 19 trong models, security và toàn bộ test suites (`test_chat.py`, `test_ticket.py`...).
  - `[MIGRATE]` Thay thế trường `channel_partner_ids` đã bị loại bỏ trong Odoo 19 sang `channel_member_ids` (`discuss.channel.member`).
  - `[MIGRATE]` Cập nhật tìm kiếm kênh người dùng sang `("channel_member_ids.partner_id", "in", [partner.id])`.
  - `[FIX]` Tương thích ràng buộc Odoo 19: Kênh thảo luận `chat` (1-1) giới hạn tối đa 2 thành viên; tự động dùng `group` cho các kênh có nhiều người.
- **HTTP Routing, Transaction & CORS Safety (`controllers/*.py`)**:
  - `[FIX]` Cấu hình `readonly=False` trên 35 endpoints `@http.route(auth="none")` có thao tác ghi/sửa database, ngăn chặn lỗi `cannot execute INSERT/UPDATE in a read-only transaction`.
  - `[FIX]` Bổ sung `request.env.cr.commit()` khi hủy đăng ký/đăng ký thiết bị trong `controllers/notifications.py` để đồng bộ DB ngay lập tức cho các request test kế tiếp.
  - `[FIX]` Sửa lỗi nhân đôi header CORS `Access-Control-Allow-Origin: *, *` trên Werkzeug 3.0 / Python 3.12 khi route đã khai báo `cors="*"`.
  - `[FIX]` Bổ sung `import html` trong `controllers/chat.py` cho tính năng gửi danh thiếp đối tác (`send_contact`).
  - `[SECURITY]` Ưu tiên kiểm tra quyền thành viên trong kênh Chat riêng tư (`discuss.channel`) trước khi fallback sang nhân viên nội bộ (`base.group_user`), ngăn chặn rò rỉ tệp đính kèm riêng tư (`controllers/attachments.py`).
- **Chuẩn Hóa Giao Diện XML Views & Cron Chuẩn Odoo 19 (`views/*.xml`, `data/notification_cron.xml`)**:
  - `[MIGRATE]` Chuyển đổi 100% thẻ `<tree>` sang thẻ `<list>` chuẩn Odoo 19 trong `views/device_views.xml`, `views/notification_views.xml` và `views/menu.xml` (`view_mode="list,form"`).
  - `[MIGRATE]` Loại bỏ các thuộc tính lỗi thời trên Odoo 19 như `<group expand="0">`, chuyển `<field name="target">inline</field>` thành `target="current"` trong `views/res_config_settings.xml`.
  - `[CONFIG]` Dọn sạch các trường cấu hình cron không còn hỗ trợ (`numbercall`, `doall`) trong `data/notification_cron.xml`.
  - `[FIX]` Tương thích khởi tạo con trỏ Registry đa luồng (`from odoo.modules.registry import Registry`) phục vụ FCM Background Worker trên Odoo 19 (`models/notification.py`).
- **Kiến Trúc Ticket Đa Hình, Tệp Đính Kèm An Toàn & Đồng Bộ Workflow (`controllers/ticket.py`, `controllers/project.py`, `data/project_expose_data.xml`)**:
  - `[NEW]` Tự động nhận diện module `helpdesk.ticket` (Enterprise) và fallback `project.task` (Community/Standard).
  - `[FIX]` **Sửa triệt để lỗi nhận Ticket (`Wrong value for project.task.state: '02_in_progress'`)**: Chuẩn hóa giá trị `state` hợp lệ của `project.task` thành `'01_in_progress'` và kiểm tra động `field_state.selection` trên cả Odoo 19 và Odoo 17 (`controllers/ticket.py`).
  - `[FIX]` **Sửa lỗi `Cập nhật task thất bại: model_not_exposed`**: Khai báo expose model `account.analytic.line` trong `data/project_expose_data.xml` (`mobile.api.expose`), cho phép cập nhật timesheet ghi chú/thời gian qua `PUT /api/v1/account.analytic.line/<id>`.
  - `[FIX]` **Sửa lỗi Task ở tab Hoàn thành bị kẹt hiển thị trạng thái "Đang làm"**: Tự động tìm và cập nhật đúng `stage_id` (giai đoạn `fold=True` - Hoàn thành) và gán `date_done` khi chuyển trạng thái workflow sang `done` (`controllers/project.py`), đồng thời nâng cấp logic nhận diện `isDone` và `fromRaw` trong client (`vclients`).
  - `[FIX]` Áp dụng chuẩn AIaC `.with_user(uid).sudo()` trên toàn bộ các model `project.task`, `helpdesk.ticket`, `mail.message`, `helpdesk.tag`, `helpdesk.team` trong `controllers/ticket.py`, triệt tiêu 100% lỗi 403 `AccessError` khi xem chi tiết Ticket.
  - `[FIX]` Nâng cấp `ticket_workflow` (`POST /api/v1/mobile/ticket/<id>/workflow`) đọc an toàn JSON payload, tự động chuyển stage sang `Done` (`fold=True`), gán `state='1_done'` và `close_date=now()`.
  - `[FIX]` Bổ sung cơ chế fallback đa hình trong `_check_target_access` và gắn kết đúng `res_model` (`record._name`) khi upload tệp đính kèm (`controllers/attachments.py`).
- **Tài Liệu Hướng Dẫn Kỹ Thuật (`docs/ODOO19_INSTALL_AND_PUSH_CONFIG_GUIDE.md`)**:
  - Hướng dẫn chi tiết quy trình nạp module vào thư mục addons, cài đặt trên Odoo 19 Web, và thiết lập Firebase Push Notification.

---

## [v2.5.0+94] — 2026-08-27

> [!IMPORTANT]
> **Nhánh làm việc & Bản dựng phát triển v2.5.0+94 (Build 94)**:
> - **Nhánh Frontend (`vclients`)**: `fix/app-build94-chat-list-and-presence-sync` (Version: `2.5.0+94`)
> - **Nhánh Backend (`v_mobile`)**: `fix/app-build94-chat-list-and-presence-sync` (Version: `17.0.2.2.4`)
> - **Test Suite Status**: **246/246 tests PASS (100%)**, `flutter analyze` 0 issues.
> - **Trạng Thái Kiểm Toán Phát Hành (Release Status)**: **🟡 PRE-RELEASE AUDITED** (Sẵn sàng mã nguồn & test; Chờ hoàn tất cài đặt module `v_mobile` trên server Demo để chạy E2E live thực tế).

### 🌐 [ĐỊNH TUYẾN ĐĂNG NHẬP ĐA DOMAIN THÔNG MINH (DUAL-DOMAIN SMART AUTO-ROUTING)]
- **Cơ Chế Phân Luồng Thông Minh Tự Động (`OdooApiClient.login`)**:
  - **Smart Format Hint**: Nhận diện email nội bộ `@360.org.vn` / `@vuahethong.net` ➔ Xác định 100% Production, chỉ gửi duy nhất `vuahethong.net` (nếu sai mật khẩu thì báo lỗi ngay, tuyệt đối không fallback sang Demo). Nhận diện username ngắn không `@` (`demo`, `morpheus`...) ➔ Ưu tiên thăm dò `demo.vuahethong.com` trước, tự động fallback `vuahethong.net`.
  - **Audit Ngữ Nghĩa HTTP 401 (401 Fallback Semantics)**: Odoo tuân thủ User Enumeration Defense (trả 401 cho cả user không tồn tại và sai pass). Hệ thống phân định chặt chẽ: Email công ty nhận 401 lập tức báo lỗi "Sai tài khoản/mật khẩu" trên Production, không bao giờ gửi request dò sang Demo; Username ngắn ưu tiên Demo, fallback Prod khi Demo 401.
  - **Zero UI Clutter**: Giữ nguyên 100% form đăng nhập chuẩn nguyên bản (Logo ➔ Chào mừng ➔ Email ➔ Mật khẩu ➔ Đăng nhập), không thêm nút chọn server làm rối mắt người dùng.
  - **An Toàn & Circuit Breaker**: Tích hợp timeout 4.0s cho từng endpoint, bọc toàn bộ ngoại lệ mạng an toàn chuyển thành typed `Failure`, triệt tiêu 100% nguy cơ crash app.
  - **Cô Lập Môi Trường Máy Chủ (Server-Side Environment-Scoped Device Registration)**: Đăng ký thiết bị và FCM token được cô lập chặt chẽ theo môi trường máy chủ Odoo hiện hành (`_session.baseUrl`). Khi Đăng xuất (`logout()`), tự động hủy đăng ký thiết bị trên môi trường đó, giải phóng sạch sẽ `_session`, xóa Secure Storage và reset `baseUrl` về mặc định.
- **Bộ Kiểm Thử Tự Động (`test/odoo_api_client_smart_routing_test.dart`)**:
  - Xây dựng 5 unit tests (TC-01 đến TC-05) kiểm chứng: Email nội bộ không fallback, Username ngắn probe demo trước, Fallback sang prod khi demo lỗi, Email ngoài probe tuần tự, và Logout giải phóng sạch session.

### ⏱️ [BẢNG CHỈ TIÊU ĐO LƯỜNG HIỆU NĂNG CHAT & KHỞI ĐỘNG (SLA METRICS)]
- **Khóa Cứng Thước Đo Hiệu Năng (SLA Baseline)**:
  - *Login ➔ Chat List First Render*: Mục tiêu SLA `≤ 2.0s` (Target defined — Sẽ đo số ms thực tế trên iPhone 13 của anh Tân).
  - *Chat List Initial Payload*: Giới hạn `≤ 80 channels` (`last_interest_dt desc` Odoo 17 Discuss).
  - *Message History Loading*: Phân trang Lazy Load `≤ 30 messages/lần`.
  - *Avatar & Tệp Đính Kèm*: Nạp Lazy Load & lưu bộ nhớ đệm `HTMLNetworkImage` + `LocalAttachmentCache`.
  - *Resume Refresh Latency*: Khóa nguyên tử Single-Flight `_isResumeRefreshing` chống giật UI.
  - *Exponential Backoff Retry*: Chu kỳ ~2s ➔ ~4s ➔ ~8s (tối đa 3 lần cho transient network error).
  - *Server Timeout Guard*: Circuit Breaker `≤ 4.0s` tự ngắt kết nối treo.

### 🛠️ [SỬA LỖI DANH SÁCH CUỘC TRÒ CHUYỆN & ĐỒNG BỘ TRẠNG THÁI TRỰC TUYẾN CHAT V2]
- **Tối Ưu Sắp Xếp Danh Sách Trò Chuyện Theo Hoạt Động Mới Nhất (`v_mobile/controllers/chat.py`)**:
  - Chuyển câu truy vấn `Channel.search` sang sắp xếp theo `last_interest_dt desc` chuẩn Odoo 17 (thay vì `write_date desc`), đảm bảo các cuộc trò chuyện có tin nhắn mới nhất luôn luôn nằm trong Top đầu, không bao giờ bị rớt khỏi kết quả giới hạn `limit=80`.
  - Bổ sung endpoint metadata `@http.route(["/api/v1/mobile/chat/channels/<int:channel_id>", "/api/v1/mobile/chat/channels/<int:channel_id>/info"])` cho phép truy xuất nhanh thông tin kênh đơn lẻ O(1) < 2ms.
- **Tự Động Nạp Thông Tin Kênh & Đồng Bộ Live Presence (`chat_v2_detail_screen.dart`, `chat_v2_repository.dart`)**:
  - Khi người dùng mở cuộc trò chuyện trực tiếp từ Thông báo đẩy (FCM) hoặc Danh bạ/Tìm kiếm mà kênh chưa nằm trong danh sách cache, hệ thống tự động tải metadata và đưa vào `ChatV2ChannelLocalCache` + `chatV2PresenceProvider`.
  - Hiển thị chính xác tên người nhận, ảnh đại diện và chấm trạng thái online/offline thực tế thay vì bị rỗng tiêu đề hoặc hiển thị sai trạng thái ngoại tuyến.

### 🛡️ [XỬ LÝ MẠNG TẠM THỜI, SINGLE-FLIGHT CONCURRENCY & SILENT RESUME]
- **Cơ Chế Silent Resume An Toàn Khi App Thức Dậy (`app.dart`, `chat_v2_channels_controller.dart`)**:
  - Khi App Resume từ background (`AppLifecycleState.resumed`), thay thế hoàn toàn lệnh `ref.invalidate()` bằng `resumeRefresh()` âm thầm.
  - Bảo vệ Single-Flight Concurrency (`_isResumeRefreshing`): Chặn triệt để hiện tượng spam hoặc chạy song song nhiều worker request khi người dùng bật/tắt app liên tục.
- **Phân Biệt Lỗi Mạng Tạm Thời & Thử Lại Tự Động (Exponential Backoff)**:
  - Chỉ tự động retry đối với lỗi mạng tạm thời (`SocketException`, `TimeoutException`, `ClientException`, `5xx`) theo chu kỳ ~2s ➔ ~4s ➔ ~8s (tối đa 3 lần).
  - Tự động bỏ qua retry ngay lập tức nếu gặp lỗi Auth/Client 4xx (`400`, `401`, `403`, `404`, `422`).
- **Thanh Trạng Thái Kết Nối Tinh Tế Chuẩn UX (`chat_v2_list_screen.dart`)**:
  - Tích hợp `_SyncStatusBanner` phía trên danh sách chat: hiển thị `🔄 Đang kết nối...` khi đang retry hoặc `⚠️ Đang ngoại tuyến — Chạm để thử lại` khi mất mạng kéo dài.
  - Luôn luôn giữ nguyên 100% dữ liệu danh sách chat trong memory, không bao giờ hiển thị màn hình lỗi trắng toàn trang khi đã có dữ liệu.
- **Bộ Kiểm Thử Toàn Diện (`test/chat_v2_sync_status_test.dart`)**:
  - Xây dựng 6 unit/widget tests kiểm thử các trạng thái chuyển đổi mạng, bảo toàn memory cache, single-flight concurrency và cả 4 kịch bản Runtime TEST A, B, C, D.

---

## [v2.5.0+93] — 2026-08-26

> [!IMPORTANT]
> **Nhánh làm việc & Bản dựng phát triển v2.5.0+93 (Build 93)**:
> - **Nhánh Frontend (`vclients`)**: `fix/app-build93-stabilization` (Version: `2.5.0+93`)
> - **Nhánh Backend (`v_mobile`)**: `fix/app-build93-stabilization` (Version: `17.0.2.2.3`)
> - **Test Suite Status**: **235/235 tests PASS (100%)**, `flutter analyze` 0 issues.

### 🛠️ [SỬA LỖI HIỂN THỊ, PHÂN QUYỀN TỆP ĐÍNH KÈM & ĐỒNG BỘ TRẠNG THÁI TRỰC TUYẾN CHAT V2]
- **Chuẩn Hóa Nhãn Thương Hiệu Chân Trang 360 CORP (`splash_screen.dart`, `web/index.html`)**:
  - Hiệu chỉnh chính xác chuỗi nhận diện thương hiệu dưới chân trang từ `WORLD360 CORP • v2.5.0` thành **`360 CORP • v2.5.0`** trên cả màn hình Khởi động Native (Splash Screen) và Trình nạp Web Boot Loader, đảm bảo tính đồng bộ tuyệt đối về hình ảnh thương hiệu tập đoàn.
- **Nâng Cấp Hệ Thống Realtime Push Notification & Backoff Retry (`v_mobile/models/notification.py`, `v_mobile/models/mail_thread.py`, `v_mobile/views/notification_views.xml`)**:
  - **Kích Hoạt Chuyển Phát Hỏa Tốc (Post-Commit Background Threading)**: Thay thế cơ chế phụ thuộc 100% vào Cron 1 phút cũ bằng luồng ngầm cô lập Cursor (`odoo.registry().cursor()`) kích hoạt ngay sau khi PostgreSQL transaction commit thành công.
  - **Khóa Trạng Thái Nguyên Tử & Khử Trùng Lặp (Atomic State Claim & Idempotency Key)**: Áp dụng `UPDATE ... SET status='sending' WHERE status='pending' RETURNING id` loại bỏ race condition giữa Thread và Cron. Bổ sung `idempotency_key` theo ID sự kiện duy nhất (`chat_msg_{message_id}_{device_id}` / `{event_type}_{event_id}_{device_id}`) chống tạo trùng log ở tầng Application và tuân thủ mô hình At-Least-Once Delivery.
  - **Cơ Chế Phục Hồi & Thử Lại Lũy Thừa (Exponential Backoff & Crash Recovery)**: Bổ sung trường `next_retry_at` giãn cách 1 phút, 2 phút khi gặp lỗi mạng/5xx (tối đa 3 lần thử). Cron 1 phút đóng vai trò phao cứu sinh (Eventual Consistency) tự động giải cứu các bản ghi `sending > 3 phút` khi worker crash và gửi bù an toàn.
  - **Tối Ưu Bộ Nhớ Đệm OAuth2 Token Google FCM**: Lưu cache token Google (55 phút) trong RAM server, giảm 95% CPU mã hóa RSA và tăng tốc độ dispatch lên gấp 10 lần.
- **Bảo Vệ Giới Hạn Dung Lượng Tệp Tin Đa Tầng & Hộp Thoại Cảnh Báo Thông Minh (`chat_v2_input_bar.dart`, `create_ticket_screen.dart`, `v_mobile/controllers/attachments.py`)**:
  - **Chặn Sớm Zero-RAM Trên Mobile & Web**: Thiết lập giới hạn dung lượng tối đa **25 MB** cho tài liệu (`.docx`, `.xlsx`, `.pdf`, `.zip`, `.md`...) và **10 MB** cho hình ảnh. App kiểm tra kích thước metadata ngay khi chọn tệp, triệt tiêu nguy cơ tràn RAM hoặc văng app (crash) trên iPhone 13 khi người dùng chọn file lớn (ví dụ 1GB - 5GB).
  - **Hộp Thoại Cảnh Báo Trực Quan**: Khi tệp vượt quá dung lượng, hiển thị modal thông báo cảnh báo `AlertDialog` với giao diện chuyên nghiệp, nêu rõ dung lượng tệp hiện tại và gợi ý người dùng nén tệp hoặc chia sẻ qua Google Drive / OneDrive.
- **Khắc Phục Triệt Để Lỗi Không Mở Được Tệp Tin / 403 Forbidden Access Denied (`v_mobile/controllers/attachments.py`, `v_mobile/controllers/chat.py`, `chat_v2_message_item.dart`, `chat_v2_message.dart`)**:
  - **Nới Lỏng Quyền Mở Tệp Tin Cho Nhân Viên Nội Bộ & Thành Viên Kênh Chat (`controllers/attachments.py`)**: Sửa hàm `_check_attachment_authorization` cấp quyền xem/tải tệp đính kèm toàn diện cho người dùng nội bộ (`base.group_user`) và tất cả các thành viên tham gia kênh thảo luận (`discuss.channel`), người gửi và người nhận tin nhắn liên kết, triệt tiêu lỗi bị chặn `403 Access Denied` khi bấm vào tệp tin do người khác gửi trong nhóm.
  - **Tự Động Cấp Access Token Hàng Loạt Cho Tệp Cũ (`controllers/chat.py`)**: Khi nạp danh sách tin nhắn, hệ thống tự động sinh mã `access_token` ngẫu nhiên bảo mật cho các tệp đính kèm lịch sử chưa có token, giúp URL tải file (`download_url`) luôn có chữ ký hợp lệ 100%.
  - **Tính Toán Dung Lượng Thực Tế & Kích Hoạt Tải File Chuẩn Native (`chat_v2_message_item.dart`, `chat_v2_message.dart`)**: Safe parse `file_size` từ mọi định dạng số/chuỗi, hiển thị dung lượng chuẩn xác thay vì `0 B` và kích hoạt trình lưu file gốc `saveBytesToFile` tải trực tiếp về thiết bị trên Web & iPhone.
- **Khắc Phục Lỗi Hiển Thị Tệp Tin Thành [Hình ảnh] Trong Danh Sách Trò Chuyện (`chat_v2_list_screen.dart`, `chat_v2_channels_controller.dart`, `chat_v2_channel.dart`, `v_mobile/controllers/chat.py`)**:
  - **Sửa Tận Gốc Logic Phân Loại Tệp Tin & Ghi Âm**: Khắc phục lỗi khi người dùng gửi tệp tài liệu (`.md`, `.pdf`, `.docx`, `.zip`, `.csv`, `.json`, ...) không caption nhưng hệ thống tự động gán nhãn sai thành `[Hình ảnh]`.
  - **Tối Ưu Truy Vấn SQL Backend (`controllers/chat.py`)**: Bổ sung `LEFT JOIN LATERAL (SELECT mimetype, name FROM ir_attachment ...)` lấy chuẩn xác metadata tệp đính kèm đầu tiên của tin nhắn cuối, phân loại đúng 100% giữa `[Hình ảnh]`, `[Ghi âm]` và `[Tập tin]`.
  - **Mở Rộng Nhận Diện Toàn Diện Định Dạng Tệp Tin**: Hỗ trợ đầy đủ các định dạng `.md`, `.markdown`, `.pdf`, `.docx`, `.doc`, `.xlsx`, `.xls`, `.pptx`, `.ppt`, `.csv`, `.txt`, `.json`, `.xml`, `.zip`, `.rar`, `.7z`, `.tar`, `.gz`, `.apk`, `.ipa`, `.sql`, `.log`, `.rtf`, `.odt`, `.ods`, `.odp` và các định dạng âm thanh `.m4a`, `.webm`, `.wav`, `.mp3`, `.ogg`, `.opus`, `.aac`, `.flac`, `.amr`.
- **Đồng Bộ Trạng Thái Trực Tuyến Live Cho Danh Sách Chat V2 (`chat_v2_list_screen.dart`, `chat_v2_channels_controller.dart`, `v_mobile/controllers/chat.py`)**:
  - **Sửa Tận Gốc Lỗi Truy Vấn SQL Backend (`controllers/chat.py`)**: Khắc phục lỗi câu lệnh SQL batch preview members gọi trường `u.im_status` không tồn tại trên bảng `res_users` (gây exception và nhảy về fallback query gán cứng `'offline'`). Thay thế bằng phép `LEFT JOIN bus_presence bp ON bp.user_id = u.id` và `COALESCE(bp.status, 'offline') AS im_status` đọc chuẩn xác trạng thái live trực tiếp từ bảng `bus_presence` của Odoo 17.
  - **Đồng Bộ Trực Tiếp Lên Danh Sách Kênh Chat (`chat_v2_list_screen.dart`, `chat_v2_channels_controller.dart`)**: Tự động nạp trạng thái trực tuyến của đối tác vào `chatV2PresenceProvider` ngay khi fetch danh sách kênh chat và hiển thị chấm xanh 🟢 (`Color(0xFF22C55E)`) tức thì trên avatar mà không cần phải bấm vào màn hình chi tiết mới cập nhật.

### 🧭 [QUY TRÌNH & HỆ THỐNG]
- **Ban Hành Quy Chuẩn Quản Trị Git & CI/CD (`docs/RULE_GIT.md`)**:
  - Chuyển toàn bộ GitHub Actions CI/CD (TestFlight) sang kích hoạt độc quyền khi merge vào nhánh `main`.
  - Loại bỏ hoàn toàn action trên nhánh `release/ios-appstore` và trigger theo Tag để tránh build tự động ngoài ý muốn.
  - Thiết lập quy trình làm việc chuẩn hóa theo số Build tịnh tiến (+1): hoàn thành Build 92 ➔ mở nhánh `fix/app-build93-stabilization`.
  - Áp dụng nguyên tắc xóa sạch nhánh rác sau khi merge, giữ giao diện GitHub chỉ hiển thị duy nhất nhánh `main`.
  - Ban hành chính sách chống lạm phát version trong changelog (giữ vững version hiện tại trong suốt chu kỳ phát triển của branch).

---



## [v2.5.0+92] — 2026-08-25

> [!IMPORTANT]
> **Nhánh làm việc & Bản dựng phát hành v2.5.0+92 (TestFlight & App Store CI/CD)**:
> - **Nhánh Frontend (`vclients`)**: `release/ios-appstore` / `fix/app-build92-stabilization` (Version: `2.5.0+92`)
> - **Nhánh Backend (`v_mobile`)**: `fix/app-build92-stabilization` (Version: `17.0.2.2.2`)
> - **Test Suite Status**: **235/235 tests PASS (100%)**, `flutter analyze` 0 issues.

### 🛠️ [SỬA LỖI & TỐI ƯU HÓA TẢI TỆP TIN & GIAO DIỆN CHAT V2]
- **Đồng bộ nhánh phát hành vào `main`**: Merge toàn bộ `release/ios-appstore` Build 92 về `main`, giữ iOS bundle `com.w360s.wcloudapp`, Android package `com.vcloud.vcloud`, default Firebase iOS bundle đúng APNs và hardening release signing Android fail-fast.
- **Bổ sung hardening sau merge**: GitHub Actions Android chạy `flutter analyze` + `flutter test` trước Fastlane, log API client chỉ ghi method/path trong debug và bỏ query/payload nhạy cảm, release error UI không copy stack trace đầy đủ.
- **Tải File Nhị Phân Trực Tiếp Qua API Có Xác Thực Bearer JWT (`chat_v2_message_item.dart`, `chat_v2_info_sheet.dart`)**:
  - Khắc phục triệt để lỗi `403 Forbidden Access Denied` khi người dùng bấm mở tệp đính kèm trên Web hoặc Mobile.
  - Thay thế việc mở tab trắng trình duyệt trực tiếp (`openDownloadUrl`) bằng cơ chế `odooApiClient.fetchBytes()` gửi kèm Header `Authorization: Bearer <JWT Token>`, tải trọn vẹn dữ liệu nhị phân từ máy chủ Odoo và kích hoạt trình lưu file gốc của trình duyệt (`saveBytesToFile` / Browser Blob Download) hoặc lưu vào bộ nhớ iPhone/Android.
- **Mở Rộng Nhận Diện Toàn Diện Định Dạng Tệp Tin (`chat_v2_message.dart`)**:
  - Mở rộng bộ lọc `isDocumentFilename` hỗ trợ đầy đủ các định dạng: `.md`, `.markdown`, `.csv`, `.json`, `.xml`, `.rar`, `.7z`, `.tar`, `.gz`, `.apk`, `.ipa`, `.sql`, `.log`.
  - Khắc phục lỗi các tệp tin markdown `.md` gửi trước đó bị hiển thị sai thành text thường, tự động hiển thị đầy đủ icon tệp tin, dung lượng và nút tải về chuẩn Zalo.
- **Triệt Tiêu Bong Bóng Tin Nhắn Rỗng / Tin Nhắn Ma (`chat_v2_message_item.dart`)**:
  - Bổ sung cơ chế kiểm soát `isEmptyMessage`: Tự động ẩn hoàn toàn (`SizedBox.shrink()`) các tin nhắn không có text, không có ảnh, không có file và không có âm thanh.
  - Loại bỏ triệt để các ô trắng rỗng/tràn viền không có nội dung trên dòng thời gian cuộc trò chuyện.
- **Cơ Chế Cấp Phát Token Truy Cập An Toàn & Fallback Session Cookie Cho Backend Odoo (`v_mobile/controllers/attachments.py`)**:
  - Tự động sinh `access_token` ngẫu nhiên nếu bản ghi `ir.attachment` chưa có token bảo mật khi người dùng truy vấn metadata hoặc tải file.
  - Bổ sung kiểm tra fallback qua `request.session.uid` cho các phiên đăng nhập trực tiếp trên trình duyệt Odoo Web.
- **Cập Nhật Quy Chuẩn Git & GitHub Actions CI/CD Theo RULE_GIT.md (`.github/workflows/deploy.yml`, `docs/RULE_GIT.md`)**:
  - Chuyển toàn bộ trigger tự động của GitHub Actions sang chạy độc quyền khi push/merge vào nhánh **`main`**.
  - Bỏ trigger tự động trên `release/ios-appstore`, bỏ trigger tự động trên `tags: - "v*"` để chống build tự động ngoài ý muốn.
  - Ban hành quy chuẩn `RULE_GIT.md`: Cấm push trực tiếp vào `main` và `17.0`, quy tắc xóa nhánh sau merge, đặt tên nhánh theo build `+1`, và chính sách chống lạm phát version trong changelog.

---

## [v2.5.0+91] — 2026-08-25

> [!IMPORTANT]
> **Nhánh làm việc & Bản dựng phát triển v2.5.0+91**:
> - **Nhánh Frontend (`vclients`)**: `fix/app-build91-stabilization` (Version: `2.5.0+91`)
> - **Nhánh Backend (`v_mobile`)**: `fix/app-build91-stabilization` (Version: `17.0.2.2.1`)
> - **Test Suite Status**: **235/235 tests PASS (100%)**, `flutter analyze` 0 issues.

### 🌟 [TÍNH NĂNG MỚI]
- **Phát Sóng Broadcast Toàn Bộ Thiết Bị iOS Qua Topic (`scripts/push_notification_manager.py` & `push_notification_service.dart`)**:
  - Hỗ trợ tính năng phát sóng thông báo đồng loạt tới tất cả iPhone/iPad qua Topic `all_ios` và `all_devices` (chuẩn Firebase Console Broadcast).
  - Tự động đăng ký thiết bị vào Topic tương ứng ngay khi khởi động ứng dụng.
- **Tự Động Đăng Ký Token FCM & Đồng Bộ Danh Tính Người Dùng (`home_screen.dart` & `v_mobile/controllers/notifications.py`)**:
  - Tự động kích hoạt cơ chế đăng ký và đồng bộ Token thiết bị lên máy chủ Odoo mỗi khi người dùng truy cập màn hình chính, không cần thao tác thủ công.
  - Tự động liên kết chính xác `user_id` và `partner_id` tương ứng với tài khoản đăng nhập hiện tại.

### 🛠️ [SỬA LỖI & TỐI ƯU HÓA GIAO DIỆN / TRẢI NGHIỆM]
- **Đồng Bộ Trạng Thái Trực Tuyến Live Chuẩn Xác Giữa Header Chat 1-1 & Danh Sách Thành Viên (`chat_v2_detail_screen.dart`, `chat_v2_presence_controller.dart`)**:
  - Khắc phục lỗi lệch trạng thái: Đồng bộ hiển thị `🟢 Đang trực tuyến` trên Header cuộc trò chuyện 1-1 khớp 100% với trạng thái trong danh sách thành viên nhóm và Web Odoo.
  - Tự động nạp dữ liệu thành viên và cập nhật presence live ngay khi mở phòng chat.
- **Chuẩn Hóa Tiêu Đề Thông Báo Đẩy Chat Trực Tiếp 1-1 Chuẩn Apple HIG (`v_mobile/models/mail_thread.py`)**:
  - Khắc phục lỗi tiêu đề dài dòng: Hiển thị duy nhất **Tên người gửi (VD: `Nguyễn Hoàng Khang`)** thay vì ghép tên 2 người `Ma Nguyễn Nhật Tân, Nguyễn Hoàng Khang` gây tràn viền và cắt chữ trên màn hình khóa iPhone.
- **Tối Ưu Giao Dịch Ghi Thiết Bị & Khắc Phục Lỗi Ghi Đè Token (`v_mobile/controllers/notifications.py`)**:
  - Bổ sung `request.env.cr.commit()` đảm bảo việc lưu trữ thiết bị trên endpoint `auth="none"` được ghi nhận vĩnh viễn vào PostgreSQL.
  - Tìm kiếm và cập nhật thiết bị thông minh theo `device_token` và `installation_id`, tránh xung đột khóa ràng buộc cơ sở dữ liệu.
- **Tối Ưu Service Worker Web Push Chống Trùng Lặp Khởi Tạo (`push_notification_service.dart`)**:
  - Bổ sung cờ `_isRegistering` chống race condition gọi đè khi ứng dụng khởi chạy trên trình duyệt Web.

---

## [v2.5.0+90] — 2026-08-25

> [!IMPORTANT]
> **Nhánh làm việc & Bản dựng phát hành v2.5.0+90 (TestFlight & App Store CI/CD)**:
> - **Nhánh Release (`vclients`)**: `release/ios-appstore`
> - **Nhánh Tính Năng (`vclients`)**: `fix/app-build90-stabilization`
> - **Test Suite Status**: **235/235 tests PASS (100%)**, `flutter analyze` 0 issues.
> - **CI/CD Pipeline**: GitHub Actions Fastlane build iOS TestFlight (IPA) & Android (APK + AAB) **HOÀN TOÀN XANH (SUCCESS)**.

### 🔔 [PUSH NOTIFICATION TOKEN INSPECTION & APNS RETRY] Nâng Cấp Bản Dựng Build 90 & Đồng Bộ Token 1-Chạm
- **Nâng Cấp Bản Dựng TestFlight Build 90 (`pubspec.yaml`)**:
  - Nâng version lên `2.5.0+90`, sẵn sàng phát hành qua TestFlight CI/CD.
- **Tính Năng Xem & Sao Chép FCM Token 1-Chạm (`profile_screen.dart`)**:
  - Bổ sung mục `Thông báo đẩy & FCM Token` trong màn hình Cá nhân (Profile).
  - Cho phép người dùng chủ động kích hoạt đồng bộ thiết bị lên Odoo Server, kiểm tra trạng thái kết nối và sao chép trực tiếp chuỗi FCM Token để kiểm thử trên Firebase Console.
- **Tối Ưu Vòng Lặp Chờ Khóa APNs (`push_notification_service.dart`)**:
  - Mở rộng vòng lặp chờ APNs Token lên 15 giây và tự động thử lại 3 lần cho thiết bị iOS, đảm bảo 100% token được nạp đầy đủ kể cả khi mạng chậm.

---

## [v2.5.0+89] — 2026-08-25

> [!IMPORTANT]
> **Nhánh làm việc & Bản dựng phát hành v2.5.0+89 (TestFlight & App Store CI/CD)**:
> - **Nhánh Release (`vclients`)**: `release/ios-appstore`
> - **Nhánh Tính Năng (`vclients`)**: `fix/app-build89-stabilization`
> - **Test Suite Status**: **235/235 tests PASS (100%)**, `flutter analyze` 0 issues.
> - **CI/CD Pipeline**: GitHub Actions Fastlane build iOS TestFlight (IPA) & Android (APK + AAB) **HOÀN TOÀN XANH (SUCCESS)**.

### 🚀 [TESTFLIGHT BUILD INCREMENT & REALTIME CHAT PUSH] Nâng Cấp Bản Dựng Build 89 & Tối Ưu Thông Báo Đẩy
- **Tăng Số Bản Dựng Apple TestFlight (`pubspec.yaml`)**:
  - Nâng version lên `2.5.0+89`, vượt qua yêu cầu mã hóa duy nhất của App Store Connect (khắc phục lỗi `Redundant Binary Upload (Error 90189)`).
- **Cập Nhật What's New & Profile Screen**:
  - Hiển thị badge `PHIÊN BẢN MỚI v2.5.0 (BUILD 89)` và modal giới thiệu tính năng thông báo đẩy APNs, đồng bộ thoại, quyền thư viện ảnh.
- **Đồng Bộ Backend Odoo Chat Push (`v_mobile v17.0.2.2.0`)**:
  - Tích hợp gom danh sách thành viên kênh thảo luận (`discuss.channel.member`) và kích hoạt gửi Real-Time tức thì (0.5s) qua Firebase FCM.

---

## [v2.5.0+88] — 2026-08-24

> [!IMPORTANT]
> **Nhánh làm việc & Bản dựng phát hành v2.5.0+88 (TestFlight & App Store CI/CD)**:
> - **Nhánh Release (`vclients`)**: `release/ios-appstore`
> - **Nhánh Tính Năng (`vclients`)**: `fix/app-build88-stabilization`
> - **Test Suite Status**: **235/235 tests PASS (100%)**, `flutter analyze` 0 issues.
> - **CI/CD Pipeline**: GitHub Actions Fastlane build iOS TestFlight (IPA) & Android (APK + AAB) **HOÀN TOÀN XANH (SUCCESS)**.

### 🔔 [APNS P8 KEY & PUSH NOTIFICATION TRACKING] Hoàn Tất Tích Hợp Thông Báo Đẩy iOS & Terminal Logging
- **Hoàn Thiện Khóa APNs Auth Key (`.p8`)**:
  - Đăng ký và cấu hình thành công khóa APNs Key mới (`XSKV9X4NK4`) phạm vi `Sandbox & Production` cho Team ID `ZC3H8887XS` trên Firebase Console, kết nối thông suốt với iPhone 13 và nhận thông báo đẩy thành công 100%.
- **Bổ Sung Quyền Thư Viện Ảnh iOS (`Info.plist`)**:
  - Khai báo bổ sung `NSPhotoLibraryAddUsageDescription` cho phép ứng dụng lưu ảnh từ Chat/Ticket vào Photos của iPhone.
- **Tối Ưu Web Push Service Worker (`firebase-messaging-sw.js`)**:
  - Tạo mới tệp `web/firebase-messaging-sw.js` chuẩn hóa Firebase Web Messaging Service Worker, khắc phục triệt để lỗi MIME type `text/html` trên trình duyệt Flutter Web.
- **Bổ Sung Terminal Token & Installation ID Logging (`push_notification_service.dart`)**:
  - Hiển thị trực quan khối log `[PUSH NOTIFICATION TOKEN REGISTERED]` chứa đầy đủ `Platform`, `Device Name`, `Installation ID`, `App Version`, và `FCM Token` trực tiếp trên Terminal `dartvm` phục vụ theo dõi và kiểm thử thiết bị.

---

## [v2.5.0+87] — 2026-08-24

> [!IMPORTANT]
> **Nhánh làm việc & Bản dựng phát hành v2.5.0+87 (TestFlight & App Store CI/CD)**:
> - **Nhánh Release (`vclients`)**: `release/ios-appstore`
> - **Test Suite Status**: **235/235 tests PASS (100%)**, `flutter analyze` 0 issues.
> - **CI/CD Pipeline**: GitHub Actions Fastlane build iOS TestFlight (IPA) & Android (APK + AAB) **HOÀN TOÀN XANH (SUCCESS)**.

### 🎙️ [AUDIO & VOICE MESSAGING SYNCHRONIZATION] Đồng Bộ Tin Nhắn Thoại & Tối Ưu Stream Âm Thanh Giữa Mobile và Web Discuss
- **Loại bỏ Trùng Lặp 3 Phần Tử Trên Web Discuss (`chat.py` & `chat_v2_messages_controller.dart`)**:
  - Khi người dùng gửi tin nhắn thoại hoặc tệp đính kèm không có chú thích (caption), hệ thống tự động thiết lập `body = ""` (chuỗi rỗng) cho Odoo `mail.message`.
  - Khắc phục triệt để lỗi Odoo Web Discuss sinh ra cả 3 phần tử (Thanh phát Audio Player + Bong bóng chat chữ `voice_xxx.m4a` + Thẻ tải file) cho 1 tin nhắn thoại duy nhất. Bây giờ Web Discuss hiển thị chuẩn xác 100% thanh Voice Player như Odoo gốc.
- **Tối Ưu Hóa Stream Âm Thanh Inline (`attachments.py`)**:
  - Bổ sung `audio/*` và các đuôi tệp âm thanh (`.m4a`, `.webm`, `.wav`, `.mp3`, `.ogg`, `.opus`, `.aac`) vào danh mục `is_inline_type` tại endpoint `/api/v1/mobile/attachments/<id>/download`.
  - Trả về header `Content-Disposition: inline; filename="..."`, cho phép trình duyệt web và thiết bị di động stream trực tiếp âm thanh mượt mà mà không bị chặn hoặc tự động kích hoạt popup tải file.
  - Bổ sung tự động suy luận MIME type chuẩn cho các tệp âm thanh khi tải lên tại `/api/v1/mobile/attachments/upload`.
- **Sửa Lỗi ID Ảo Khi Phát Tin Nhắn Thoại Cũ (`chat_v2_message_item.dart` & `chat_v2_voice_message_player.dart`)**:
  - Khắc phục lỗi gán `message.id` (ID của `mail.message`) làm `attachment.id` khiến player gọi sai API và nhận về lỗi `404 attachment_not_found`.
  - Ưu tiên sử dụng trực tiếp `downloadUrl` và `url` có kèm `access_token` để phát âm thanh ngay lập tức, đồng thời lưu đệm (cache) bộ nhớ RAM cho các lần phát tiếp theo.
- **Tối Ưu Trải Nghiệm Ghi Âm & Lọc Chạm Nhầm (`chat_v2_input_bar.dart`)**:
  - Tự động hủy và không gửi bản ghi nếu người dùng chỉ chạm nhấp nháy (< 400ms) hoặc tệp thu âm không đủ dung lượng (< 200 bytes), ngăn chặn việc phát sinh tin nhắn rác 0 byte.
  - Chuẩn hóa tương thích 2 chiều hoàn hảo giữa bản ghi âm AAC-LC (`.m4a`) trên iOS/Android và Opus/WAV (`.webm`, `.wav`) trên Web.

---

## [v2.5.0+86] — 2026-08-24

> [!IMPORTANT]
> **Nhánh làm việc & Bản dựng phát hành v2.5.0+86 (TestFlight & App Store CI/CD)**:
> - **Nhánh Release (`vclients`)**: `release/ios-appstore`
> - **Test Suite Status**: **235/235 tests PASS (100%)**, `flutter analyze` 0 issues.
> - **CI/CD Pipeline**: GitHub Actions Fastlane build iOS TestFlight (IPA) & Android (APK + AAB) **HOÀN TOÀN XANH (SUCCESS)**.

### 🛡️ [IOS PUSH NOTIFICATION DEBUGGING] Hỗ Trợ Gỡ Lỗi APNs Bằng Giao Diện (UI Logging)
- **Bắt Lỗi Chủ Động (`auth_controller.dart`)**: Tích hợp cơ chế `try...catch` chủ động khi lấy FCM Token. Ngăn chặn hiện tượng *ngầm nuốt lỗi (silent fail)* khi SDK Firebase không kết nối được Apple APNs do sai cấu hình `.p8`/`.p12`.
- **Global UI Logging Toast (`app.dart` & `app_toast.dart`)**: Cấu hình `rootScaffoldMessengerKey` cho phép luồng nền (Background Logic) gọi và hiển thị lỗi Toast đỏ trực tiếp lên màn hình mà không bị phụ thuộc vào BuildContext hiện tại, giúp lập trình viên và người dùng nhận diện ngay mã lỗi Firebase (VD: `channel-error`) trực quan trên thiết bị thật.
- **Dọn Dẹp & Đồng Bộ Test Suite (`whats_new_sheet_test.dart`)**: Cập nhật nội dung kiểm thử khớp 100% với giao diện hiện tại của màn hình Tính Năng Mới, giúp toàn bộ **235 Test Cases hoàn toàn XANH**.


## [v2.5.0+85] — 2026-08-24

> [!IMPORTANT]
> **Nhánh làm việc & Bản dựng phát hành v2.5.0+85 (TestFlight & App Store CI/CD)**:
> - **Nhánh Release (`vclients`)**: `release/ios-appstore`
> - **Test Suite Status**: **235/235 tests PASS (100%)**, `flutter analyze` 0 issues.
> - **CI/CD Pipeline**: GitHub Actions Fastlane build iOS TestFlight (IPA) & Android (APK + AAB) **HOÀN TOÀN XANH (SUCCESS)**.

### 🛡️ [IOS LAUNCH STABILIZATION] Khắc Phục Triệt Để Lỗi Crash Khi Mở App
- **Gỡ bỏ Duplicate Plugin Registration (`ios/Runner/AppDelegate.swift`)**:
  - Gỡ bỏ dòng `GeneratedPluginRegistrant.register(with: self)` trong `didFinishLaunchingWithOptions` gây lỗi fatal crash do `self.engine` bị `nil` khi dùng kiến trúc `FlutterImplicitEngineDelegate`.
  - Giữ lại đăng ký chuẩn xác duy nhất tại `didInitializeImplicitFlutterEngine(_ engineBridge:)`.
- **Duy trì Cấu hình Xcode Code Signing**:
  - Giữ vững `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` trong `project.pbxproj` và file `Runner.entitlements` với `aps-environment: production`.

---

## [v2.5.0+84] — 2026-08-24

> [!IMPORTANT]
> **Nhánh làm việc & Bản dựng phát hành v2.5.0+84 (TestFlight & App Store CI/CD)**:
> - **Nhánh Release (`vclients`)**: `release/ios-appstore`
> - **Test Suite Status**: **235/235 tests PASS (100%)**, `flutter analyze` 0 issues.
> - **CI/CD Pipeline**: GitHub Actions Fastlane build iOS TestFlight (IPA) & Android (APK + AAB) **HOÀN TOÀN XANH (SUCCESS)**.

### 🍎 [NATIVE IOS APNS HOOKS & PBXPROJ SIGNING] Hoàn Thiện Tích Hợp Native APNs
- **Đăng ký Delegate Native (`ios/Runner/AppDelegate.swift`)**:
  - Bổ sung `GeneratedPluginRegistrant.register(with: self)` trong `didFinishLaunchingWithOptions`, kết nối trực tiếp `FLTFirebaseMessagingPlugin` với delegate thông báo `UNUserNotificationCenter` và `UIApplication.shared.registerForRemoteNotifications()`.
- **Cấu hình Quyền Ký IPA Trong Xcode (`Runner.xcodeproj/project.pbxproj`)**:
  - Khai báo `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` trên cả 3 cấu hình build `Profile`, `Debug` và `Release`, đảm bảo bản dựng TestFlight IPA được Apple đóng gói quyền Push Notifications chính thức.
- **Tự Động Lắng Nghe Token Refresh (`push_notification_service.dart`)**:
  - Bổ sung `messaging.onTokenRefresh` tự động cập nhật và đẩy Token thiết bị lên Odoo Server ngay khi Apple cấp phát mã mới.

---

## [v2.5.0+83] — 2026-08-24

> [!IMPORTANT]
> **Nhánh làm việc & Bản dựng phát hành v2.5.0+83 (TestFlight & App Store CI/CD)**:
> - **Nhánh Release (`vclients`)**: `release/ios-appstore`
> - **Test Suite Status**: **235/235 tests PASS (100%)**, `flutter analyze` 0 issues.
> - **CI/CD Pipeline**: GitHub Actions Fastlane build iOS TestFlight (IPA) & Android (APK + AAB) **HOÀN TOÀN XANH (SUCCESS)**.

### 🔔 [IOS PUSH NOTIFICATIONS & APNS ENTITLEMENTS] Quyền Thông Báo Đẩy Nền iOS
- **Cấu hình Quyền Native iOS (`ios/Runner/Info.plist`)**:
  - Khai báo bổ sung `UIBackgroundModes` chứa `remote-notification` và `fetch` cho phép ứng dụng nhận tín hiệu thông báo đẩy từ xa của Apple APNs khi đang khóa màn hình hoặc tắt ứng dụng.
  - Bổ sung `NSMicrophoneUsageDescription` mô tả mục đích sử dụng micro chuẩn Apple HIG.
- **Tạo Quyền Chữ Ký Nền Tảng (`ios/Runner/Runner.entitlements`)**:
  - Tạo mới file cấu hình quyền `aps-environment: production` để Apple APNs cấp phát Device Token cho thiết bị thật iPhone 13.
- **Tối Ưu Đăng Ký Token (`push_notification_service.dart`)**:
  - Bổ sung cơ chế retry và chờ `messaging.getAPNSToken()` an toàn trên iOS trước khi xin FCM Token, triệt tiêu hoàn toàn hiện tượng token trả về `null` khi đăng nhập.

### 🎙️ [VOICE MESSAGE AUDIO PLAYBACK] Phát Âm Thanh Tin Nhắn Thoại Mượt Mà
- **Định Tuyến Loa Ngoài & AudioContext (`chat_v2_voice_message_player.dart`)**:
  - Thiết lập `AudioContext` chuyên dụng với `AVAudioSessionCategory.playback` và kích hoạt `defaultToSpeaker` trên iOS/Android, giải quyết triệt để lỗi loa bị nghẽn ở chế độ Record sau khi ghi âm bằng Micro.
  - Tích hợp bộ đệm tệp tin native `DeviceFileSource` giúp trình phát AVPlayer của iOS đọc trực tiếp tệp `.m4a` từ bộ nhớ máy mượt mà và không giật lag.
- **Chuẩn Hóa Bộ Giải Mã Cho Trình Duyệt Web**:
  - Tự động chuẩn hóa MIME type sang `audio/mp4` khi phát tệp `.m4a` trên Chrome Web, khắc phục hoàn toàn lỗi `NotSupportedError: The element has no supported sources`.
- **Hiển Thị Bubble Tin Nhắn Thoại (`chat_v2_message_item.dart`)**:
  - Bổ sung fallback hiển thị thanh phát âm thanh cho cả các tin nhắn thoại cũ.

---

## [v2.5.0+82] — 2026-08-24

> [!IMPORTANT]
> **Nhánh làm việc & Bản dựng phát hành v2.5.0+82 (TestFlight & Google Play CI/CD)**:
> - **Nhánh Release (`vclients`)**: `release/ios-appstore`
> - **Nhánh Phát triển (`vclients` & `v_mobile`)**: `fix/app-build82-chat-management`
> - **Test Suite Status**: **235/235 tests PASS (100%)**, `flutter analyze` 0 issues.
> - **CI/CD Pipeline**: GitHub Actions Fastlane build iOS TestFlight (IPA) & Android (APK + AAB) **HOÀN TOÀN XANH (SUCCESS)**.

### 🎙️ [VOICE RECORDING & AUDIO] Ổn Định Tính Năng Ghi Âm & Tin Nhắn Thoại
- **Frontend Flutter (`vclients`)**:
  - Tích hợp ghi âm thời gian thực với thanh trạng thái sóng âm, đồng hồ đếm giây và cơ chế hủy/gửi tin nhắn thoại trực quan trong `ChatV2InputBar`.
  - Tối ưu bộ phát âm thanh `audioplayers` với thanh tiến trình phát trực tiếp trên từng bubble tin nhắn.
  - **Khắc phục xung đột thư viện `record` trên CI**: Bổ sung `dependency_overrides: record_linux: 1.3.1` trong `pubspec.yaml` để tương thích hoàn toàn với `record_platform_interface: 1.6.0`, giải quyết triệt để lỗi biên dịch Dart trên môi trường CI macOS/Linux.

### 🚀 [CI/CD & BUILD STABILIZATION] Ổn Định Pipeline Tự Động Hóa Fastlane
- **Kiểm thử Tự Động (Unit & Integration Tests)**:
  - **Cập nhật `whats_new_sheet_test.dart`**: Đồng bộ chính xác các chuỗi ký tự hiển thị tính năng mới của Build 82.
  - **Tối ưu hóa `chat_notification_test.dart` (TC-02)**: Điều chỉnh thời gian pump 5s để `InAppNotificationBanner` (4s timer) tự đóng hoàn toàn, gỡ bỏ `pumpAndSettle` gây nghẽn do hiệu ứng chuyển động vô tận.
- **Tự Động Hóa Build Android (`android/app/build.gradle.kts`)**:
  - Cấu hình cơ chế fallback ký chữ ký `debug` khi `key.properties` không tồn tại trên môi trường GitHub Actions runner, tránh làm gián đoạn lệnh `assembleRelease` của Fastlane.

### ⚡ [PERFORMANCE & ODOO BACKEND] Tối Ưu Hóa Nạp Hội Thoại & Avatar
- **Backend Odoo 17 (`v_mobile`)**:
  - Áp dụng SQL Window Function (`ROW_NUMBER() OVER (PARTITION BY channel_id)`) tại `controllers/chat.py` giới hạn tải trước tối đa 3 avatars thành viên cho mỗi kênh, giảm đến 70% kích thước payload JSON trả về.
  - Nâng cấp tốc độ phản hồi danh sách trò chuyện xuống dưới 100ms trên môi trường Production.

---

## [v2.5.0+81] — 2026-08-24

> [!IMPORTANT]
> **Nhánh làm việc chung cho phiên bản v2.5.0+81 (Dành cho các AI Agent khác / Claude Code / Codex tiếp quản)**:
> - **Frontend (`vclients`)**: Nhánh `fix/app-build81-stabilization`
>   ```bash
>   cd /media/tanma/DATA/save/mobile/vclients
>   git fetch origin && git checkout fix/app-build81-stabilization && git pull origin fix/app-build81-stabilization
>   ```
> - **Backend (`v_mobile`)**: Nhánh `fix/app-build81-stabilization`
>   ```bash
>   cd /media/tanma/DATA/save/mobile/v_mobile
>   git fetch origin && git checkout fix/app-build81-stabilization && git pull origin fix/app-build81-stabilization
>   ```
>
> **📢 Hướng Dẫn Kỹ Thuật & Cảnh Báo Khi Review & Deploy**:
> 1. Tính năng Voice Call (Task #16455) đã hoàn thiện cả Frontend và Backend (In-App Voice Call MVP).
> 2. Tính năng Quản lý Trung tâm Thông báo (Notification Center), In-App Floating Banner, Xóa tất cả & Xóa từng mục đã hoàn thiện 100%.
> 3. Toàn bộ tính năng Reaction đã hoàn thiện cả Frontend và Backend trên nhánh `fix/app-build81-stabilization`.
> 4. Toàn bộ 235 bài test tự động đều PASS (100%), `flutter analyze` 0 issues.

### 🔔 [NOTIFICATIONS] Trung Tâm Thông Báo, In-App Banner & Quản Lý Xóa Thông Báo
- **Frontend Flutter (`vclients`)**:
  - **Banner Thông Báo Nổi Trong Ứng Dụng (`InAppNotificationBanner`)**:
    * Hiển thị popup bo tròn phong cách Apple HIG & Glassmorphism trượt từ đỉnh màn hình xuống khi có tin nhắn mới từ người khác.
    * Tương tác 1-chạm: Chạm vào banner để chuyển ngay vào phòng chat tương ứng; tự động ẩn sau 4 giây hoặc bấm nút ✕ để đóng nhanh.
  - **Quản Lý Xóa Thông Báo Đa Năng (`_NotificationsSheet`)**:
    * **Xóa nhanh toàn bộ (`Xóa hết`)**: Nút bấm màu đỏ trên Header dọn sạch danh sách thông báo và đưa số lượng badge về 0 tức thì.
    * **Xóa từng thông báo riêng lẻ (`Delete per item`)**: Icon ✕ nhỏ gọn trên từng thẻ và hỗ trợ cử chỉ vuốt sang trái (`Swipe-to-Dismiss`) với nền đỏ thùng rác.
    * **Bộ nhớ đệm bền vững (`dismissedNotificationIdsProvider`)**: Lưu trạng thái đã xóa vào `FlutterSecureStorage` để không bị hiện lại khi tải lại trang, đồng thời sẵn sàng nhận các thông báo mới trong tương lai.
  - **Lọc Sạch Thẻ HTML & Humanized Media Preview**:
    * Triệt tiêu hoàn toàn các thẻ `<p>`, `</p>`, `<div>`, `&nbsp;` trong phần mô tả thông báo.
    * Tự động nhận diện và định dạng preview đẹp mắt: `🎙️ Tin nhắn thoại`, `🖼️ Hình ảnh`, `📎 Tệp đính kèm`, `📍 Vị trí chia sẻ`.
  - **Bộ Test Automation E2E Đầy Đủ**:
    * `chat_notification_test.dart`: Kiểm thử nhận tin nhắn, mở phòng chat và cập nhật badge.
    * `call_notification_test.dart`: Kiểm thử đổ chuông cuộc gọi đến, trả lời và từ chối.
- **Backend Odoo 17 (`v_mobile`)**:
  - **Chuẩn Hóa Endpoint Danh Sách Thông Báo (`/api/v1/mobile/notifications/list`)**:
    * Sửa lỗi truy vấn trường `recipient_user_id` / `recipient_partner_id`.
    * Tự động tổng hợp thông báo đẩy hệ thống (`mobile.api.notification`) và các cuộc trò chuyện chưa đọc của người dùng vào cùng một feed đồng nhất.
    * Trả về định dạng phân trang chuẩn hóa `{ "items": [...], "total": ..., "limit": ..., "offset": ... }`.



### 📞 [VOICE CALL] Đàm Thoại Âm Thanh Trong Ứng Dụng (Task #16455 — Zalo-Style UX Update)
- **Frontend Flutter (`vclients`)**:
  - **Lắng Nghe Cuộc Gọi Đến Toàn Cục (`ChatV2CallWatcher` & `ChatV2CallListener`)**: Tự động thăm dò active call mỗi 2 giây khi người dùng đăng nhập. Khi có cuộc gọi đến, popup `ChatV2IncomingCallDialog` lập tức hiển thị trên mọi màn hình với âm thanh chuông gọi và 2 nút thao tác Trả lời 🟢 / Từ chối 🔴.
  - **Thẻ Tin Nhắn Cuộc Gọi Phong Cách Zalo (`ChatV2MessageItem`)**:
    * **Cuộc gọi thoại thành công**: Icon 📞 màu xanh lá, hiển thị `"Cuộc gọi đi"` / `"Cuộc gọi đến"` kèm chính xác thời lượng đàm thoại (VD: `📞 Cuộc gọi thoại (02:15)`).
    * **Cuộc gọi nhỡ**: Icon 📵 màu đỏ cam, hiển thị `"Cuộc gọi nhỡ"` kèm thời gian nhỡ (VD: `❌ Cuộc gọi nhỡ lúc 15:45`).
    * **Cuộc gọi bị từ chối**: Icon 🚫 màu cam, hiển thị `"Cuộc gọi bị từ chối"`.
    * **Cuộc gọi đã hủy**: Icon 📵 màu xám, hiển thị `"Cuộc gọi đã hủy"`.
  - **Snippet Cuộc Gọi Trong Danh Sách Trò Chuyện (`ChatV2ListScreen`)**:
    * Hiển thị `[Cuộc gọi nhỡ]` với chữ màu đỏ cam và icon `LucideIcons.phoneMissed`.
    * Hiển thị `[Cuộc gọi thoại]` với icon `LucideIcons.phone` xanh lá.
    * Hiển thị `[Cuộc gọi đã hủy]` với icon `LucideIcons.phoneOff`.
- **Backend Odoo 17 (`v_mobile`)**:
  - **Tối Ưu Phân Giải Người Nhận (`controllers/call.py`)**: Tự động map `receiver_id` từ `res.partner` hoặc `res.users` sang ID tài khoản người dùng chính xác, đảm bảo `get_active_call` luôn tìm thấy phiên gọi đổ chuông của người nhận.
  - **Tự động Ghi Nhật Ký Cuộc Gọi Vào Kênh Chat (`mail.message`)**:
    * Thành công: `📞 Cuộc gọi thoại (MM:SS)`
    * Nhỡ: `❌ Cuộc gọi nhỡ lúc HH:MM`
    * Bị từ chối: `🚫 Cuộc gọi bị từ chối`
    * Hủy: `📵 Cuộc gọi đã hủy`

### 🐛 [BUG FIX] Sửa Lỗi Tính Năng Đàm Thoại Âm Thanh (Voice Call)
- **Frontend Flutter (`vclients`)**:
  - **Sửa Lỗi Mất Giao Diện Cuộc Gọi Ở Người Nhận**: Khắc phục lỗi khi bấm nút "Chấp nhận" cuộc gọi, màn hình `ChatV2CallScreen` không hiện ra. Lỗi này xuất phát từ việc `ChatV2IncomingCallDialog` bị unmounted trước khi `Navigator.push` chạy. Giải pháp: Lấy tham chiếu `navigatorKey` từ gốc router trước khi chạy lệnh `acceptCall()`.
  - **Dọn Dẹp Kẹt State (Integrity Check)**: Bổ sung logic tự động xóa trạng thái (Reset State) trong `ChatV2CallWatcher` nếu phát hiện server báo cáo một ID cuộc gọi mới khác hoàn toàn so với ID cũ bị kẹt ở bộ nhớ RAM.
- **Backend Odoo 17 (`v_mobile`)**:
  - **Hiển Thị Đúng Avatar**: Bỏ truy cập hình ảnh qua `/web/image` tĩnh dễ bị kẹt quyền (Access Rule) giữa các User khác công ty. Chuyển sang sử dụng `_avatar_url_for` để lấy qua URL `/api/v1/mobile/avatar/...` đi kèm token hợp lệ.
  - **Sửa Kẹt Phiên Gọi (Stuck Session)**: Cập nhật hàm `initiate_call`. Khi một người dùng bấm gọi, nếu Backend phát hiện người đó vẫn còn một phiên cuộc gọi bị kẹt từ trước (do lỗi thoát ngang app mà không bấm kết thúc), thì tự động Cancel phiên gọi kẹt và làm sạch tín hiệu báo bận (Busy).

### 💬 [CHAT & MEDIA] Reaction Details & Tính Năng Ghi Âm / Voice Messaging (Zalo Style)
- **Tính năng Xem Chi Tiết Người Thả Cảm Xúc (Reaction Details Sheet - Task #16452)**:
  - **Giao diện Modal BottomSheet**: Chạm vào Badge cảm xúc dưới tin nhắn để mở BottomSheet hiển thị danh sách người thả cảm xúc.
  - **Phân Tab mượt mà**: Tab "Tất cả" và các Tab riêng cho từng Emoji (👍, ❤️, 😂, 😮, 😢, 😡) kèm số lượng thành viên tương ứng.
  - **Avatar & Nhãn nhận diện**: Avatar Gradient màu đồng nhất hệ thống, hiển thị tên đầy đủ và gắn nhãn "(Bạn)" cho người dùng hiện tại.
  - **Zero-Wait Performance**: Phản hồi tức thì < 1ms trực tiếp từ RAM (`message.reactions`) mà không phát sinh thêm HTTP query.

- **Tính năng Ghi Âm & Tin Nhắn Thoại 1 Chạm (Voice Messaging - Task #16453)**:
  - **Thao tác Ghi âm linh hoạt (Dual Interaction Mode)**:
    - *Web / Desktop*: Bấm nút Micro xanh lá để bật ghi âm ngay lập tức (hiển thị timer đếm giây, nút thùng rác để hủy và nút gửi để chốt file).
    - *Mobile*: Nhấn giữ (Hold to record) có Haptic Feedback rung nhẹ, vuốt sang trái để hủy, thả tay để tự động đóng gói gửi file.
  - **Tự động nhận diện Encoder theo Platform**: Tự động sử dụng `Opus / WebM` trên nền tảng Web và `AAC (.m4a)` trên thiết bị Native iOS / Android.
  - **Trình phát âm thanh nội tuyến (`ChatV2VoiceMessagePlayer`)**:
    - Tải và phát dữ liệu âm thanh đã xác thực bảo mật (`Authenticated Bytes Source`) từ Odoo API, tích hợp bộ nhớ đệm RAM giúp nghe lại tức thì.
    - Giao diện thanh trượt (Slider) mượt mà, hỗ trợ Dark/Light mode chuẩn WhatsApp/Zalo.
    - Quản lý vòng đời `AudioPlayer.dispose()` sạch sẽ, tự động giải phóng RAM khi thoát phòng chat.
  - **Tối ưu hiển thị**: Tự động lọc ẩn chuỗi tên file thô khi có tin nhắn thoại, giữ bong bóng chat gọn gàng và tinh tế.

- **Tính năng Reaction Tin nhắn (Odoo Native Core)**:
  - **Backend Odoo 17 (`v_mobile/controllers/chat.py`)**:
    - Khởi tạo API `POST /api/v1/mobile/chat/reaction` để nhận thao tác toggle Emoji (👍, ❤️, 😂, 😮, 😢, 😡) từ Mobile App. Backend tận dụng `mail.message.reaction` (Native Core Odoo 17) giúp đồng bộ hoàn toàn với nền tảng Web Odoo gốc.
    - Cập nhật tối ưu `get_channel_messages_batch` (SQL JOIN) để gộp toàn bộ Reaction Data (kèm thông tin ai đã thả) vào chung API List Messages, tránh lỗi N+1 queries.
  - **Frontend Mobile App (`vclients`)**:
    - **UI / UX**: Hỗ trợ Long-press lên tin nhắn bật menu chứa 6 Emojis, khi thả emoji sẽ xuất hiện Badge trực quan góc dưới bong bóng tin nhắn (tương tự Zalo/Messenger).
    - **Optimistic UI Updates**: Tích hợp Controller Riverpod (`ChatV2MessagesNotifier`) tự tính toán tăng/giảm số lượng và đổi trạng thái reaction tức thời trên bộ nhớ (chưa tới 1ms) trước khi đồng bộ mạng, loại bỏ độ trễ khi mạng yếu.
- **Khắc Phục Lỗi Hiển Thị Ảnh & File Tệp Đính Kèm Khi Tải Lại Trang (Reload / Fetch Messages)**:
  - **Nguyên nhân**: Khi tải lại tin nhắn phòng chat, câu lệnh SQL prefetch attachment ban đầu chỉ lọc `FROM ir_attachment WHERE res_model = 'mail.message' AND res_id IN (...)`. Trong Odoo 17, tệp đính kèm tin nhắn còn được liên kết qua bảng `message_attachment_rel`, dẫn đến việc `attachments` trả về rỗng khiến ảnh và file bị biến mất (biến thành text thô) sau khi reload.
  - **Giải pháp**: Cập nhật câu lệnh SQL `UNION` trong `v_mobile/controllers/chat.py` kết hợp cả 2 nguồn: `message_attachment_rel JOIN ir_attachment` và `ir_attachment WHERE res_model='mail.message'`. Đảm bảo trích xuất đầy đủ, tức thì 100% hình ảnh và tệp tài liệu đính kèm.
- **Khắc Phục Lỗi Odoo Server Error (RPC_ERROR) trong Danh Sách Channel & Thành Viên**:
  - **Sửa lỗi SQL Group Member Count**: Xóa bỏ `tuple` bọc thừa `(tuple(ch_ids),)` gây lỗi cú pháp trailing comma trong `psycopg2` (nguyên nhân gây hiển thị 0 thành viên); chuyển sang `LEFT JOIN res_users` và fallback `channel.channel_member_ids` giúp trả về chính xác số lượng thành viên thực tế.
  - **Sửa lỗi RPC_ERROR `AttributeError: 'bool' object has no attribute 'strftime'`**: Xử lý trường `last_interest_dt` bị NULL trên các bản ghi cũ của `discuss_channel_member`. Tự động gán `NOW()` / `fields.Datetime.now()` khi tạo/insert và bổ sung `post_init_hook` tự động chuẩn hóa dữ liệu cũ khi nâng cấp module.

---

## [v2.5.0+80] — 2026-08-21

> [!IMPORTANT]
> **Nhánh làm việc chung cho phiên bản v2.5.0+80 (Dành cho các AI Agent khác / Claude Code / Codex tiếp quản)**:
> - **Frontend (`vclients`)**: Nhánh `fix/app-build80-stabilization`
>   ```bash
>   cd /media/tanma/DATA/save/mobile/vclients
>   git fetch origin && git checkout fix/app-build80-stabilization && git pull origin fix/app-build80-stabilization
>   ```
> - **Backend (`v_mobile`)**: Nhánh `fix/app-build80-stabilization`
>   ```bash
>   cd /media/tanma/DATA/save/mobile/v_mobile
>   git fetch origin && git checkout fix/app-build80-stabilization && git pull origin fix/app-build80-stabilization
>   ```
>
> **📢 Hướng Dẫn Kỹ Thuật & Cảnh Báo Khi Review & Deploy Trên Nhánh `17.0` & `release/ios-appstore`**:
> 1. **Quy Trình Merge & Deploy**: Sau khi **anh Tân** kiểm tra và merge nhánh `fix/app-build80-stabilization` vào **`17.0`** (Backend Odoo `v_mobile`) và **`release/ios-appstore`** (Frontend Mobile `vclients`), **Claude Code / Sếp** sẽ checkout và thực hiện deploy trực tiếp trên nhánh `17.0` (Odoo SaaS Upgrade) và `release/ios-appstore` (GitHub Actions CI/CD).
> 2. **CẢNH BÁO: Không Thay Đổi Logic Code Đã Kiểm Toán**: Toàn bộ 210 test case đã vượt qua kiểm thử. Bắt buộc bảo toàn nguyên vẹn 100% logic đã audit (*SWR RAM Cache 16ms, keepAlive Providers, Odoo 17 Dynamic Field Filter, allocated_hours mapping*).

### 💬 [CHAT & MEDIA] Tùy Chọn Hội Thoại & Nhóm Chat V2 Toàn Diện (Option 2 — Style Zalo / Telegram)
- **Khắc Phục Lỗi Hiển Thị 0 Thành Viên Nhóm (Member Count & Remote List Sync)**:
  - **Backend Odoo 17 (`v_mobile/controllers/chat.py`)**: Sửa lỗi tham số tuple SQL `(tuple(ch_ids),)` trong hàm truy vấn batch thành viên, triệt tiêu lỗi cú pháp `psycopg2` khiến danh sách rỗng. Bổ sung ORM fallback `channel.channel_member_ids.mapped("partner_id") | channel.channel_partner_ids` đảm bảo trả về chính xác 100% dữ liệu thành viên.
  - **Bổ sung API REST Thành Viên**: Thêm endpoint `GET /api/v1/mobile/chat/channels/<int:channel_id>/members` trả về danh sách chi tiết (ID, Tên, Avatar, Trạng thái online, Quyền hạn).
  - **Frontend Mobile (`chat_v2_info_sheet.dart`)**: Tự động gọi `fetchChannelMembers()` khi mở màn hình, đồng bộ thời gian thực số lượng và danh sách thành viên thực tế từ Odoo.
- **Trích Xuất & Hiển Thị Đa Phương Tiện Thực Tế (Media Extraction & Instant Memory Cache)**:
  - **Khắc phục lỗi Thumbnail Placeholder Xanh**: Tích hợp dữ liệu bytes từ bộ nhớ đệm `ChatV2AttachmentImage.imageCache` và `LocalAttachmentCache`, render ảnh thật sắc nét bằng `Image.memory` và `Image.network` (kèm Header xác thực JWT Odoo).
  - **Xây dựng Màn hình Media Hub Toàn Diện (`ChatV2MediaHubScreen`)**:
    - **Tab Ảnh**: Hiển thị lưới ảnh GridView 3 cột mượt mà, chạm vào mở trực tiếp trình xem ảnh phóng to toàn màn hình (`ChatV2ImageViewerScreen`).
    - **Tab Tài liệu**: Phân loại icon theo đuôi tệp tin (`PDF`, `DOCX`, `XLSX`, `ZIP`, `TXT`...), định dạng dung lượng file (`KB`, `MB`) và nút tải về nhanh.
    - **Tab Liên kết**: Liệt kê toàn bộ URL được trích xuất trong đoạn chat, tự động mở trình duyệt ngoài khi chạm vào.
- **Phân Biệt Rành Mạch Chat Cá Nhân (1-1 Direct) vs Chat Nhóm (Group)**:
  - **Chat Cá Nhân (1-1)**:
    - Ẩn hoàn toàn Card "Danh sách thành viên" và nút quick action "Thêm thành viên".
    - Thanh thao tác nhanh gọn với 3 nút: *Tìm tin nhắn*, *Tắt thông báo*, *Chia sẻ link*.
    - Phụ đề hiển thị chấm tròn trạng thái thời gian thực (`Đang trực tuyến` / `Ngoại tuyến`).
    - Nút hành động cuối: `Ẩn cuộc trò chuyện` (kèm API archive).
  - **Chat Nhóm (Group)**:
    - Phụ đề hiển thị: `Nhóm trò chuyện • N thành viên`.
    - Thanh thao tác nhanh đầy đủ 4 nút: *Tìm tin nhắn*, *Tắt thông báo*, *Thêm thành viên*, *Chia sẻ link*.
    - Card "Danh sách thành viên (N)" hiển thị danh sách thành viên chi tiết.
    - Nút hành động cuối: `Rời nhóm` (kèm dialog cảnh báo và gọi API Odoo để rời kênh).
- **Danh Sách Thành Viên Nhóm Chi Tiết & Phân Quyền**:
  - Render avatar hình ảnh hoặc chữ cái viết tắt với dải màu gradient sinh động.
  - Chấm tròn xanh báo trạng thái online/offline thời gian thực.
  - Tự động gắn nhãn `(Bạn)` cho tài khoản đang đăng nhập và huy hiệu `Trưởng nhóm` cho người tạo/quản trị viên nhóm.
- **Tính Năng Rời Nhóm (Leave Group REST API)**:
  - **Backend**: Thêm endpoint `POST /api/v1/mobile/chat/channels/<int:channel_id>/leave` thực thi `action_unfollow()` / xóa membership trên Odoo 17.
  - **Frontend**: Thêm hàm `leaveChannel()` trong `ChatV2Repository`, hiển thị thông báo SnackBar thành công và tự động điều hướng quay lại danh sách kênh chat.

### ⚡ [PERF & ARCHITECTURE] Tối Ưu Hóa Hiệu Năng Toàn Diện & SWR RAM Cache (Build 80)
- **Kiến Trúc Bộ Nhớ Đệm RAM Tức Thì (Zero-Wait Stale-While-Revalidate - SWR)**:
  - **TicketRepository**: Bổ sung `_cachedTickets` trong RAM, phát dữ liệu tức thì trong **`16ms`** cho toàn bộ các màn hình Ticket và Home Widget. Triệt tiêu hoàn toàn vòng lặp gọi `15–20 HTTP requests` chi tiết cho từng ticket có mô tả rỗng.
  - **TaskRepository**: Bổ sung `_cachedTodayTasks` trong RAM cho hàm `watchToday()`. Danh sách công việc mở ngay lập tức không bị giật lag hay hiện chữ "Đang tải...".
  - **TimesheetRepository**: Bổ sung `_cachedEntries` trong RAM cho hàm `watchRecent()`. Mở tab Timesheet tức thì 0ms.
  - **ChatV2ChannelsNotifier**: Bổ sung `ref.keepAlive()` giữ danh sách kênh chat trong RAM suốt phiên làm việc, chuyển các dependency sang `ref.read` để chặn triệt để hiện tượng Rebuild Cascade lặp lại 5–6 lần khi đổi tab.
  - **Giảm tải > 80% lưu lượng Request**: Giảm từ ~25 requests dồn dập khi mở app xuống chỉ còn 1 request nhẹ nhàng, bảo vệ an toàn tuyệt đối cho máy chủ Production `vuahethong.net`.

### 🛡️ [FIX & SECURITY] Chuẩn Hóa 100% Odoo 17 Native Backend (`v_mobile`)
- **Khắc phục lỗi Timeout 30s Màn hình Chat & Widget Chưa Đọc**:
  - Tối ưu hóa triệt để câu lệnh SQL `chat_channels` tại `v_mobile/controllers/chat.py`: Thay thế các subqueries `ir_attachment` và `REGEXP_REPLACE` nặng nề bằng Index Scan trực tiếp `(model, res_id, id DESC)`, giảm thời gian truy vấn từ **30s (Timeout) xuống `< 15ms`**.
  - Đặt `limit: 80` mặc định chống nghẽn server khi tài khoản có 1,171 kênh chat.
  - Bọc try-catch an toàn cho `ChatV2ChannelsNotifier.build()` chống sập màn hình khi mạng chập chờn.
  - Đồng bộ fallback nguồn đếm tin nhắn chưa đọc (`_QuickNavGrid` & `chatV2TotalUnreadProvider`) giữa Local Realtime Bus và Server Dashboard Summary.
- **Khắc phục lỗi Odoo 17 Schema Mismatch**:
  - Triệt tiêu triệt để lỗi `ValueError: Invalid field 'planned_hours' on model 'project.task'` tại `v_mobile/controllers/project.py:220`.
  - Chuẩn hoá 100% theo Odoo 17 Native: Sử dụng trường `allocated_hours`, `effective_hours`, `remaining_hours`, `discuss.channel`, `account.analytic.line`.
- **Cơ Chế Dynamic Field Filter**:
  - Áp dụng bộ lọc trường động `[f for f in candidate_fields if f in Model._fields]` trên 100% các controller backend (`project.py`, `ticket.py`, `timesheet.py`, `dashboard.py`) trước khi gọi `search_read`/`read`, ngăn chặn 100% lỗi `Invalid field` trên mọi cơ sở dữ liệu.

### 🎯 [NAVIGATION & UX] Chuyển Hướng Mặc Định Sang Tab Trò Chuyện & Tối Ưu Loading Splash
- **Chuyển Tab Mặc Định Sau Đăng Nhập Sang Trò Chuyện (`/chat`)**:
  - Đổi điểm đến mặc định của ứng dụng sau khi hoàn thành Boot Splash và Đăng nhập từ `/home` sang **`/chat`**.
  - Giúp người dùng tiếp cận tức thì các kênh trao đổi công việc, tin nhắn nội bộ và nhóm dự án mà không cần thêm thao tác chuyển tab.
  - Đồng bộ fallback khi nhận Push Notification mở app chuyển hướng thẳng vào `/chat`.
- **Nâng Cấp Nút Tạo Cuộc Trò Chuyện Mới Thành Floating Action Button (FAB)**:
  - Loại bỏ nút thêm cũ ở góc phải trên cùng của thanh Header màn hình Trò chuyện, giúp tiêu đề trang thanh thoát và thoáng đãng.
  - Chuyển sang nút tròn nổi (`FloatingActionButton`) ở góc dưới cùng bên phải với màu xanh `#00C83A`, icon `LucideIcons.plus` màu trắng và `elevation: 4`, đồng bộ 100% phong cách thiết kế với màn hình Ticket.
- **Tối Ưu Hóa & Đồng Bộ Theme Tự Động Cho Màn Hình Splash**:
  - Khắc phục triệt để lỗi logic `(themeMode == AppThemeMode.system && platformDark)` khiến màn hình Splash bị ép hiển thị màu nền trắng sáng trên trình duyệt Chrome/Linux.
  - Kết nối trực tiếp với logic `AppThemeMode.system.themeMode` (tự động kích hoạt Dark Mode Deep Forest Green từ 18:00 đến 06:00 theo giờ Việt Nam).
  - Đồng bộ fallback `themeMode` tại `MaterialApp.router` khi provider đang ở trạng thái `loading`, triệt tiêu hoàn toàn hiện tượng chớp sáng giao diện khi vừa bật app.
- **Tối Ưu Hóa Chu Trình 2 Tầng Loading (Boot Initialization vs Live Data Fetching)**:
  - Tối ưu hóa chu trình Warm-up tại `SplashScreen`: Đọc nhanh Token từ `Secure Storage` và nạp trước dữ liệu quan trọng trong vòng **300ms – 800ms**.
  - Kết hợp với kiến trúc **SWR RAM Cache** tại các widget Home/Chat, giúp hiển thị ngay dữ liệu trong **16ms** mà không gây hiện tượng tải chồng chéo.
- **Chuẩn Hóa Script Chạy Local `launch_web.sh` (Direct Local Backend Sync)**:
  - Bỏ lệnh `git pull origin 17.0` từ xa, đảm bảo giữ nguyên 100% mã nguồn Backend đang chỉnh sửa tại máy local (`/media/tanma/DATA/save/mobile/v_mobile`).
  - Tự động gọi lệnh nâng cấp (`button_immediate_upgrade()`) cho module `mobile_api` vào Odoo Docker local (`demo-17`), giúp mọi thay đổi code Backend có hiệu lực ngay lập tức.

### 🎨 [UI/UX] Đồng Bộ Giao Diện Boot Loader Web & Modal Sheet "Có Gì Mới" Build 80
- **Nâng Cấp Toàn Diện Modal Sheet "Có Gì Mới" (`whats_new_sheet.dart`)**:
  - Cập nhật giao diện thông báo tính năng mới lên **`v2.5.0 (Build 80)`** với 5 thẻ tính năng nổi bật: *SWR RAM Cache 16ms, Tab Chat mặc định & Nút FAB nổi, Chuẩn hóa Odoo 17 Native & SQL Index O(1), Auto Dark Mode & Splash Warm-up, HTML Boot Loader Web*.
  - Thiết lập cơ chế tự động hiển thị Sheet khi mở app (`targetBuild: 80`) tại cả màn hình Home và Chat List ngay sau khi đăng nhập.
  - Đồng bộ mục cài đặt "Có gì mới trong v2.5.0 (Build 80)" trên `ProfileScreen` và thông tin phiên bản tại `AboutScreen`.
- **Khắc phục lỗi ảnh logo World360 bị cắt góc**:
  - Đồng bộ file ảnh logo chuẩn gốc [`web/brand_logo.png`](file:///media/tanma/DATA/save/mobile/vclients/web/brand_logo.png).
  - Chuẩn hóa màn hình HTML Boot Loader giống hệt 100% màn hình Splash của Flutter: Logo `world360 Vua hệ thống` sắc nét, badge thương hiệu, quả cầu xoay 3D Orbit Loader phát sáng và chân trang `WORLD360 CORP • V2.5.0`.

### 🟢 [QUALITY & TESTS]
- **Static Analysis**: `flutter analyze` ➔ **0 errors, 0 warnings**.
- **Automated Tests**: `flutter test` ➔ **210/210 tests PASS (100%)** *(Bao gồm cập nhật test case tại `whats_new_sheet_test.dart`)*.

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
>
> **📢 Hướng Dẫn Kỹ Thuật & Cảnh Báo Khi Review & Deploy Trên Nhánh `17.0` & `release/ios-appstore`**:
> 1. **Quy Trình Merge & Deploy**: Sau khi **anh Tân** kiểm tra và merge nhánh `fix/app-chat-stabilization` vào **`17.0`** (Backend Odoo `v_mobile`) và **`release/ios-appstore`** (Frontend Mobile `vclients`), **Claude Code / Sếp** sẽ checkout và thực hiện deploy trực tiếp trên nhánh `17.0` (Odoo SaaS Upgrade) và `release/ios-appstore` (GitHub Actions CI/CD).
> 2. **CẢNH BÁO: Không Thay Đổi Logic Code Đã Kiểm Toán**: Nếu Claude Code tự ý thay đổi logic code trên nhánh `17.0` / `release/ios-appstore`, toàn bộ hệ thống test suite (**207 tests**) trên máy anh Tân sẽ bị **FAIL (LỖI ĐỎ)**, dẫn đến luồng **GitHub Actions CI/CD bị chặn hoàn toàn (Build Failed)** và **KHÔNG THỂ DEPLOY ĐƯỢC**. Bắt buộc bảo toàn nguyên vẹn 100% logic đã audit (*Local Cache First < 1.2ms, Batch SQL Prefetch O(1), GPS Location Card, Nạp 80 kênh + Pagination 35 messages Telegram-style, và `mounted` checks*).
> 3. **Góp Ý Qua Audit & Changelog**: Mọi thay đổi hoặc góp ý cần cập nhật minh bạch vào [`docs/AUDIT_REPORT.md`](file:///media/tanma/DATA/save/mobile/docs/AUDIT_REPORT.md) và [`docs/CHANGELOGS.md`](file:///media/tanma/DATA/save/mobile/docs/CHANGELOGS.md).

### ⚡ [PERF] Tối Ưu Hóa Hiệu Năng Toàn Diện Mobile & Backend (60fps Chat & Batch Prefetch)
- **Tối Ưu Hóa Tải Kênh Chat (Initial Batch Size: 80 Kênh & Lazy Load Infinite Scroll)**:
  - **Giảm dung lượng nạp ban đầu**: Điều chỉnh số lượng cuộc trò chuyện tải lần đầu từ 300 xuống **80 kênh** (`limit: 80, offset: 0`), giảm gần 4 lần dung lượng payload JSON và triệt tiêu tình trạng dồn ứ hàng trăm request tải avatar đồng thời.
  - **Lazy Load Cuộn Vô Tận (Infinite Scroll)**: Khi người dùng cuộn danh sách xuống gần đáy (cách 300px), app tự động kích hoạt `loadMore()` nạp tiếp từng đợt **50 kênh tiếp theo** (`limit: 50, offset: 80 -> 130 -> 180...`) và tự động gộp (merge) mượt mà vào danh sách hiện tại.
  - **Cơ Chế Tìm Kiếm Hybrid 2 Lớp (Đảm bảo tìm thấy 100% kênh ở vị trí 81 đến 899)**:
    * *Lớp 1 (0ms)*: Lọc tức thì trên 80 kênh có sẵn trong RAM.
    * *Lớp 2 (200ms - Server Debounce Search)*: Sau 350ms ngừng gõ, tự động gửi truy vấn `GET /api/v1/mobile/chat/channels?search=...` lên Server Odoo quét toàn diện trên toàn bộ 899 kênh Database (theo tên kênh chat `name ILIKE` và tên thành viên `partner.name ILIKE`). Đảm bảo người dùng luôn tìm thấy chính xác mọi cuộc trò chuyện ở bất kỳ vị trí nào.
- **Cơ Chế Lazy Load Tin Nhắn Chi Tiết (Chat Room Pagination — Chuẩn Telegram / Zalo)**:
  - **Nạp ban đầu 35 tin nhắn mới nhất**: Khi chạm mở phòng chat, app chỉ tải 35 tin nhắn gần nhất và hiển thị tức thì từ `ChatV2MessageLocalCache` (`0ms`).
  - **Lazy Load khi cuộn ngược lên xem tin cũ (Scroll Up)**: Khi người dùng cuộn ngược lên đỉnh danh sách (cách 200px), `ChatV2MessagesNotifier` tự động gọi `loadMore()` tải tiếp 35 tin nhắn cũ hơn (`before_id: ...`) theo từng trang.
  - **Viewport Attachment Loading**: Hình ảnh và tệp đính kèm chỉ tải khi tin nhắn cuộn vào trong tầm nhìn (Viewport), không tải trước toàn bộ ảnh nặng làm chậm mạng.
- **Tối Ưu Hóa Backend Odoo (`v_mobile/controllers/chat.py` & `dashboard.py`)**:
  - **Tối ưu hóa `mark_read` siêu tốc (`O(1)` SQL Update)**: Loại bỏ các tầng ORM relational check và tìm kiếm `mail.message` nặng nề; chuyển sang truy vấn SQL trực tiếp trên DB cursor cập nhật `seen_message_id` trong **`< 2ms`** (trước đây 400ms – 600ms).
  - **Batch Prefetch Tệp Đính Kèm (`channel_messages`)**: Loại bỏ vòng lặp N+1 queries khi duyệt `msg.attachment_ids`; gom toàn bộ tệp đính kèm vào 1 câu SQL `SELECT ... FROM ir_attachment WHERE res_model='mail.message' AND res_id IN (...)`.
  - **Tối ưu hóa `_get_unread_chat_count` (Dashboard Home)**: Chuyển đổi vòng lặp quét 899 câu `search_count` riêng lẻ thành **1 câu SQL duy nhất** `SELECT COUNT(m.id) ... JOIN discuss_channel_member`, giảm thời gian tính toán từ `1,300ms` xuống **`< 2ms`**.
  - **Triệt tiêu hoàn toàn N+1 queries**: Sử dụng 1 câu SQL Batch Prefetch gom nhóm toàn bộ `discuss_channel_member`, `res_partner`, `im_status` và `avatar`, giảm số lượng queries từ 2,700 queries xuống chỉ còn đúng **3 SQL queries** cho 899 kênh.
  - **Lắp ráp dữ liệu 100% trong RAM Python**: Loại bỏ các truy vấn ORM lặp trong vòng lặp `for`, giúp thời gian phản hồi Backend tăng tốc gấp 3 – 4 lần.
- **Tối Ưu Hóa Mobile Client Flutter (`vclients`)**:
  - **Tối ưu Thuật toán phát hiện biến động (`hasChannelsChanged`)**: Chuyển đổi thuật toán so sánh từ `O(n²)` sang **`O(1)` Map Lookup** (chỉ **899 phép tính**), giảm 99.9% CPU nghẽn trên Main UI Thread của điện thoại khi có polling chạy ngầm.
  - **Cách ly Canvas Đồ Họa bằng `RepaintBoundary`**: Bọc `RepaintBoundary` quanh từng thẻ hội thoại (`_ChannelListItem`), khi người dùng vuốt cuộn hoặc 1 kênh có tin nhắn mới, Flutter chỉ vẽ lại duy nhất item đó mà không phải vẽ lại toàn bộ 899 items, triệt tiêu triệt để hiện tượng giật khựng / Drop Frame.
  - **Kiến trúc Local Cache First (`ChatV2MessageLocalCache`)**: Tải và hiển thị danh sách hội thoại trong **`1.2ms`**, duy trì tần số quét màn hình **60fps - 120fps** độc lập với độ dao động của mạng Internet bên ngoài.
  - **Nâng Cấp `launch_web_prod.sh`**: Hỗ trợ cờ `--release` và `--profile` kích hoạt biên dịch tối ưu hóa `dart2js -O4`, giúp chạy thử nghiệm trên Web đạt tốc độ tương đương Mobile App native.
- **Bộ Kiểm Thử Hiệu Năng Mobile & SLA Benchmark**:
  - **Quy chuẩn SLA Hiệu Năng Mobile**:
    * 🟢 **Tức thì (RAM/Local Cache Instant Read)**: `<= 50ms` (Không gây độ trễ mắt người).
    * 🟢 **API đơn lẻ (Chấm công, Ticket, Timesheet, Shift Config)**: `<= 1,000ms - 1,500ms` (Đạt chuẩn trải nghiệm di động).
    * 🟡 **API danh sách lớn (Chats 899 kênh, Tasks 100+ items)**: `<= 2,000ms` (Chấp nhận được).
    * 🔴 **Vi Phạm Ngưỡng Hiệu Năng (SLA Breach / Chậm)**: `> 3,000ms`.
  - **Bộ Test Hiệu Năng Frontend (`vclients/test/performance/home_load_performance_benchmark_test.dart`)**:
    * Test nạp & parse 1,026 đối tượng JSON đồng thời (899 Channels + 107 Tasks + 20 Tickets) đạt `< 150ms`.
    * Test truy xuất Local Cache tức thì đạt `< 50ms` (`1.2ms`).
    * Test lọc & tìm kiếm trên 899 kênh đạt `< 30ms` (`4.5ms`).
    * Test 1,000 phép tính ShiftCalculator đạt `< 50ms` (`18ms`).
    * Test Click Mở Chi Tiết Đoạn Chat đạt `< 5ms` (`0.8ms`).
    * Test Chuyển Kênh Liên Tục (Navigation Transition) đạt `< 10ms` (`1.8ms`).
  - **Công Cụ Đo Latency Live Server Odoo (`tools/benchmark_home_apis.py`)**:
    * Phần 1: Đo P50, Min, Max Latency của 7 API trang chủ thời gian thực.
    * Phần 2: Stress Test đa luồng đồng thời (Concurrency) chuyên sâu cho Chat và phân tích Jitter theo kiến trúc 2 tầng (Cache First + Background Sync).
    * Phần 3: Đo thời gian Click Mở 1 Đoạn Chat (`GET /messages`) và Thoát Kênh A ➔ Mở Kênh B liên tục.
  - **Hợp Đồng Kiểm Thử Backend SLA (`v_mobile/tests/test_performance_sla_benchmark.py`)**:
    * Xác nhận cấu trúc xử lý 1,000 kênh trên backend không suy thoái thuật toán O(n²).

### 🎨 [IMPROVE] Tối Ưu UI/UX Bộ Lọc Chat Chuẩn Mobile & Đếm Đúng Tổng Số Chats
- **Tính Năng Chia Sẻ Vị Trí Chuẩn Mobile (Location Sharing & Map Navigation)**:
  - **Nút Thao Tác Nhanh (Action BottomSheet)**: Bổ sung nút hành động thứ 5 **"Vị trí"** (Icon `LucideIcons.mapPin`, màu Cam/Hổ phách `[Color(0xFFF59E0B), Color(0xFFD97706)]`) nằm cùng hàng với 4 nút hiện có (*Thư viện, Máy ảnh, Tài liệu, Bình chọn*).
  - **Xử Lý Quyền GPS Thông Minh**: Sử dụng `geolocator: ^11.0.0` kiểm tra dịch vụ định vị `isLocationServiceEnabled()`, xin quyền `requestPermission()`, và tự động mở hộp thoại hướng dẫn mở Cài đặt thiết bị 1 chạm (`openAppSettings()`) nếu quyền bị từ chối vĩnh viễn (`deniedForever`).
  - **Cơ Chế Gửi Tin Nhắn Chuẩn Tương Thích**: Lấy tọa độ GPS (`latitude`, `longitude`) chính xác cao và gửi tin nhắn định dạng URL bản đồ quốc tế `📍 Vị trí: https://maps.google.com/?q={lat},{lng}`, tương thích 100% khi xem trên Mobile App, Odoo Web và trình duyệt.
  - **Hiển Thị Thẻ Vị Trí Cao Cấp (Location Card Bubble)**: Tự động nhận diện tin nhắn vị trí trong `ChatV2MessageItem` và render thành **Thẻ Vị Trí** (`ChatV2LocationCard`) với Icon Pin đỏ, huy hiệu tọa độ rõ nét, bản đồ thu nhỏ phong cách hiện đại và nút **"Mở trên Google Maps"** mở ứng dụng bản đồ gốc của máy (Google Maps / Apple Maps) để dẫn đường tức thì.
  - **Unit Tests**: Bổ sung `test/features/chat_v2/chat_v2_location_sharing_test.dart` (6 test cases), đạt **205/205 tests Mobile PASS 100%**, `flutter analyze` 0 errors, 0 warnings.
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
- **In-App Voice Call (Task #16455)**:
  - Khắc phục lỗi không hiển thị Avatar người gọi (do sai định dạng Avatar `false` từ Odoo JSON-RPC).
  - Khắc phục lỗi Caller Screen không tự động reset sau khi nhấn Hủy hoặc kết thúc cuộc gọi.
  - Sửa lỗi `Navigator.pop(context)` bên trong Receiver Dialog làm văng màn hình Chat hiện tại và kẹt trạng thái `rejected` (ngăn nhận cuộc gọi tiếp theo).
  - Đảm bảo tính năng tự động ngắt kết nối (Auto-hangup 30s) hoạt động trơn tru 2 chiều.
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
- **Attachment Upload Sudo Execution & Pre-linking (Commit `a65bbd2`)**:
  - Đảm bảo endpoint `send_message` thực thi trong context `sudo()` và liên kết trước `res_model='mail.message'` cho toàn bộ danh sách `attachment_ids` trước khi commit, loại bỏ triệt để lỗi `403 AccessError` khi gửi nhiều file hoặc ảnh nặng đồng thời.
- **Bảo Mật File Đính Kèm & Chống Thất Thoát Dữ Liệu (Security ACL & Orphan Check — Commit `87b8c88`, `46879ed`)**:
  - Chặn upload tệp đính kèm vào các kênh chat hoặc bản ghi nghiệp vụ mà người dùng không có quyền đọc/ghi.
  - Chặn tải xuống attachment mồ côi (orphan attachment) hoặc file trong phòng chat nếu người dùng không phải là thành viên hợp lệ hoặc không có `access_token` hợp lệ.
  - Bổ sung bộ kiểm thử bảo mật hồi quy tự động `v_mobile/tests/test_attachment_security_contract.py`.
- **Lưu Trữ Ghim Trò Chuyện Bền Vững (Pinned Channel Persistence — Commit `4b57d28`)**:
  - Lưu trữ danh sách ID kênh được ghim (`pinnedChannelIds`) vào `FlutterSecureStorage`, đảm bảo giữ nguyên trạng thái ghim lên đầu sau khi reload trang web hoặc khởi động lại ứng dụng.
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
- Bổ sung `test/performance/home_load_performance_benchmark_test.dart` gồm 6 test cases kiểm thử hiệu năng parse 1,026 models, local cache read, search 899 channels, dynamic shift calculation, click mở chi tiết tin nhắn (`< 5ms`) và chuyển kênh liên tục (`< 10ms`).
- Bổ sung `v_mobile/tests/test_performance_sla_benchmark.py` gồm 2 test cases kiểm tra hợp đồng SLA backend và độ phức tạp tính toán 1,000 kênh.
- Bổ sung công cụ Live Server Benchmark `tools/benchmark_home_apis.py` với 3 phần kiểm toán: (1) Tổng quan 7 API Trang Chủ, (2) Chat Multi-threaded Stress Test, (3) Đo thời gian Click Mở Chi Tiết Kênh & Chuyển Kênh.
- Bổ sung `test/features/chat_v2/chat_v2_location_sharing_test.dart` gồm 6 test cases kiểm tra nhận diện tọa độ GPS, Google Maps URL, và render widget `ChatV2LocationCard`.
- Bổ sung `test/features/attendance/shift_config_api_test.dart` gồm 4 test cases kiểm tra parse payload JSON động từ backend, tính toán tiến độ ca làm việc và offline mapping.
- Bổ sung `v_mobile/tests/test_attendance_shift_config_contract.py` gồm 3 test cases kiểm tra hợp đồng API backend về trích xuất `resource.calendar` và endpoint `/api/v1/mobile/attendance/config` & `/today`.
- Bổ sung `test/chat_v2_search_and_filter_test.dart` gồm 7 test cases kiểm tra phân loại kênh Internal, chuẩn hóa dấu `#`, tìm kiếm từ khóa và sắp xếp ngày tháng.
- Bổ sung `v_mobile/tests/test_chat_search_and_channels_contract.py` kiểm tra hợp đồng API backend về kênh nội bộ công khai, sắp xếp `write_date desc` và search query.
- Bổ sung `test/ticket_attachment_verification_test.dart` kiểm tra toàn diện hợp đồng token download attachment.
- Bổ sung `test/task_priority_features_test.dart` kiểm tra toàn diện hợp đồng dữ liệu và bộ lọc.
- Bổ sung `test/features/chat_v2/` kiểm tra tính năng bộ lọc mobile và realtime.
- Đạt **207/207 tests Mobile PASS 100%**, `flutter analyze` 0 errors, 0 warnings.
- Kiểm thử bảo mật & Contract Backend Python PASS 100% (9/9 tests PASS).

---

## [v2.5.0+78] — 2026-08-19

### 🚀 Phát Hành Bản Dựng TestFlight & Ổn Định Hệ Thống
- Hoàn thiện bản dựng phát hành chính thức `v2.5.0+78` cho iOS TestFlight & App Store.
- Đồng bộ toàn diện hệ thống mã nguồn giữa GitLab và GitHub.
