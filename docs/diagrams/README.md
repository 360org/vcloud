# SƠ ĐỒ HỆ THỐNG VCLOUD & VMOBILE (DIAGRAMS DIRECTORY)

> Thư mục lưu trữ tập trung và phân loại toàn bộ sơ đồ kiến trúc, luồng hoạt động (Activity/Sequence Diagrams) dưới các định dạng: **PNG** (ảnh nét cao), **SVG** (vector zoom vô hạn), **HTML** (giao diện web tương tác) và **Draw.io** (file nguồn kéo thả).

---

## 📂 Danh mục Sơ đồ theo Chức năng

### 1. Phân hệ Đăng nhập & Xác thực (`diagrams/login_auth/`)
Sơ đồ UML Activity Diagram toàn diện 3 giai đoạn: Webhook tạo user ➔ Mobile Auth ➔ Phân quyền Role Odoo.
- [`ACTIVITY_DIAGRAM_LOGIN_AUTH.png`](login_auth/ACTIVITY_DIAGRAM_LOGIN_AUTH.png): Ảnh nét cao 1680 x 3833 px.
- [`ACTIVITY_DIAGRAM_LOGIN_AUTH.svg`](login_auth/ACTIVITY_DIAGRAM_LOGIN_AUTH.svg): File vector phóng to vô hạn.
- [`ACTIVITY_DIAGRAM_LOGIN_AUTH.html`](login_auth/ACTIVITY_DIAGRAM_LOGIN_AUTH.html): Bản vẽ trực quan HTML tương tác.
- [`ACTIVITY_DIAGRAM_LOGIN_AUTH.drawio`](login_auth/ACTIVITY_DIAGRAM_LOGIN_AUTH.drawio): File nguồn XML chỉnh sửa trên draw.io.

### 2. Phân hệ Master Directory Hub & Đồng bộ Tenant (`diagrams/master_sync/`)
Sơ đồ hoạt động và tuần tự của Master Hub Odoo 17 định tuyến đa DB và quản lý `databases.user`.
- **Master Directory Sync Workflow**:
  - [`MASTER_DIRECTORY_SYNC_WORKFLOW.png`](master_sync/MASTER_DIRECTORY_SYNC_WORKFLOW.png) | [`svg`](master_sync/MASTER_DIRECTORY_SYNC_WORKFLOW.svg) | [`html`](master_sync/MASTER_DIRECTORY_SYNC_WORKFLOW.html) | [`drawio`](master_sync/MASTER_DIRECTORY_SYNC_WORKFLOW.drawio)
- **Master Sequence Diagram (18 Bước 3 Giai đoạn)**:
  - [`MASTER_SEQUENCE_DIAGRAM.png`](master_sync/MASTER_SEQUENCE_DIAGRAM.png) | [`svg`](master_sync/MASTER_SEQUENCE_DIAGRAM.svg) | [`html`](master_sync/MASTER_SEQUENCE_DIAGRAM.html) | [`drawio`](master_sync/MASTER_SEQUENCE_DIAGRAM.drawio)
- **Workflow User Sync Automation**:
  - [`WORKFLOW_AUTOMATION_DIAGRAM.html`](master_sync/WORKFLOW_AUTOMATION_DIAGRAM.html) | [`WORKFLOW_USER_SYNC_AUTOMATION.drawio`](master_sync/WORKFLOW_USER_SYNC_AUTOMATION.drawio)

### 3. Phân hệ Chấm công & Nhắc việc (`diagrams/attendance/`)
Sơ đồ luồng chấm công vào/ra (Check-in/Check-out), quét ca động `resource.calendar`, kiểm tra nghỉ lễ và định tuyến Cron nhắc nhở.
- [`diagram_attendance_activity.png`](attendance/diagram_attendance_activity.png): Sơ đồ hoạt động chấm công tổng thể.
- [`diagram_attendance.html`](attendance/diagram_attendance.html): Bản vẽ HTML Mermaid có thanh zoom/pan.

### 4. Phân hệ Nhắn tin & Trao đổi Chat (`diagrams/chat/`)
Sơ đồ vòng đời tin nhắn Chat V2, đính kèm đa phương tiện, xử lý websocket và đồng bộ tin nhắn chưa đọc.
- [`diagram_chat_activity.png`](chat/diagram_chat_activity.png): Sơ đồ luồng hoạt động Chat V2.
- [`diagram_chat.html`](chat/diagram_chat.html): Bản vẽ HTML tương tác.

### 5. Phân hệ Push Notification Gateway (`diagrams/push_gateway/`)
Sơ đồ định tuyến thông báo đẩy hai chế độ (Local Tenant FCM vs Master SaaS Gateway), cơ chế Idempotency và phân phối đa thiết bị.
- [`push_gateway_activity_diagram.html`](push_gateway/push_gateway_activity_diagram.html): Sơ đồ tương tác HTML bộ điều phối Push Gateway.
- [`push_gateway_activity_diagram.md`](push_gateway/push_gateway_activity_diagram.md): Tài liệu đặc tả luồng đi kèm sơ đồ.

### 6. Bộ công cụ Render Tự động (`diagrams/scripts/`)
- [`render.js`](scripts/render.js): Script Puppeteer tự động render sơ đồ HTML Mermaid thành ảnh PNG độ nét cao.
