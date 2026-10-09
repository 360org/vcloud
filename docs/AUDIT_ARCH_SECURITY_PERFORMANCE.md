# BÁO CÁO AUDIT KIẾN TRÚC, BẢO MẬT & HIỆU NĂNG CHỊU TẢI
**Hệ thống**: VCloud Mobile Ecosystem (`vclients`, `v_mobile_19`, `v_mobile_17`)  
**Ngày thực hiện**: 2026-10-09  
**Người thực hiện**: Chief System Architect & Security/Performance Auditor  
**Chế độ**: Strict Read-Only Audit (Protocol v6.0 / Evidence-First)  

---

## I. TỔNG QUAN KẾT QUẢ AUDIT
Rà soát toàn diện mã nguồn Flutter Client và Odoo Addons trên 3 trụ cột Kỹ thuật. Đã phát hiện và lập danh mục:
- **1 Lỗ hổng Critical**: Hardcoded cluster secret fallback trong Odoo 17.
- **5 Điểm nghẽn / Lỗ hổng High**: IDOR bypass ticket không có partner_id, rò rỉ internal notes qua chatter, spoofing partner_id khi tạo ticket, N+1 query loop trong notification dispatch, và thiếu `_sql_indexes` trên Odoo 19.
- **4 Điểm kiến trúc / hiệu năng Medium**: Router guard thiếu chặn attendance cho portal, presentation gọi API trực tiếp, information disclosure danh bạ nhân viên, và N+1 relation trong project list.

---

## II. CHI TIẾT 3 TRỤ CỘT KIỂM TOÁN

### 1. 🏗️ CẤU TRÚC HỆ THỐNG (ARCHITECTURE & CLEAN CODE)

#### ARCH-01: Router Guard thiếu chặn Portal truy cập Chấm công (Attendance)
- **Vị trí**: `vclients/lib/core/router/app_router.dart:120`
- **Mức độ**: `MEDIUM`
- **Hiện tượng**: `app_router.dart` chỉ chặn Timesheet cho Portal user (`if (user.isPortal && loc.startsWith('/timesheet')) return '/home';`). Đối với Attendance, router chỉ kiểm tra `if (!user.hasAttendance && ...)`. Nếu tenant có cài `hr_attendance`, Portal user vẫn có thể chuyển hướng hoặc deep-link vào `/attendance`. Màn hình Attendance vẫn mount và gửi HTTP request đến Odoo trước khi bị backend trả 403.
- **Khắc phục**: Bổ sung điều kiện chặn trực tiếp trong Router Guard:
  ```dart
  if (user.isPortal && (loc == '/attendance' || loc.startsWith('/attendance'))) {
    return '/home';
  }
  ```

#### ARCH-02: Vi phạm Clean Architecture - Presentation Layer gọi trực tiếp API & Session
- **Vị trí**: 
  - `vclients/lib/features/chat_v2/presentation/screens/chat_v2_video_player_screen.dart:148`
  - `vclients/lib/features/chat_v2/presentation/screens/chat_v2_image_viewer_screen.dart:336`
  - `vclients/lib/features/ticket/presentation/ticket_detail_screen.dart:1808`
- **Mức độ**: `MEDIUM`
- **Hiện tượng**: Các widget màn hình trực tiếp gọi `odooApiClient.fetchBytes(...)`, đọc `odooApiClient.session?.uid` và trích xuất raw headers thay vì thông qua Data Repository (`features/<module>/data/*_repository.dart`).
- **Khắc phục**: Đưa các logic tải nhị phân / media cache về `AttachmentRepository` và expose qua Riverpod Controller.

#### ARCH-03: Thiếu Portal Guard đồng nhất trên Project Tasks API
- **Vị trí**: `v_mobile_19/controllers/project.py:91`, `v_mobile_17/controllers/project.py:91`
- **Mức độ**: `LOW`
- **Hiện tượng**: Các endpoint `/api/v1/mobile/project/list` và `/api/v1/mobile/project/all_tasks` không kiểm tra `deny_portal(uid)` như `attendance.py` và `timesheet.py`. Portal user có thể gọi API này để xem danh sách dự án.
- **Khắc phục**: Khai báo `deny_portal(uid)` hoặc bổ sung explicit domain filter cho portal user.

---

### 2. 🛡️ BẢO MẬT (OWASP & DATA PROTECTION)

#### SEC-01: Hardcoded Cluster Secret Fallback trong Odoo 17 Master Sync
- **Vị trí**: `v_mobile_17/controllers/auth.py:1414-1418` & `v_mobile_17/models/res_users.py:23`
- **Mức độ**: `CRITICAL`
- **Hiện tượng**: Trong Odoo 17, nếu `vmobile.master_sync_secret` chưa được cấu hình, hệ thống tự động fallback về chuỗi mặc định `default_cluster_sec = "360org-vcloud-cluster-mesh-sec-2026"`. Kẻ tấn công trên cùng mạng nội bộ có thể gửi webhook Bearer Token giả mạo để soft-revoke tài khoản hoặc thao túng Master Directory.
- **Khắc phục**: Xóa bỏ hoàn toàn giá trị fallback, chuyển sang cơ chế fail-closed (từ chối xác thực nếu secret chưa được cấu hình trong `ir.config_parameter`).

#### SEC-02: Bypass IDOR Quyền Sở Hữu Ticket khi `partner_id` Trống
- **Vị trí**: `v_mobile_19/controllers/ticket.py:269-270` & `v_mobile_19/controllers/ticket.py:574`
- **Mức độ**: `HIGH`
- **Hiện tượng**: Logic kiểm tra:
  ```python
  if (_user.share or not _user.has_group("base.group_user")) and ticket.partner_id and ticket.partner_id.id != _user.partner_id.id:
      return _cors_response(_json_resp({"error": "forbidden"}, 403))
  ```
  Nếu ticket chưa được gán đối tác (`ticket.partner_id == False`), mệnh đề `ticket.partner_id and ...` trả về `False`, khiến điều kiện chặn 403 bị bỏ qua. Tài khoản Portal có thể đọc chi tiết và gửi tin nhắn vào ticket unassigned của hệ thống.
- **Khắc phục**: Sửa điều kiện thành:
  ```python
  if (_user.share or not _user.has_group("base.group_user")) and (not ticket.partner_id or ticket.partner_id.id != _user.partner_id.id):
  ```

#### SEC-03: Rò Rỉ Ghi Chú Nội Bộ (Internal Notes Leakage) Cho Portal User
- **Vị trí**: `v_mobile_19/controllers/ticket.py:273-295`
- **Mức độ**: `HIGH`
- **Hiện tượng**: Trong `ticket_detail`, truy vấn lấy tin nhắn bằng `Message = request.env["mail.message"].with_user(uid).sudo()` không lọc bỏ các tin nhắn ghi chú nội bộ (`is_internal=True`). Portal user có thể đọc toàn bộ ghi chú nội bộ của nhân viên CSKH khi xem chi tiết ticket.
- **Khắc phục**: Thêm điều kiện lọc `is_internal = False` khi người gọi là Portal user:
  ```python
  domain = [("model", "=", "helpdesk.ticket"), ("res_id", "=", ticket_id)]
  if _user.share:
      domain.append(("is_internal", "=", False))
  ```

#### SEC-04: Giả Mạo `partner_id` Khi Tạo Ticket Mới (Partner Impersonation)
- **Vị trí**: `v_mobile_19/controllers/ticket.py:456-460`
- **Mức độ**: `HIGH`
- **Hiện tượng**: `ticket_create` nhận `partner_id` trực tiếp từ payload `values.get("partner_id")`. Portal user có thể truyền `partner_id` của một doanh nghiệp khác để tạo ticket giả mạo danh tính.
- **Khắc phục**: Nếu `_user.share == True`, luôn ép buộc `partner_id = _user.partner_id.id` và bỏ qua giá trị truyền lên từ client.

#### SEC-05: Lộ Danh Bạ Nhân Viên Nội Bộ (Employee Enumeration)
- **Vị trí**: `v_mobile_19/controllers/ticket.py:821`
- **Mức độ**: `MEDIUM`
- **Hiện tượng**: Endpoint `/api/v1/mobile/ticket/assignees` trả về danh sách 100 nhân viên nội bộ kèm email và avatar mà không kiểm tra `deny_portal(uid)`.
- **Khắc phục**: Thêm `deny_portal(uid)` để chỉ cho phép nhân viên nội bộ truy cập.

---

### 3. ⚡ HIỆU NĂNG & KHẢ NĂNG CHỊU TẢI (PERFORMANCE & STRESS)

#### PERF-01: N+1 SQL Queries Khi Dispatch Push Notification
- **Vị trí**: `v_mobile_19/models/notification.py:193-201`
- **Mức độ**: `HIGH`
- **Hiện tượng**: Vòng lặp duyệt thiết bị `for device in devices:` thực hiện câu truy vấn `self.sudo().search([("idempotency_key", "=", ikey), ...], limit=1)` cho từng thiết bị riêng lẻ. Với nhóm chat lớn (200 thiết bị), ORM thực hiện 200 câu truy vấn SELECT tuần tự.
- **Khắc phục**: Gom danh sách key cần kiểm tra và thực hiện một truy vấn batch duy nhất:
  ```python
  all_keys = [f"{event_type}_{event_uid}_{d.id}" for d in devices if event_uid]
  existing_keys = set(self.sudo().search([("idempotency_key", "in", all_keys), ("status", "in", ("pending", "sending", "sent"))]).mapped("idempotency_key"))
  ```

#### PERF-02: Thiếu `_sql_indexes` Trên Odoo 19 Gây Sequential Scan
- **Vị trí**: `v_mobile_19/models/notification.py:105`, `v_mobile_19/models/device.py:28`
- **Mức độ**: `HIGH`
- **Hiện tượng**: Trong Odoo 19, `index=True` trên field definitions bị deprecate và không tự động sinh index DB. Cần khai báo qua `_sql_indexes = (models.Index(...),)`. Bảng `mobile_api_notification` và `mobile_api_device` thiếu composite index trên `(idempotency_key, status)` và `(user_id, active)`, dẫn đến Full Table Scan khi lượng log thông báo tăng cao.
- **Khắc phục**: Khai báo `_sql_indexes` rõ ràng trên các model Odoo 19 theo chuẩn Ponytail.

#### PERF-03: N+1 Relation Traversal Trong Project List
- **Vị trí**: `v_mobile_19/controllers/project.py:118`
- **Mức độ**: `MEDIUM`
- **Hiện tượng**: Thuộc tính `task_count: len(p.task_ids)` trong vòng lặp `for p in projects:` kích hoạt N truy vấn con cho quan hệ tasks của từng dự án.
- **Khắc phục**: Dùng `read_group` hoặc truy vấn raw SQL `GROUP BY project_id` để đếm số lượng task trong 1 truy vấn duy nhất.

---

## III. KẾT LUẬN & ĐỀ XUẤT LỘ TRÌNH NÂNG CẤP
- **Tổng số phát hiện**: 1 Critical, 5 High, 4 Medium.
- **Đánh giá**: Hệ thống có nền tảng phân tầng tốt, cơ chế State Reset 4 lớp khi Logout hoạt động chuẩn xác, tuy nhiên **CHƯA ĐẠT TIÊU CHUẨN VẬN HÀNH CHỊU TẢI & BẢO MẬT TUYỆT ĐỐI** nếu chưa xử lý dứt điểm các lỗ hổng IDOR/Data Leak trên Portal và N+1 queries trong Push Notification.
- **Lộ trình đề xuất**: Đóng gói thành bản vá **Sprint v19.0.1.2.32 & v2.9.17+155** để xử lý toàn diện 10 mục trên.
