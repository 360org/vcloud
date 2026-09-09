# ĐẶC TẢ KỸ THUẬT: TÍNH NĂNG TAG @ (MENTION THÀNH VIÊN) TRONG CHAT

- **Dự án**: Mobile Ecosystem (`vcloud`, `v_mobile_17`, `v_mobile_19`)
- **Tài liệu**: `docs/SPEC_CHAT_MENTION.md` (Kế thừa `docs/SPEC.md` Section IX)
- **Phiên bản**: v1.0.0
- **Ngày ban hành**: 2026-09-09
- **Tác giả**: `00_AIAC_LEAD` & Multi-Agent Swarm

---

## I. TỔNG QUAN & BỐI CẢNH (CONTEXT & GOALS)

Trong các cuộc hội thoại kênh nhóm (`discuss.channel`) và kênh hỗ trợ, người dùng cần có khả năng **nhắc tên đích danh (@ Mention)** một hoặc nhiều thành viên để thu hút sự chú ý và gửi thông báo đẩy ưu tiên cao.

### Mục tiêu cốt lõi:
1. **Trải nghiệm gõ mượt mà (Mobile UX)**: Gõ `@` sẽ mở bảng gợi ý thành viên kênh tức thì (< 5ms), tìm kiếm thông minh (hỗ trợ tiếng Việt không dấu/có dấu), chọn nhanh và tự động chèn vào ô nhập.
2. **Đồng bộ đa nền tảng (Flutter Mobile ↔ Odoo Web Discuss)**:
   - Trên Mobile: Render text highlight màu thương hiệu (`#1976D2` / Primary Blue), chạm vào để xem danh thiếp/chat 1-1.
   - Trên Web Odoo: Tạo thẻ HTML chuẩn Odoo `<a data-oe-model="res.partner" data-oe-id="..." class="o_mail_redirect">@Tên</a>` để hiển thị đồng bộ khi mở trên trình duyệt máy tính.
3. **Bảo mật & Hiệu năng cao (Security & Performance)**:
   - **Chống IDOR**: Backend kiểm soát chặt chẽ, chỉ cho phép tag các đối tác (`res.partner`) thực sự là thành viên của kênh.
   - **Chống XSS**: Escape toàn bộ nội dung người dùng nhập trước khi bọc thẻ HTML an toàn.
   - **Chống ReDoS**: Sử dụng biểu thức chính quy tuyến tính (Linear Regex) có chặn độ dài chuỗi tối đa (<2000 ký tự).

---

## II. BACKEND CONTRACT & API SPECIFICATION (`v_mobile_17` & `v_mobile_19`)

### 1. Endpoint Gửi Tin Nhắn (`POST /api/v1/mobile/chat/messages`)

- **Method**: `POST`
- **Path**: `/api/v1/mobile/chat/messages`
- **Auth**: Bearer JWT / Session UID

#### Request Payload:
```json
{
  "channel_id": 128,
  "body": "Chào @Vũ Việt Hùng, vui lòng kiểm tra báo cáo này nhé @all",
  "partner_ids": [45],
  "mentioned_partners": [
    {
      "id": 45,
      "name": "Vũ Việt Hùng"
    }
  ],
  "attachments": []
}
```

#### Xử lý logic Backend (`controllers/chat.py`):
1. **Kiểm tra quyền thành viên**:
   ```python
   all_partner_ids = (channel.channel_member_ids.mapped("partner_id") | channel.channel_partner_ids).ids
   if partner.id not in all_partner_ids:
       return _cors_response(_json_resp({"error": "forbidden", "message": "Bạn không phải thành viên kênh"}, 403))
   ```
2. **IDOR Guard trên `partner_ids`**:
   Lọc sạch danh sách `partner_ids` được tag, chỉ giữ lại các ID nằm trong `all_partner_ids`:
   ```python
   raw_partner_ids = body.get("partner_ids") or []
   valid_partner_ids = [pid for pid in raw_partner_ids if isinstance(pid, int) and pid in all_partner_ids and pid != partner.id]
   ```
3. **Chuyển đổi sang HTML Discuss an toàn (XSS Guard)**:
   ```python
   import html
   from markupsafe import Markup

   clean_text = html.escape(raw_body)
   # Thay thế các cụm @Tên của partner hợp lệ thành thẻ <a> chuẩn Odoo
   for mp in mentioned_partners:
       pid = mp.get("id")
       pname = mp.get("name")
       if pid in valid_partner_ids and pname:
           escaped_name = html.escape(pname)
           tag_html = f'<a href="#" data-oe-model="res.partner" data-oe-id="{pid}" class="o_mail_redirect">@{escaped_name}</a>'
           clean_text = clean_text.replace(f"@{escaped_name}", tag_html)

   # Tạo tin nhắn Odoo
   msg = channel.message_post(
       body=Markup(clean_text),
       message_type="comment",
       subtype_xmlid="mail.mt_comment",
       partner_ids=valid_partner_ids,
   )
   ```
4. **Push Notification Gateway (`models/mail_thread.py`)**:
   Khi phát hiện `message.partner_ids` có chứa người nhận, gói tin Firebase Push FCM gửi đi mang thêm thuộc tính:
   ```json
   {
     "is_mention": true,
     "mention_title": "💬 Bạn được nhắc đến trong tin nhắn"
   }
   ```

#### Response:
```json
{
  "id": 98452,
  "body": "<a href=\"#\" data-oe-model=\"res.partner\" data-oe-id=\"45\" class=\"o_mail_redirect\">@Vũ Việt Hùng</a>, vui lòng kiểm tra báo cáo này nhé @all",
  "plain_body": "@Vũ Việt Hùng, vui lòng kiểm tra báo cáo này nhé @all",
  "author": {
    "id": 14,
    "name": "Sếp Tân",
    "avatar_url": "/api/v1/mobile/avatar/users/14"
  },
  "partner_ids": [45],
  "date": "2026-09-09 16:00:00"
}
```

---

## III. FRONTEND ARCHITECTURE (`vclients`)

### 1. Thành phần UI/UX mới & Tích hợp

```
lib/features/chat_v2/
├── presentation/
│   ├── widgets/
│   │   ├── chat_v2_input_bar.dart        (Bắt sự kiện @, quản lý overlay popup)
│   │   ├── chat_v2_mention_overlay.dart  (Widget popup danh sách gợi ý thành viên)
│   │   ├── chat_v2_message_item.dart     (Highlight text @mention & bắt sự kiện tap)
│   │   └── chat_bubbles.dart             (Render TextSpan tô màu @mention)
│   └── controllers/
│       └── chat_v2_notifier.dart         (Cung cấp channel members & gửi partner_ids)
```

### 2. Chi tiết luồng hoạt động `ChatV2InputBar` & `ChatV2MentionOverlay`

1. **Lắng nghe nhập liệu**:
   - `TextEditingController` kiểm tra vị trí con trỏ:
     Nếu trước con trỏ là `@` hoặc `@từ_khóa` (không chứa khoảng trắng), kích hoạt `MentionOverlay`.
2. **Lọc thành viên (In-Memory Filter)**:
   - Đọc danh sách thành viên kênh từ state `channelMembers`.
   - Tìm kiếm không phân biệt hoa/thường, không phân biệt dấu tiếng Việt (ví dụ: `hung` -> `Vũ Việt Hùng`).
   - Mục đầu tiên nếu là kênh nhóm: `📢 @all (Nhắc tất cả thành viên)`.
3. **Chèn vào ô nhập (Selection & Insertion)**:
   - Khi bấm chọn thành viên:
     - Thay thế cụm `@từ_khóa` thành `@Tên_Thành_Viên `.
     - Thêm `{id: member.id, name: member.name}` vào danh sách `_mentionedPartners`.
     - Ẩn popup `MentionOverlay`.
4. **Hiển thị bong bóng tin nhắn (`ChatV2MessageItem`)**:
   - Dùng Regex linear: `RegExp(r'@([A-Za-z0-9_\p{L}\s]{1,40})', unicode: true)` để bóc tách.
   - Text chứa `@Tên` được format `TextSpan` màu xanh dương đậm (`#1976D2`), in đậm nhẹ.
   - Nếu ID người dùng hiện tại có trong `message.partner_ids`, viền bong bóng tin nhắn phát sáng hoặc hiển thị badge `Bạn được nhắc đến`.

---

## IV. MA TRẬN PHÂN CÔNG ĐIỀU PHỐI (SWARM WORKFLOW)

| Vai trò | Phụ trách | Phạm vi file |
|---|---|---|
| 👑 `00_AIAC_LEAD` | Lập Spec, giám sát kiến trúc và nghiệm thu toàn diện | `docs/SPEC_CHAT_MENTION.md`, `docs/SPEC.md` |
| 💻 `DEV_BACKEND_ODOO` | Cập nhật API chat nhận `partner_ids`, convert HTML an toàn | `v_mobile_17/controllers/chat.py`, `v_mobile_19/controllers/chat.py` |
| 📱 `DEV_MOBILE_FLUTTER` | Xây dựng Mention Overlay, TextSpan Highlight, Repository | `vclients/lib/features/chat_v2/presentation/widgets/*` |
| 🛡️ `TESTER_SECURITY` | Kiểm thử IDOR (chặn tag ngoài kênh), XSS, ReDoS regex | `tests/test_chat_mention_security.py` |
| 🔍 `TESTER_FUNCTIONAL` | Kiểm thử gửi nhận tin nhắn, payload partner_ids, test suites | `test_chat_mention_contract.py`, Flutter widget tests |

---

## V. TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA)

1. **AC-1 (Backend API)**: Endpoint `POST /api/v1/mobile/chat/messages` nhận và lưu `partner_ids`, format HTML thẻ `<a>` chuẩn Odoo Discuss.
2. **AC-2 (Security IDOR)**: Không thể tag partner ID không thuộc kênh (bị lọc bỏ 100%).
3. **AC-3 (Mobile Input)**: Gõ `@` hiển thị popup gợi ý mượt mà, chọn thành viên chèn đúng tên và vị trí con trỏ.
4. **AC-4 (Mobile Rendering)**: Text `@Tên` được highlight màu chuẩn, không bị vỡ layout khi nhận tin dài.
5. **AC-5 (Tests Pass 100%)**: Backend contract test đạt 5/5 PASS, Flutter analyze đạt 0 issues.
