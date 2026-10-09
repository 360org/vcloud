# 📊 BÁO CÁO AUDIT RÀ SOÁT TÍNH NĂNG PHÂN HỆ HELPDESK TICKET
**Target Repositories**: `vclients` (Flutter), `v_mobile_19` (Odoo 19), `v_mobile_17` (Odoo 17)  
**Tài liệu tham chiếu SSOT**: `docs/features.md` (Nhóm 5: Ticket / Helpdesk & SLA)  
**Ngày thực hiện**: 2026-10-09  
**Người thực hiện**: Principal QA Lead & Helpdesk Auditor (Như)  
**Chế độ**: STRICT READ-ONLY INSPECTION & AUDIT (Không sửa code, không đổi database)  

---

## I. TỔNG QUAN KẾT QUẢ RÀ SOÁT 5 HẠNG MỤC

| STT | Hạng Mục Rà Soát | Vị Trí File Code & Dòng | Kết Quả Rà Soát Thực Tế | Mức Độ |
| :---: | :--- | :--- | :--- | :---: |
| 1 | Lệch tác giả khi Nhận Ticket | `v_mobile_17/controllers/ticket.py:285-288, 982-996`<br>`v_mobile_19/controllers/ticket.py:289-292, 994-1008`<br>`vclients/lib/features/ticket/presentation/ticket_detail_screen.dart:1434-1436, 1500-1503` | Backend không ghi `message_post` khi nhận ticket mà chỉ update `user_id`. Tracking message có `body` rỗng bị backend ép thành `"{author_name} đã tạo ticket này"`. Ngoài ra Flutter so sánh lệch ID giữa `res.users` (uid) và `res.partner` (partner_id). | **[BUG - HIGH]** |
| 2 | Đính kèm media trong Chatter & Ghi chú nội bộ | `vclients/lib/features/ticket/presentation/ticket_detail_screen.dart:1524-1616`<br>`vclients/lib/features/ticket/data/ticket_comment_repository.dart:67-71`<br>`v_mobile_17/controllers/ticket.py:591-596`<br>`v_mobile_19/controllers/ticket.py:598-603` | `_CommentComposer` thiếu hoàn toàn nút chọn/chụp ảnh; repo không truyền `attachment_ids`. Backend nhận `attachment_ids` nhưng hardcode `subtype_id = mail.mt_comment`, hoàn toàn thiếu tham số `is_internal` (`mail.mt_note`). | **[GAP - MED]** |
| 3 | Chọn Partner & SLA Deadline khi Tạo Ticket | `vclients/lib/features/ticket/presentation/create_ticket_screen.dart:30-180`<br>`vclients/lib/features/ticket/data/ticket_repository.dart:133-152`<br>`v_mobile_17/controllers/ticket.py:476-495`<br>`v_mobile_19/controllers/ticket.py:481-500` | Form tạo ticket thiếu trường chọn Khách hàng (`partner_id`) cho Internal User và thiếu trường chọn Hạn cam kết SLA (`date_deadline`). Backend `ticket_create` có nhận `partner_id` nhưng thiếu trường `date_deadline`. | **[GAP - LOW]** |
| 4 | Infinite Scroll & Tìm kiếm Database | `vclients/lib/features/ticket/presentation/ticket_list_screen.dart:40-57, 132-138, 463-479`<br>`vclients/lib/features/ticket/data/ticket_repository.dart:66-71`<br>`v_mobile_17/controllers/ticket.py:100-132`<br>`v_mobile_19/controllers/ticket.py:100-132` | Khởi tạo không truyền limit nên backend ép trần cứng 20 ticket. Giao diện thiếu `ScrollController` listener tải thêm (không có Infinite Scroll). Ô Search lọc 100% trên RAM cục bộ (trong 20 bản ghi), không query API xuống DB Odoo. | **[GAP - MED]** |
| 5 | Đối soát 14 Tính Năng Nhóm 5 (`features.md`) | `docs/features.md:1063-1190`<br>`vclients/docs/features.md:1063-1190` | 10/14 tính năng đạt chuẩn VERIFIED (5.3, 5.4, 5.6, 5.7, 5.9, 5.10, 5.11, 5.12, 5.13, 5.14). 3/14 tính năng tồn đọng GAP/BUG (5.1, 5.2, 5.5). 1 tính năng đã bỏ qua theo chỉ đạo của Sếp Tân (5.8 CSAT). | **[GAP - MED]** |

---

## II. CHI TIẾT TRUY VẾT & NGUYÊN NHÂN GỐC RỄ (ROOT CAUSE ANALYSIS)

### 1. Hạng Mục 1: Lỗi Tác Giả Chatter khi Nhận Ticket (BUG - HIGH)

#### A. Luồng Thực Thi Hiện Tại
1. **Phía Flutter Mobile**:
   - Khi người dùng bấm nút **"Nhận ticket"** (`ticket_detail_screen.dart:654-657`), controller gọi:
     `ref.read(ticketActionsProvider).updateStatus(widget.ticketId, TicketStatus.doing)`
   - `TicketRepository.updateStatus()` (`ticket_repository.dart:212-218`) gửi request:
     `POST /api/v1/mobile/ticket/<id>/workflow` với body `{"status": "in_progress"}` (hoặc `doing`).
2. **Phía Backend Odoo** (`v_mobile_17/controllers/ticket.py:982-996` và `v_mobile_19/controllers/ticket.py:994-1008`):
   - Controller tìm ticket bằng quyền `.sudo()`:
     ```python
     elif status in ("in_progress", "doing", "take"):
         if not ticket.user_id or ticket.user_id.id != user.id:
             vals["user_id"] = user.id
         ...
         ticket.write(vals)
     ```
   - **Lỗi 1 (Thiếu log message)**: Backend chỉ gọi `ticket.write(vals)` mà **không hề gọi `ticket.message_post(...)`**. Khi `write()` chạy, Odoo core chỉ tạo 1 bản ghi tracking ngầm trong `mail.message` với trường `body = False` (rỗng) và lưu thay đổi vào `tracking_value_ids`.
   - **Lỗi 2 (Hardcode sai nội dung tin nhắn rỗng)**:
     Tại endpoint `ticket_detail` (`v_mobile_17:285-288` & `v_mobile_19:289-292`):
     ```python
     for msg in messages:
         body_str = (msg.body or "").strip()
         if not body_str or body_str in ("<p></p>", "<p><br></p>", "<p>&nbsp;</p>"):
             author_name = msg.author_id.name if msg.author_id else "Người dùng"
             body_str = f"<p><strong>{author_name}</strong> đã tạo ticket này.</p>"
     ```
     Bất kỳ tin nhắn tracking nào có body rỗng đều bị backend ép cứng thành: `"<strong>{author_name}</strong> đã tạo ticket này"`.
   - **Lỗi 3 (Lệch ID User vs Partner trên Flutter)**:
     Tại `ticket_detail_screen.dart`:
     ```dart
     // Dòng 49:
     _myId = ref.read(authControllerProvider).value?.id ?? ''; // ID của res.users (session.uid)

     // Dòng 1434 (class _CommentCard):
     final isMe = comment.authorId == myId; // BUG: comment.authorId là ID của res.partner (mail.message.author_id)
     final name = comment.authorName ?? (isMe ? 'Bạn' : 'Người dùng');
     ```
     Vì `res.users.id != res.partner.id` (ví dụ User ID là 2, Partner ID là 3), `isMe` luôn trả về `false`.
   - **Lỗi 4 (Fallback giao diện)**:
     Tại `ticket_detail_screen.dart:1500-1503`:
     ```dart
     final displayContent = rawContent.isNotEmpty
         ? rawContent
         : '$name đã tạo ticket này.';
     ```
     Nếu comment content rỗng, giao diện lại tiếp tục hiển thị `$name đã tạo ticket này.`.

---

### 2. Hạng Mục 2: Rà Soát Đính Kèm File/Ảnh & Ghi Chú Nội Bộ Trong Chatter (GAP - MED)

#### A. Phía Flutter (`_CommentComposer`)
- **Vị trí**: `vclients/lib/features/ticket/presentation/ticket_detail_screen.dart:1524-1616`.
- **Thực trạng**: Widget chỉ chứa duy nhất `TextField` và 1 icon button `LucideIcons.send`.
  - Không có nút chọn ảnh từ Thư viện (`ImagePicker(source: gallery)`).
  - Không có nút chụp ảnh từ Camera (`ImagePicker(source: camera)`).
  - Không có nút đính kèm tệp tài liệu (`FilePicker`).
  - Không có toggle chuyển đổi giữa **"Phản hồi khách hàng"** (`mt_comment`) và **"Ghi chú nội bộ"** (`mt_note`).
- **Data Layer** (`ticket_comment_repository.dart:67-71`):
  Hàm `add(ticketId, content)` chỉ gửi:
  `body: <String, dynamic>{'body': content}`.

#### B. Phía Backend Odoo (`ticket_add_message`)
- **Vị trí**: `v_mobile_17/controllers/ticket.py:556-606` & `v_mobile_19/controllers/ticket.py:563-613`.
- **Endpoint**: `POST /api/v1/mobile/ticket/<int:ticket_id>/message`.
- **Rà soát tham số**:
  - `attachment_ids`: Đã có dòng `attachment_ids = body.get("attachment_ids", [])` và truyền vào `rec.message_post(..., attachment_ids=attachment_ids)`. Tuy nhiên Flutter chưa gửi.
  - `is_internal`: **HOÀN TOÀN THIẾU**. Backend đang hardcode cố định:
    ```python
    subtype_id=request.env.ref("mail.mt_comment").id if request.env.ref("mail.mt_comment", raise_if_not_found=False) else False,
    ```
    Không kiểm tra `is_internal` từ request payload. Không cho phép ghi chú nội bộ qua `mail.mt_note`.

---

### 3. Hạng Mục 3: Màn Hình Tạo Ticket (`create_ticket_screen.dart`) (GAP - LOW)

#### A. Phía Flutter
- **Vị trí**: `vclients/lib/features/ticket/presentation/create_ticket_screen.dart:30-180`.
- **Thực trạng**:
  - Chỉ có các trường: `_title`, `_description`, `_priority`, `_teamId`, `_selectedTagId`, `_ccEmail`, `_attachments`.
  - **Thiếu trường chọn Khách hàng (`partner_id`)**: Đối với tài khoản Nhân viên nội bộ (`is_portal == false`), khi tiếp nhận yêu cầu từ hotline/Zalo/email muốn tạo ticket hộ khách hàng, app không có chỗ để tìm và chọn khách hàng.
  - **Thiếu trường chọn Hạn xử lý SLA (`date_deadline`)**: Không có DatePicker chọn deadline cam kết xử lý.
  - `TicketRepository.create` (`ticket_repository.dart:133-152`): Không có tham số `partnerId` và `dateDeadline`.

#### B. Phía Backend Odoo (`ticket_create`)
- **Vị trí**: `v_mobile_17/controllers/ticket.py:444-505` & `v_mobile_19/controllers/ticket.py:444-510`.
- **Rà soát**:
  - `partner_id`: Backend đã có logic `partner_id = values.get("partner_id")` cho user nội bộ. Do Flutter không gửi nên backend tự fallback về `_user.partner_id.id` của chính nhân viên tạo.
  - `date_deadline`: Backend **HOÀN TOÀN THIẾU** nhận và ghi trường `date_deadline` vào `vals`.

---

### 4. Hạng Mục 4: Phân Trang & Tìm Kiếm Ticket (`ticket_list_screen.dart`) (GAP - MED)

#### A. Cơ Chế Phân Trang (Chạm trần 20 bản ghi)
- **Vị trí Flutter**: `ticket_controller.dart:17-33` (`TicketFilterNotifier`) & `ticket_list_screen.dart:463-479` (`_TicketList`).
- **Thực trạng**:
  - `TicketFilter` khởi tạo mặc định `limit: null, offset: null`.
  - `TicketRepository.watchAssigned()`: Do `limit` là `null` nên không truyền tham số `limit` lên HTTP query.
  - Backend Odoo (`v_mobile_17:100` & `v_mobile_19:100`):
    `limit = min(int(kw.get("limit", 20)), 100)`. Backend mặc định áp `limit = 20`.
  - Giao diện `_TicketList`: Sử dụng `ListView.separated` không có controller lắng nghe sự kiện cuộn đáy để tải thêm.
  - **Hệ quả**: Danh sách bị "chạm trần" 20 ticket. Người dùng hoàn toàn không xem được ticket từ bản ghi số 21 trở đi.

#### B. Cơ Chế Tìm Kiếm (In-Memory Search)
- **Vị trí**: `vclients/lib/features/ticket/presentation/ticket_list_screen.dart:132-138`:
  ```dart
  bool _matchesQuery(Ticket ticket) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '${ticket.title} ${ticket.description ?? ''}'.toLowerCase().contains(q);
  }
  ```
- **Thực trạng**: Tìm kiếm thực hiện 100% trên bộ nhớ RAM của 20 ticket đã tải về.
- **Hệ quả**: Hoàn toàn không gọi API tìm kiếm trực tiếp dưới database Odoo. Nếu ticket cần tìm không nằm trong top 20 ticket mới nhất, tìm kiếm sẽ trả về rỗng dù dữ liệu có tồn tại trên hệ thống Odoo.

---

### 5. Hạng Mục 5: Đối Soát 14 Tính Năng Nhóm 5 Trong `docs/features.md`

| STT | Tính Năng Trong SSOT | Trạng Thái SSOT | Trạng Thái Rà Soát Thực Tế | Ghi Chú Đánh Giá |
| :---: | :--- | :---: | :---: | :--- |
| **5.1** | Danh sách Phiếu & Phân trang | `[!]` GAP | **GAP - MED** | Chạm trần 20 ticket; thiếu Infinite Scroll; tìm kiếm in-memory. |
| **5.2** | Tạo Phiếu Yêu cầu Mới | `[!]` GAP | **GAP - LOW** | Thiếu chọn `partner_id` cho nhân viên; thiếu chọn SLA `date_deadline`. |
| **5.3** | Đính kèm File/Ảnh & In-App Viewer | `[x]` VERIFIED | **VERIFIED** | Hỗ trợ đính kèm khi tạo; xem ảnh in-app `ChatV2ImageViewerScreen`; tải file an toàn. |
| **5.4** | Màn hình Chi tiết Ticket Toàn diện | `[x]` VERIFIED | **VERIFIED** | Hiển thị 18 trường thông tin; SLA chip; thông tin khách hàng và kỹ thuật viên. |
| **5.5** | Luồng Trao đổi & Bình luận (Chatter) | `[!]` GAP | **BUG / GAP** | Lệch tác giả khi nhận ticket; thiếu đính kèm file trong composer; thiếu `is_internal`. |
| **5.6** | HTML-to-Text Sanitizer | `[x]` VERIFIED | **VERIFIED** | `cleanHtmlText` làm sạch mã HTML chuẩn xác, giải mã entities an toàn. |
| **5.7** | Đo lường SLA & Deadline | `[x]` VERIFIED | **VERIFIED** | Getter `isOverdue` chính xác; cảnh báo đỏ khi quá hạn SLA. |
| **5.8** | Đánh giá Hài lòng (CSAT) | `[-]` DROPPED | **DROPPED** | Bỏ qua theo chỉ đạo của Sếp Tân ("em ko cần làm nhé bỏ cái 5.5 did"). |
| **5.9** | Chế độ Portal Mode Isolation | `[x]` VERIFIED | **VERIFIED** | Bảo mật cách ly dữ liệu qua `_user.share` và `partner_id`, pass 10/10 test Odoo 17 & 19. |
| **5.10**| Quản lý Hoạt động (`mail.activity`) | `[x]` VERIFIED | **VERIFIED** | Hỗ trợ xem, tạo và đánh dấu hoàn thành hoạt động kèm feedback trên cả Flutter và backend. |
| **5.11**| Quy trình Mở lại Ticket (Reopen) | `[x]` VERIFIED | **VERIFIED** | Nút "Mở lại ticket" màu cam hiển thị khi Done, đưa ticket về trạng thái đang xử lý. |
| **5.12**| Phân công & Chuyển giao Ticket | `[x]` VERIFIED | **VERIFIED** | Hộp thoại reassign chọn nhân viên từ `/api/v1/mobile/ticket/assignees`. |
| **5.13**| Chỉnh sửa Thông tin Ticket | `[x]` VERIFIED | **VERIFIED** | Hộp thoại edit cập nhật tiêu đề, mô tả, mức ưu tiên, đội xử lý qua `/update`. |
| **5.14**| Dọn dẹp Endpoint Rác & Audit Trail | `[x]` VERIFIED | **VERIFIED** | Chặn xóa comment bảo toàn audit trail Odoo; chuyển `sendContact` sang ghi chatter native. |

---

## III. ĐỀ XUẤT PHƯƠNG ÁN KHẮC PHỤC (ACTION PLAN FOR IMPLEMENTATION PHASE)

1. **Khắc phục Lỗi Tác Giả khi Nhận Ticket (Ưu tiên 1 - HIGH)**:
   - **Backend**: Trong `ticket_workflow`, khi chuyển trạng thái sang `doing`/`in_progress`, bổ sung lệnh gọi `ticket.with_user(uid).message_post(body=f"Kỹ thuật viên {user.name} đã tiếp nhận xử lý ticket.", message_type="notification", subtype_id=request.env.ref("mail.mt_note").id)`.
   - **Backend**: Trong `ticket_detail`, bỏ đoạn code ép tin nhắn rỗng thành `"đã tạo ticket này"`, chuyển sang phân tích đúng `msg.tracking_value_ids` hoặc chỉ hiển thị tin nhắn có nội dung thật.
   - **Flutter**: Trong `_CommentCard`, sửa điều kiện `isMe`: so sánh `comment.authorId` với `partner_id` của user hiện tại (thay vì so sánh với `session.uid`).
2. **Bổ Sung Đính Kèm File & Ghi Chú Nội Bộ Trong Chatter (Ưu tiên 2 - MED)**:
   - **Flutter**: Tích hợp nút đính kèm ảnh/file và toggle "Ghi chú nội bộ" vào `_CommentComposer`.
   - **Flutter**: Cập nhật `TicketCommentRepository.add()` nhận thêm `attachmentIds` và `isInternal`.
   - **Backend**: Trong `ticket_add_message`, tiếp nhận `is_internal = body.get("is_internal", False)`. Nếu `True` và user là nhân viên nội bộ, gán `subtype_id = request.env.ref("mail.mt_note").id`.
3. **Bổ Sung Partner & SLA Deadline Cho Màn Hình Tạo Ticket (Ưu tiên 3 - LOW)**:
   - **Flutter**: Khi `!user.isPortal`, hiển thị trường tìm kiếm/chọn Khách hàng (`partner_id`) và trường chọn Hạn xử lý SLA (`date_deadline`).
   - **Backend**: Trong `ticket_create`, tiếp nhận `date_deadline = values.get("date_deadline")` và ghi vào `vals`.
4. **Bổ Sung Infinite Scroll & Tìm Kiếm Server-Side (Ưu tiên 4 - MED)**:
   - **Flutter**: Thêm `ScrollController` vào `_TicketList`, khi cuộn chạm ngưỡng 90% chiều cao thì gọi `loadMore(offset += limit)`.
   - **Flutter**: Ô tìm kiếm áp dụng debounce 400ms và kích hoạt `ticketFilterProvider.notifier.update(filter.copyWith(search: query))` để gọi API tìm kiếm trực tiếp dưới database Odoo.
