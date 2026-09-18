# 🗺️ BẢN ĐỒ CẤU TRÚC DỰ ÁN & TRA CỨU NHANH (PROJECT STRUCTURE MAP)
> **Dự án**: VCloud Mobile (Flutter) & Odoo API Backend (`v_mobile`)  
> **Phiên bản chuẩn hóa**: AIaC 2026 / Build 94+  
> **Mục đích**: Bản đồ tra cứu tức thì theo từng chức năng, loại bỏ hoàn toàn việc tìm mò file thủ công (`Zero-Guessing Navigation`).

---

## 🧭 1. MA TRẬN TRA CỨU NHANH THEO CHỨC NĂNG (FEATURE MATRIX)

| Chức năng (Feature) | 📱 Frontend UI Screen & Controller (`vclients`) | ⚙️ Backend API Controller (`v_mobile_17`) | 🗄️ Odoo Model / Table | 🧪 Test File tương ứng |
| :--- | :--- | :--- | :--- | :--- |
| **💬 Chat v2 (Kênh & Nhóm)** | • `chat_v2_list_screen.dart`<br>• `chat_v2_channels_controller.dart`<br>• `chat_v2_repository.dart` | • `controllers/chat.py`<br>`GET /api/v1/mobile/chat/channels`<br>`POST /api/v1/mobile/chat/direct`<br>`POST /api/v1/mobile/chat/groups` | `mail.channel`<br>`mail.channel.member` | • `vclients/test/chat_v2_sync_status_test.dart`<br>• `v_mobile_17/tests/test_chat.py` |
| **💬 Chat v2 (Tin nhắn & Real-time)** | • `chat_v2_detail_screen.dart`<br>• `chat_v2_messages_controller.dart`<br>• `chat_v2_repository.dart` | • `controllers/chat.py`<br>`GET /api/v1/mobile/chat/channels/<id>/messages`<br>`POST /api/v1/mobile/chat/messages`<br>`POST /api/v1/mobile/chat/reaction` | `mail.message`<br>`mail.message.reaction` | • `vclients/test/chat_v2_quote_reply_test.dart`<br>• `vclients/test/chat_v2_lazy_loading_test.dart` |
| **📎 Đính kèm & Media Chat** | • `chat_attachment_sheet.dart`<br>• `chat_v2_media_gallery_screen.dart` | • `controllers/attachments.py`<br>`POST /api/v1/mobile/attachments/upload`<br>`GET /api/v1/mobile/attachments/<id>/download` | `ir.attachment` | • `vclients/test/chat_attachment_url_sanitization_test.dart`<br>• `v_mobile_17/tests/test_attachments.py` |
| **📞 Cuộc gọi WebRTC (Call v2)** | • `chat_v2_call_screen.dart`<br>• `chat_v2_call_controller.dart` | • `controllers/call.py`<br>`POST /api/v1/mobile/chat/call/initiate`<br>`POST /api/v1/mobile/chat/call/<id>/accept` | `mobile.api.call.session` | • `vclients/test/chat_v2_call_ui_test.dart`<br>• `vclients/test/call_notification_test.dart` |
| **📊 Bình chọn (Poll Voting)** | • `chat_v2_poll_bubble.dart`<br>• `chat_v2_create_poll_dialog.dart` | • `controllers/chat.py`<br>`POST /api/v1/mobile/chat/messages/<id>/poll/vote` | `mail.message` (JSON payload) | • `vclients/test/chat_v2_poll_test.dart` |
| **🕒 Chấm công (Attendance)** | • `attendance_screen.dart`<br>• `attendance_controller.dart`<br>• `attendance_repository.dart` | • `controllers/attendance.py`<br>`POST /api/v1/mobile/attendance/check-in`<br>`POST /api/v1/mobile/attendance/check-out`<br>`GET /api/v1/mobile/attendance/today` | `hr.attendance`<br>`res.company` | • `vclients/test/attendance_api_mapping_test.dart`<br>• `v_mobile_17/tests/test_attendance.py` |
| **⏱️ Nhật ký & Đếm giờ (Timesheet)** | • `timesheet_list_screen.dart`<br>• `create_entry_screen.dart`<br>• `timesheet_controller.dart` | • `controllers/timesheet.py`<br>`POST /api/v1/mobile/timesheet/log`<br>`POST /api/v1/mobile/timesheet/timer/start`<br>`GET /api/v1/mobile/timesheet/summary` | `account.analytic.line`<br>`mobile.api.timesheet.timer` | • `vclients/test/timesheet_timer_test.dart`<br>• `v_mobile_17/tests/test_timesheet.py` |
| **📋 Dự án & Nhiệm vụ (Tasks)** | • `today_tasks_section.dart`<br>• `task_controller.dart`<br>• `task_repository.dart` | • `controllers/project.py`<br>`GET /api/v1/mobile/project/list`<br>`GET /api/v1/mobile/project/all_tasks`<br>`POST /api/v1/project.task/<id>/complete` | `project.project`<br>`project.task` | • `vclients/test/task_repository_test.dart`<br>• `v_mobile_17/tests/test_project.py` |
| **🎫 Hỗ trợ Kỹ thuật (Helpdesk)** | • `ticket_list_screen.dart`<br>• `ticket_detail_screen.dart`<br>• `ticket_controller.dart` | • `controllers/ticket.py`<br>`GET /api/v1/mobile/ticket/list`<br>`POST /api/v1/mobile/ticket/create`<br>`POST /api/v1/mobile/ticket/<id>/message` | `helpdesk.ticket`<br>`helpdesk.stage` | • `vclients/test/ticket_html_mapping_test.dart`<br>• `v_mobile_17/tests/test_ticket.py` |
| **🔐 Xác thực & Token (Auth)** | • `login_screen.dart`<br>• `auth_controller.dart`<br>• `auth_repository.dart` | • `controllers/auth.py`<br>`POST /api/v1/auth/login`<br>`POST /api/v1/auth/refresh`<br>`GET /api/v1/auth/me` | `res.users`<br>`mobile.api.refresh_token` | • `vclients/test/odoo_api_client_auth_test.dart`<br>• `v_mobile_17/tests/test_auth.py` |
| **👤 Hồ sơ & Avatar (Profile)** | • `profile_screen.dart`<br>• `edit_profile_screen.dart`<br>• `profile_controller.dart` | • `controllers/avatar.py`<br>`GET /api/v1/mobile/avatar/users/<id>`<br>`POST /api/v1/mobile/avatar/upload` | `res.users`<br>`hr.employee`<br>`res.partner` | • `vclients/test/auth_avatar_mapping_test.dart`<br>• `v_mobile_17/tests/test_avatar.py` |
| **🔔 Thông báo Push (Notifications)**| • `push_notification_service.dart`<br>• `push_notification_repository.dart` | • `controllers/notifications.py`<br>`POST /api/v1/mobile/notifications/register`<br>`GET /api/v1/mobile/notifications/list` | `mobile.api.device`<br>`mobile.api.notification` | • `vclients/test/push_notification_repository_test.dart`<br>• `v_mobile_17/tests/test_device.py` |
| **🏠 Dashboard & Trang chủ** | • `home_screen.dart`<br>• `home_summary_controller.dart`<br>• `dashboard_repository.dart` | • `controllers/dashboard.py`<br>`GET /api/v1/mobile/dashboard/summary` | `hr.attendance`<br>`account.analytic.line` | • `vclients/test/home_dual_tier_metric_test.dart`<br>• `v_mobile_17/tests/test_dashboard.py` |

---

## 📁 2. CHI TIẾT CẤU TRÚC FLUTTER CLIENT (`vclients/`)
Đường dẫn: [`/media/tanma/DATA/save/mobile_versions/vclients`](file:///media/tanma/DATA/save/mobile_versions/vclients)

```text
vclients/lib/
├── app.dart                                # Root MaterialApp & GoRouter configuration
├── main.dart                               # Entrypoint ứng dụng
├── core/                                   # Tầng Hạ Tầng Cốt Lõi (Core Infrastructure)
│   ├── api/
│   │   ├── api_endpoints.dart              # Hằng số URLs và Endpoints Odoo API
│   │   ├── odoo_api_client.dart            # HTTP Client, Token Interceptor & Smart Routing
│   │   └── websocket_service.dart          # Kết nối WebSocket Odoo Bus / Realtime
│   ├── config/
│   │   ├── app_config.dart                 # Cấu hình môi trường (Dev/Staging/Production)
│   │   └── odoo_config.dart                # Database & Server Base URL
│   ├── notifications/
│   │   └── push_notification_service.dart  # Firebase Messaging (FCM) & APNs iOS Handler
│   ├── router/
│   │   └── app_router.dart                 # Định nghĩa toàn bộ Routes & Navigation Guards
│   ├── theme/                              # Apple HIG / Dark Theme Tokens
│   └── utils/                              # Formatters (Date, Currency, Error Parsers)
├── features/                               # Tầng Tính Năng (Feature-Driven Modules)
│   ├── auth/                               # Đăng nhập, Lưu trữ Token an toàn (FlutterSecureStorage)
│   ├── attendance/                         # Chấm công, Định vị Geolocation, Ca làm việc
│   ├── chat_v2/                            # Chat v2 toàn diện:
│   │   ├── application/                    # Controllers (Channels, Messages, Call, Polls, Search)
│   │   ├── data/                           # Repositories & Local Database Caching
│   │   ├── domain/                         # Chat Entities & Enums
│   │   └── presentation/                   # Screens & Widgets (ChatBubble, VoiceBubble, CallUI)
│   ├── home/                               # Dashboard tổng quan, Quick Actions
│   ├── profile/                            # Thông tin cá nhân, Đổi Theme, Đổi Avatar
│   ├── ticket/                             # Helpdesk Support Tickets
│   └── timesheet/                          # Nhật ký công việc, Timer đếm giờ
└── shared/                                 # Tầng Dùng Chung (Shared Models & UI Kit)
    ├── models/                             # DTO Models (Attendance, Timesheet, Message, Ticket...)
    └── widgets/                            # UI Components (BrandOrbitLoader, AppToast, AppScaffold...)
```

---

## ⚙️ 3. CHI TIẾT CẤU TRÚC BACKEND ODOO (`v_mobile_17/`)
Đường dẫn: [`/media/tanma/DATA/save/mobile_versions/v_mobile_17`](file:///media/tanma/DATA/save/mobile_versions/v_mobile_17)

```text
v_mobile_17/
├── __init__.py / __manifest__.py           # Khai báo Metadata Module, Dependencies & Changelogs
├── controllers/                            # Tầng Xử Lý API (REST / JSON-RPC / Streaming)
│   ├── attachments.py                      # Tải lên, tải xuống & preview file đính kèm
│   ├── attendance.py                       # Checkin/Checkout GPS, cấu hình khoảng cách
│   ├── auth.py                             # Login, Me, Token Refresh & Avatar fallback
│   ├── avatar.py                           # Cắt, nén và trả về Avatar (User, Partner, Channel)
│   ├── call.py                             # Signaling WebRTC (Initiate, Accept, ICE Candidate)
│   ├── chat.py                             # REST API Kênh chat, Tin nhắn, Reaction, Poll voting
│   ├── contacts.py                         # Tìm kiếm danh bạ nhân sự / khách hàng
│   ├── cors.py                             # Xử lý CORS Preflight OPTIONS cho Web/Mobile
│   ├── dashboard.py                        # Tổng hợp số liệu Home Dashboard (N+1 query optimized)
│   ├── notifications.py                    # Đăng ký FCM Device Token, Danh sách Notification
│   ├── project.py                          # Dự án, Nhiệm vụ (Tasks) & Đánh dấu hoàn thành
│   ├── ticket.py                           # Helpdesk Tickets, Trao đổi & SLA Stage
│   └── timesheet.py                        # Ghi log giờ làm việc, Bộ đếm giờ Timer
├── models/                                 # Tầng ORM Database & Business Logic
│   ├── api_log.py                          # Lưu vết API Request/Response để debug
│   ├── call_session.py                     # Quản lý phiên gọi thoại/video
│   ├── device.py                           # Quản trị thiết bị Push Notification (APNs/FCM)
│   ├── expose.py                           # Danh mục trường API được phép truy xuất an toàn
│   ├── ir_http_cors.py                     # Hook CORS xử lý global header
│   ├── ir_websocket.py                     # Bus websocket thông báo real-time
│   ├── notification.py                     # Lịch sử thông báo push gửi tới thiết bị
│   ├── refresh_token.py                    # Quản lý Refresh Token & chu kỳ hết hạn
│   ├── res_config_settings.py              # Cấu hình Firebase Server Key & Bật/Tắt tính năng
│   └── timesheet_timer.py                  # Trạng thái Timer đang chạy của từng User
├── security/                               # Phân quyền truy cập (ir.model.access.csv)
├── views/                                  # Giao diện quản trị Odoo Backend (XML Views)
└── tests/                                  # Bộ bài kiểm thử tự động (Unit / Integration Tests)
```

---

## 🧪 4. DANH MỤC KIỂM THỬ TỰ ĐỘNG (AUTOMATED TEST SUITE)

### A. Frontend Tests (`vclients/test/` — 45+ Bài Test)
| Nhóm Kiểm Thử | Tệp Test | Trọng Tâm Xác Minh |
| :--- | :--- | :--- |
| **Chat v2** | `chat_v2_sync_status_test.dart`<br>`chat_v2_poll_test.dart`<br>`chat_v2_call_ui_test.dart`<br>`chat_v2_quote_reply_test.dart` | Đồng bộ tin nhắn, bình chọn poll, render cuộc gọi và trích dẫn tin |
| **Media & File** | `chat_attachment_url_sanitization_test.dart`<br>`document_attachment_download_test.dart` | Làm sạch URL đính kèm, tải file không bị crash bộ nhớ |
| **API & Routing**| `odoo_api_client_smart_routing_test.dart`<br>`odoo_api_client_auth_test.dart` | Điều hướng thông minh giữa Odoo Cloud & Local, Interceptor Token |
| **Timesheet** | `timesheet_timer_test.dart`<br>`timesheet_repository_test.dart` | Khởi động/dừng Timer, tính toán tổng số giờ chính xác |
| **Chấm công** | `attendance_api_mapping_test.dart`<br>`shift_config_api_test.dart` | Parse dữ liệu ca làm việc, tọa độ GPS và bán kính hợp lệ |
| **Dashboard** | `home_dual_tier_metric_test.dart`<br>`home_load_performance_benchmark_test.dart` | Hiển thị 2 tầng chỉ số, tải dữ liệu dưới 500ms |

### B. Backend Tests (`v_mobile_17/tests/` — 20+ Bài Test)
| Nhóm Kiểm Thử | Tệp Test | Trọng Tâm Xác Minh |
| :--- | :--- | :--- |
| **Bảo mật & ACL** | `test_attachment_security_contract.py`<br>`test_auth.py` | Quyền truy cập file nhạy cảm, chặn giả mạo User ID |
| **Chat Backend** | `test_chat.py`<br>`test_chat_unread_and_last_message_contract.py` | Tính toán số tin chưa đọc, cập nhật tin nhắn cuối cùng |
| **Hiệu năng & SLA**| `test_performance_sla_benchmark.py`<br>`test_dashboard.py` | Tối ưu hóa truy vấn SQL Batch, tránh lỗi N+1 |
| **Thiết bị & FCM** | `test_device.py`<br>`test_notification_matrix.py` | Đăng ký Device Token, xử lý lỗi token hết hạn |

---

## 🛠️ 5. BỘ CÔNG CỤ & KỊCH BẢN TỰ ĐỘNG HÓA (`scripts/` & `tools/`)

* **Khởi chạy Môi Trường Phát Triển & Web (Local Dev & Testing)**:
  * [`vclients/launch_web.sh`](file:///media/tanma/DATA/save/mobile_versions/vclients/launch_web.sh): Tự khởi động Odoo 17 Docker (`dev_env/17.0`) & chạy Flutter Web (Port 8088, Odoo 17).
  * [`vclients/launch_web_19.sh`](file:///media/tanma/DATA/save/mobile_versions/vclients/launch_web_19.sh): Tự khởi động Odoo 19 Docker (`dev_env/19.0`) & chạy Flutter Web (Port 8088, Odoo 19).
  * [`vclients/update_backend.sh`](file:///media/tanma/DATA/save/mobile_versions/vclients/update_backend.sh): Nạp nhanh code mới & Upgrade Backend Odoo 17/19 mà không cần tắt Flutter Web.
  * [`vclients/launch_web_prod.sh`](file:///media/tanma/DATA/save/mobile_versions/vclients/launch_web_prod.sh): Chạy Flutter Web trỏ trực tiếp Production/Staging server.
* **Quản trị Push Notification**:
  * [`scripts/push_notification_manager.py`](file:///media/tanma/DATA/save/mobile_versions/scripts/push_notification_manager.py): Gửi push notification test trực tiếp đến FCM/APNs.
  * [`scripts/diagnose_user_notifications.py`](file:///media/tanma/DATA/save/mobile_versions/scripts/diagnose_user_notifications.py): Kiểm tra trạng thái thiết bị của từng nhân sự.
* **Kiểm thử Hiệu năng & Tải**:
  * [`tools/benchmark_home_apis.py`](file:///media/tanma/DATA/save/mobile_versions/tools/benchmark_home_apis.py): Đo lường độ trễ (latency) của các API màn hình Home.
  * [`tools/testing/spam_demo_chat.py`](file:///media/tanma/DATA/save/mobile_versions/tools/testing/spam_demo_chat.py): Bắn tải tin nhắn liên tục để kiểm tra độ mượt UI.
* **Đồng bộ Dữ liệu Odoo**:
  * [`scripts/odoo_task_manager.py`](file:///media/tanma/DATA/save/mobile_versions/scripts/odoo_task_manager.py): Tương tác trực tiếp với Task Odoo qua XML-RPC.
* **Sơ đồ Kiến trúc, UML Activity Diagram & Sequence Diagram (Thư mục tập trung: `docs/diagrams/`)**:
  * [`docs/diagrams/README.md`](file:///media/tanma/DATA/save/mobile_versions/docs/diagrams/README.md): Bản đồ tổng quan toàn bộ sơ đồ hệ thống Vcloud & vmobile theo từng phân hệ chức năng.
  * **Master Directory Hub & Đồng bộ Tenant (`docs/diagrams/master_sync/`)**:
    * [`docs/diagrams/master_sync/MASTER_SEQUENCE_DIAGRAM.png`](file:///media/tanma/DATA/save/mobile_versions/docs/diagrams/master_sync/MASTER_SEQUENCE_DIAGRAM.png): Biểu đồ trình tự UML độc lập sắc nét (3646 x 1588 px), 18 bước rõ ràng qua 3 giai đoạn.
    * [`docs/diagrams/master_sync/MASTER_SEQUENCE_DIAGRAM.svg`](file:///media/tanma/DATA/save/mobile_versions/docs/diagrams/master_sync/MASTER_SEQUENCE_DIAGRAM.svg) | [`.html`](file:///media/tanma/DATA/save/mobile_versions/docs/diagrams/master_sync/MASTER_SEQUENCE_DIAGRAM.html) | [`.drawio`](file:///media/tanma/DATA/save/mobile_versions/docs/diagrams/master_sync/MASTER_SEQUENCE_DIAGRAM.drawio)
    * [`docs/diagrams/master_sync/MASTER_DIRECTORY_SYNC_WORKFLOW.png`](file:///media/tanma/DATA/save/mobile_versions/docs/diagrams/master_sync/MASTER_DIRECTORY_SYNC_WORKFLOW.png): Ảnh Raster PNG tĩnh độ phân giải cao (1800 x 4200 px).
    * [`docs/diagrams/master_sync/MASTER_DIRECTORY_SYNC_WORKFLOW.svg`](file:///media/tanma/DATA/save/mobile_versions/docs/diagrams/master_sync/MASTER_DIRECTORY_SYNC_WORKFLOW.svg) | [`.html`](file:///media/tanma/DATA/save/mobile_versions/docs/diagrams/master_sync/MASTER_DIRECTORY_SYNC_WORKFLOW.html) | [`.drawio`](file:///media/tanma/DATA/save/mobile_versions/docs/diagrams/master_sync/MASTER_DIRECTORY_SYNC_WORKFLOW.drawio)
    * [`docs/diagrams/master_sync/WORKFLOW_AUTOMATION_DIAGRAM.html`](file:///media/tanma/DATA/save/mobile_versions/docs/diagrams/master_sync/WORKFLOW_AUTOMATION_DIAGRAM.html) | [`.drawio`](file:///media/tanma/DATA/save/mobile_versions/docs/diagrams/master_sync/WORKFLOW_USER_SYNC_AUTOMATION.drawio)
  * **Đăng nhập & Phân quyền Role (`docs/diagrams/login_auth/`)**:
    * [`docs/diagrams/login_auth/ACTIVITY_DIAGRAM_LOGIN_AUTH.png`](file:///media/tanma/DATA/save/mobile_versions/docs/diagrams/login_auth/ACTIVITY_DIAGRAM_LOGIN_AUTH.png): Sơ đồ UML Activity Diagram toàn diện 3 giai đoạn (1680 x 3833 px).
    * [`docs/diagrams/login_auth/ACTIVITY_DIAGRAM_LOGIN_AUTH.svg`](file:///media/tanma/DATA/save/mobile_versions/docs/diagrams/login_auth/ACTIVITY_DIAGRAM_LOGIN_AUTH.svg) | [`.html`](file:///media/tanma/DATA/save/mobile_versions/docs/diagrams/login_auth/ACTIVITY_DIAGRAM_LOGIN_AUTH.html) | [`.drawio`](file:///media/tanma/DATA/save/mobile_versions/docs/diagrams/login_auth/ACTIVITY_DIAGRAM_LOGIN_AUTH.drawio)
  * **Chấm công & Điểm danh (`docs/diagrams/attendance/`)**:
    * [`docs/diagrams/attendance/diagram_attendance_activity.png`](file:///media/tanma/DATA/save/mobile_versions/docs/diagrams/attendance/diagram_attendance_activity.png): Sơ đồ luồng chấm công vào/ra và quét ca động `resource.calendar`.
    * [`docs/diagrams/attendance/diagram_attendance.html`](file:///media/tanma/DATA/save/mobile_versions/docs/diagrams/attendance/diagram_attendance.html): Bản vẽ HTML Mermaid tương tác.
  * **Nhắn tin Chat V2 (`docs/diagrams/chat/`)**:
    * [`docs/diagrams/chat/diagram_chat_activity.png`](file:///media/tanma/DATA/save/mobile_versions/docs/diagrams/chat/diagram_chat_activity.png): Sơ đồ luồng gửi nhận tin nhắn, đính kèm nhiều ảnh và websocket.
    * [`docs/diagrams/chat/diagram_chat.html`](file:///media/tanma/DATA/save/mobile_versions/docs/diagrams/chat/diagram_chat.html): Bản vẽ HTML tương tác.
  * **Push Notification Gateway (`docs/diagrams/push_gateway/`)**:
    * [`docs/diagrams/push_gateway/push_gateway_activity_diagram.html`](file:///media/tanma/DATA/save/mobile_versions/docs/diagrams/push_gateway/push_gateway_activity_diagram.html): Sơ đồ điều phối Gateway 2 chế độ Local Tenant vs Master SaaS.

---

## 🚀 6. NGUYÊN TẮC ĐIỀU HƯỚNG 3 BƯỚC (QUY TẮC CHỐNG MÒ FILE)

Khi cần phát triển hoặc sửa lỗi một tính năng bất kỳ, **BẮT BUỘC** thực hiện theo 3 bước:

1. **Bước 1 (Tra cứu Ma Trận)**: Tìm tên tính năng trong **Bảng 1 (Ma trận Tra Cứu Nhanh)** để lấy chính xác đường dẫn File Frontend, API Route và Model Backend.
2. **Bước 2 (Mở Đích Danh)**: Chỉ mở (`Read`) đúng các file đã được xác định trong ma trận. Không quét tuần tự toàn bộ thư mục `lib/` hay `controllers/`.
3. **Bước 3 (Chạy Test Tương Ứng)**: Sau khi chỉnh sửa, chạy đúng bài test được liệt kê tại **Bảng 4** để kiểm chứng trước khi commit.

---

## 🗄️ 7. DANH MỤC CƠ SỞ DỮ LIỆU LOCAL & LOCAL SERVER (DATABASE MATRIX)

### A. Môi trường Local Server nội bộ (`192.168.1.100` — Môi trường chuẩn chính thức)
Hạ tầng Docker tập trung trên Server nội bộ (`ssh local` - `/mnt/DATA/dev/`):
- **Odoo 17.0 (`odoo_dev_v17`)**: HTTP Port **`1700`** (Longpolling: `1772`, DB: `odoo_dev_v17_db` port `1732`).
- **Odoo 19.0 (`odoo_dev_v19`)**: HTTP Port **`1900`** (Longpolling: `1972`, DB: `odoo_dev_v19_db` port `1932`).

### B. Môi trường Standalone trên Máy trạm cá nhân (Docker Dev Env tại máy Mac/Laptop)
Dùng khi phát triển cô lập hoặc offline tại chỗ (`/media/tanma/DATA/save/dev_env/`):

| Cụm / Phiên bản | Tên Database | Mục đích sử dụng | Tên Công ty trong DB | Backend API Port | Tài khoản Trùng (Test Dropdown) | Tài khoản Độc Quyền (Không hiện Dropdown) |
| :---: | :--- | :--- | :--- | :---: | :--- | :--- |
| **Odoo 17.0** | **`demo-17`** | 🏢 **DB Nội Bộ (Internal)** | `360 Nội Bộ (Internal Company)` | Port **`8069`** (Local Server: **`1700`**) | `demo` / `demo`<br>`admin` / `admin` | 👤 `staff_internal` / `internal_pass_17` |
| **Odoo 17.0** | **`vcloud-17-client`** | 👥 **DB Khách Hàng (Customer)** | `360 Khách Hàng (Customer Company)` | Port **`8069`** (Local Server: **`1700`**) | `demo` / `demo`<br>`admin` / `admin` | 👤 `client_user` / `client_pass_17` |
| **Odoo 19.0** | **`demo-19`** | 🚀 **DB Odoo 19 (Mô phỏng demo.vuahethong.com)** | `360 CORP` | Port **`8079`** (Local Server: **`1900`**) | `demo` / `demo` | 👤 `odoo19_user` / `demo` |
