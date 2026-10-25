# 🛡️ CLAUDE CODE PRE-PUSH AUDIT & QUALITY GATE (SSOT)
# File: audit_claude.md
# Director & Single Authority: Sếp Tân
# Version: Audit Protocol v2.1 (N+1 Anti-Patterns & Rookie Mistakes Blacklist Edition)
# Liên kết hệ thống: `prompt_claude.md` (Execution SSOT) ⇄ `audit_claude.md` (Audit SSOT)

---

## 📑 MỤC LỤC NHANH (TABLE OF CONTENTS)

| Phần | Nội dung | Mục tiêu |
|---|---|---|
| **I** | Định Vị & Ranh Giới Hệ Thống | Mối quan hệ giữa `prompt_claude.md` và `audit_claude.md` |
| **II** | Triết Lý Kỷ Luật: Anti-Sycophancy & Evidence-First | Phân định trạng thái & Thang độ tin cậy L0 - L5 |
| **III** | 🏛️ 4 Trục Kiểm Toán Cốt Lõi (The 4 Audit Pillars) | Tối ưu hệ thống, Đúng version, An toàn bảo mật, Chịu tải |
| **IV** | ⚠️ Sổ Tay Diệt N+1 Query & Các Lỗi Ngớ Ngẩn, Cơ Bản | 5 Mẫu N+1 kinh điển + 20 lỗi ngớ ngẩn (Odoo & Flutter) |
| **V** | 📋 Pre-Push Verification Checklist Theo Nhánh | GitLab `17.0`, GitLab `19.0`, GitHub `main` |
| **VI** | 🧰 Kích Hoạt Bộ Công Cụ Chuyên Trách Audit | `audit-gate`, `tester-security`, `/ponytail-audit`, `ReportFindings` |
| **VII** | 📊 Mẫu Báo Cáo Nghiệm Thu Chuẩn (< 1.200 ký tự) | Báo cáo cô đọng dạng bảng trình Sếp Tân duyệt trước khi push |
| **VIII** | 🛑 Quy Trình Stop-The-Line & Rollback Guard | Cơ chế ngắt lặp và phục hồi an toàn khi vi phạm tiêu chuẩn |

---

## 🧭 I. ĐỊNH VỊ & RANH GIỚI HỆ THỐNG (SSOT LINKAGE)

Nhằm tối ưu hóa tài nguyên, tránh phân mảnh và chồng chéo tài liệu, toàn bộ hệ thống vận hành Claude Code của Sếp Tân được tinh gọn thành **2 file SSOT duy nhất**:

```text
┌────────────────────────────────────────────────────────┐
│                   SẾP TÂN (PO / TỔNG)                  │
└───────────────────────────┬────────────────────────────┘
                            │
            ┌───────────────┴───────────────┐
            ▼                               ▼
┌──────────────────────────────┐ ┌──────────────────────────────┐
│       prompt_claude.md       │ │       audit_claude.md        │
│   (EXECUTION & SDLC ENGINE)  │ │   (PRE-PUSH AUDIT & GATE)    │
├──────────────────────────────┤ ├──────────────────────────────┤
│ • Dàn nhạc Multi-Agent OS 3.1│ │ • 4 Trục kiểm toán cốt lõi   │
│ • 7 Bước SDLC thực thi       │ │ • Diệt N+1 & Lỗi ngớ ngẩn    │
│ • Fact-check & Root Cause    │ │ • Checklist GitLab 17.0/19.0 │
│ • Ponytail & Work Breakdown  │ │ • Checklist GitHub main      │
└──────────────────────────────┘ └──────────────────────────────┘
```

- **`prompt_claude.md`**: Master Execution Prompt — Chỉ đạo thi công, giao việc Multi-Agent, phân rã gói việc, giữ ranh giới 1-File-1-Owner và bảo vệ Context.
- **`audit_claude.md`**: Master Quality Gate — Trọng tài độc lập, kiểm toán bằng chứng thực tế, soi 4 trục chuyên sâu và thanh trừng lỗi ngớ ngẩn trước khi cấp phép push code lên GitLab và GitHub.

---

## ⚖️ II. TRIẾT LÝ KỶ LUẬT: ANTI-SYCOPHANCY & EVIDENCE-FIRST PROTOCOL

> **"Không đứng về phía Sếp. Không đứng về phía AI. Đứng về phía Evidence."**  
> *Never trade truth for agreement. Never trade evidence for confidence. Never trade correctness for satisfaction.*

### 1. Phân định rạch ròi 5 trạng thái thao tác (Action States):
- `CHANGED`: Diff xác nhận file có sửa đổi. *(Chỉ chứng minh có gõ phím, KHÔNG chứng minh code đúng hay fix được lỗi).*
- `TESTED`: Test script / unit test đã chạy và pass. *(Chỉ chứng minh các case trong file test đó pass, chưa chứng minh hệ thống chạy thật).*
- `REPRODUCED`: Đã tái hiện được bug/hiện tượng trước fix bằng log/curl/query DB thật.
- `VERIFIED`: Bằng chứng runtime thực tế sau fix chứng minh hành vi mong muốn đạt được và không hồi quy.
- `PRODUCTION-VERIFIED`: Đã kiểm chứng trực tiếp trên môi trường thực tế.

### 2. Thang đo độ chắc chắn 6 cấp độ (Confidence Levels L0 - L5):
- `L0 — UNKNOWN`: Chưa kiểm tra / chưa có dữ liệu.
- `L1 — HYPOTHESIS`: Có giả thuyết hoặc phỏng đoán kỹ thuật hợp lý nhưng chưa chứng minh.
- `L2 — SUPPORTED`: Đã đọc code và thấy logic có vẻ đúng. *(TUYỆT ĐỐI CẤM dừng ở L2 rồi báo "đã fix xong").*
- `L3 — REPRODUCED`: Đã tái hiện lỗi bằng traceback log, profiler, curl hoặc query DB cụ thể.
- `L4 — VERIFIED`: Đã patch code + chạy test suite + có log runtime/terminal chứng minh hành vi đúng.
- `L5 — PRODUCTION-VERIFIED`: Đã kiểm chứng chạy ổn định trên môi trường Production.
*(⛔ **LUẬT THÉP**: Cấm nhảy cóc từ L2 "em đọc code thấy hợp lý" lên L4/L5).*

---

## 🏛️ III. 4 TRỤC KIỂM TOÁN CỐT LÕI (THE 4 AUDIT PILLARS)

Trước khi thực hiện bất kỳ lệnh `git commit` hay `git push` nào, Agent Audit **BẮT BUỘC** rà soát code theo đúng 4 trục:

```text
           ┌──────────────────────────────────────────────┐
           │        4 TRỤC KIỂM TOÁN PRE-PUSH CODE        │
           └──────────────────────┬───────────────────────┘
      ┌─────────────────┬─────────┴─────────┬─────────────────┐
      ▼                 ▼                   ▼                 ▼
 1. TỐI ƯU HỆ THỐNG  2. ĐÚNG VERSION    3. AN TOÀN BẢO MẬT   4. CHỊU TẢI
 (Query, RAM, UI)   (Parity 17 vs 19)   (Anti-IDOR, Token)  (504, Concurrency)
```

---

### 🚀 TRỤC 1: TỐI ƯU HỆ THỐNG (SYSTEM PERFORMANCE & RESOURCE OPTIMIZATION)

#### A. Backend Odoo (`v_mobile_17`, `v_mobile_19`):
1. **Triệt tiêu ORM N+1 Query**:
   - ⛔ **CẤM**: Gọi `.search()`, `.browse()` hoặc truy cập quan hệ relational bên trong vòng lặp `for record in records:`.
   - ✅ **BẮT BUỘC**: Dùng mapped, filtered hoặc batch queries:
     ```python
     # SAI (N+1 Query kinh điển):
     for line in order_lines:
         partner = line.order_id.partner_id.name

     # ĐÚNG (Batch In-Memory qua Prefetch):
     partners = order_lines.mapped("order_id.partner_id.name")
     ```
2. **Khai báo SQL Indexing chuẩn**:
   - Mọi trường dùng thường xuyên trong mệnh đề `domain` (filter) hoặc `order` (sort) của API mobile **BẮT BUỘC** có index.
   - Odoo 17 & 19: Sử dụng cú pháp mới `models.Index()` thay vì `index=True` kiểu cũ.
3. **Quản lý RAM, Gevent Worker & Session Cursor**:
   - Không cache recordset qua nhiều request HTTP.
   - Nếu tự mở cursor độc lập (`with registry.cursor() as cr:`), bắt buộc bọc trong context manager để tự động `close()` và `commit()`, tuyệt đối không để treo connection pool của PostgreSQL.
   - Đảm bảo bus/websocket listener không giữ socket treo làm phình RAM worker.

#### B. Frontend Mobile & Web (`vclients`):
1. **Widget Rebuild Optimization**:
   - Sử dụng từ khóa `const` triệt để ở mọi constructor widget tĩnh.
   - Tách nhỏ widget thay vì viết các file View dài hàng nghìn dòng.
   - Lọc lắng nghe state qua `ref.watch(provider.select((s) => s.specificField))` để tránh rebuild toàn màn hình khi chỉ 1 trường nhỏ thay đổi.
2. **Quản lý Bộ Nhớ & Cleanup Controller**:
   - Mọi `TextEditingController`, `ScrollController`, `AnimationController`, `StreamSubscription` **BẮT BUỘC** phải được dispose trong hàm `dispose()` của `StatefulWidget` hoặc Riverpod `ref.onDispose()`.
3. **Thu Gọn Payload Mạng (Compact Payload)**:
   - Các API danh sách (Tickets, Channels, Messages, Timesheet) bắt buộc có phân trang (`limit`, `offset`), không fetch toàn bộ dữ liệu làm tràn RAM thiết bị di động.

---

### 🔄 TRỤC 2: ĐÚNG VERSION & PARITY (VERSION GOVERNANCE & MULTI-VERSION PARITY)

#### A. Quản Trị Version SSOT:
1. **Frontend Flutter (`vclients`)**:
   - `pubspec.yaml` là **Single Source of Truth (SSOT)** duy nhất cho `version: x.y.z+build`.
   - Build number trên TestFlight và Google Play **BẮT BUỘC** lấy từ `pubspec.yaml`, cấm để `github.run_number` tự động ghi đè làm lệch số hiệu bản dựng.
   - Đồng bộ `vclients/docs/CHANGELOGS.md` đầy đủ ngày tháng `(YYYY-MM-DD)` và 5 tag chuẩn: `[NEW]`, `[FIX]`, `[IMPROVE]`, `[REFACTOR]`, `[SECURITY]`.
2. **Backend Odoo 17 (`v_mobile_17`)**:
   - `__manifest__.py`: `version: '17.0.x.y.z'`
   - Ghi rõ Changelog trong trường `description` của `__manifest__.py` và `docs/CHANGELOGS.md`.
3. **Backend Odoo 19 (`v_mobile_19`)**:
   - `__manifest__.py`: `version: '19.0.x.y.z'`
   - Đồng bộ version tương ứng với các cải tiến và fix bug từ 17.

#### B. Đồng Bộ API Contract & Cú Pháp 17 vs 19 (Parity Gate):
| Hạng mục kiểm tra | Odoo 17 (`v_mobile_17`) | Odoo 19 (`v_mobile_19`) | Quy chuẩn Parity |
|---|---|---|---|
| **Chat / Discuss** | `mail.channel` / `discuss.channel` | `discuss.channel` | API mobile map cùng payload chuẩn |
| **Giao diện XML** | `invisible="..."` | `invisible="..."` | ⛔ CẤM TUYỆT ĐỐI dùng `attrs=` |
| **Ràng buộc ORM** | `models.Constraint()` | `models.Constraint()` | ⛔ CẤM dùng `_sql_constraints` |
| **Singleton Check** | `ensure_one()` an toàn | `ensure_one()` an toàn | Tránh crash khi query `res.users` trả về rỗng |
| **Format Markup** | `markupsafe.Markup` | `markupsafe.Markup` | Bắt buộc bọc HTML post chatter |

---

### 🛡️ TRỤC 3: AN TOÀN BẢO MẬT (SECURITY, ACCESS CONTROL & TRUST BOUNDARY)

1. **Kiểm Soát Quyền Sở Hữu & Chống IDOR (Anti-Insecure Direct Object References)**:
   - Mọi endpoint trả về hoặc chỉnh sửa dữ liệu (Ticket, Task, Hồ sơ, File đính kèm) **BẮT BUỘC** kiểm tra quyền của `request.env.user` hoặc JWT `uid`.
   - ⛔ **CẤM**: Nhận `partner_id` hoặc `user_id` từ client gửi lên rồi thực thi trực tiếp mà không kiểm tra xem user đó có quyền truy cập bản ghi đó hay không.
   - Hạn chế tối đa việc lạm dụng `.sudo()`. Nếu nghiệp vụ bắt buộc dùng `sudo()`, phải thực hiện kiểm tra quyền (permission check) ở tầng Python ngay trước đó.
2. **Bảo Vệ Token & Credentials**:
   - Không bao giờ trả về password hash trong bất kỳ API response nào.
   - ⛔ **CẤM GHI LOG THÔ**: Không `print()`, `_logger.info()` chứa mật khẩu, JWT Access/Refresh Token ra console container hoặc terminal.
   - Frontend: Mật khẩu và Token bắt buộc lưu trữ trong `FlutterSecureStorage` (Keychain trên iOS / EncryptedSharedPreferences trên Android).
3. **Phân Lập Đa Tenant & Đa Công Ty (Data Isolation)**:
   - Mọi truy vấn ORM phải có điều kiện lọc theo `company_id` hoặc `company_ids` nằm trong danh sách được cấp phép của user hiện tại (`request.env.companies`).
4. **Chống XSS & SQL Injection**:
   - Bắt buộc bọc nội dung HTML bằng `from markupsafe import Markup; Markup(html_str)` khi đẩy tin nhắn vào chatter/mail, tránh lộ raw HTML hoặc bị tấn công script.
   - Cấm nối chuỗi raw SQL (`cr.execute("SELECT ... %s" % val)`). Bắt buộc dùng parameterized query: `cr.execute("SELECT ... %s", (val,))`.

---

### ⚡ TRỤC 4: CHỊU TẢI & CONCURRENCY (HIGH LOAD & RESILIENCE)

1. **Triệt Tiêu 504 Gateway Timeout (Nguyên Tắc Bất Di Bất Dịch)**:
   - Các tác vụ tốn thời gian (gửi push notification hàng loạt qua FCM, tạo tài liệu PDF, đồng bộ mail nặng, kiểm tra AI) **BẮT BUỘC** đẩy vào background queue / thread hoặc cron job. Tuyệt đối không để request HTTP của mobile client chờ quá 10 giây.
   - Tối ưu luồng đăng nhập đa DB và API lấy danh sách chat: Gom query, không gọi RPC tuần tự lặp đi lặp lại.
2. **Bảo Vệ Worker Pool & Gevent Safety**:
   - ⛔ **CẤM**: Hạ `workers = 0` trong file cấu hình `odoo.conf` để né lỗi. Mọi code viết ra phải chạy ổn định trên môi trường Multi-Worker Gevent.
   - Không thực hiện các lệnh khóa bảng độc quyền (`LOCK TABLE`, `SELECT ... FOR UPDATE` không timeout) gây nghẽn kết nối của các worker khác.
3. **Rate Limiting & Chống DoS**:
   - Các endpoint nhạy cảm (`/api/v1/auth/login`, `/api/v1/auth/lookup-db`, `/api/v1/auth/reset-password`) phải có cơ chế giới hạn tần suất gọi từ 1 IP để bảo vệ server.
4. **Mobile Client Resilience (Khả Năng Phục Hồi Của App)**:
   - Cấu hình Timeout hợp lý trên Flutter: Connect Timeout (15s), Receive Timeout (30s).
   - Retry an toàn với Exponential Backoff cho các API đọc dữ liệu idempotent (GET).
   - Xử lý lỗi thân thiện: Khi server trả về 502/503/504 hoặc mất mạng, app phải hiển thị thông báo lỗi lịch sự kèm nút "Thử lại", tuyệt đối không crash trắng màn hình hoặc văng app.

---

## ⚠️ IV. SỔ TAY DIỆT N+1 QUERY & CÁC LỖI NGỚ NGẨN, CƠ BẢN (ROOKIE & SILLY MISTAKES BLACKLIST)

Đây là danh mục các lỗi ngớ ngẩn (silly mistakes) và lỗi cơ bản thường gặp nhất trong thực chiến khiến ứng dụng bị đơ, sập server hoặc chạy chậm như rùa. Agent Audit **BẮT BUỘC** soi kỹ từng mục:

### 🚨 PHẦN 1: 5 MẪU LỖI N+1 QUERY KINH ĐIỂN VÀ CÁCH DIỆT TẬN GỐC

| Mẫu Lỗi N+1 | Hiện Tượng Gây Nghẽn | Code Sai (Anti-Pattern) | Giải Pháp Chuẩn (Diệt Tận Gốc) |
|---|---|---|---|
| **1. Query trong vòng lặp `for`** | Duyệt 1.000 dòng bắn 1.001 câu SQL xuống Postgres | ```python<br>for user in users:<br>    tasks = env['project.task'].search([('user_id', '=', user.id)])<br>``` | **Gom 1 câu `search` duy nhất:**<br>```python<br>all_tasks = env['project.task'].search([('user_id', 'in', users.ids)])<br>tasks_by_user = defaultdict(lambda: env['project.task'])<br>for t in all_tasks:<br>    tasks_by_user[t.user_id.id] |= t<br>``` |
| **2. Truy cập Relational field lặp** | Mỗi lần chạm vào `record.partner_id.name` là 1 câu SQL mới nếu mất prefetch | ```python<br>data = []<br>for t in tickets:<br>    data.append({'client': t.partner_id.name})<br>``` | **Dùng `mapped()` hoặc `read()` batch:**<br>```python<br># Prefetch toàn bộ partner 1 lần:<br>tickets.mapped('partner_id.name')<br># Hoặc read fields cần thiết:<br>tickets.read(['name', 'partner_id'])<br>``` |
| **3. Computed Field thiếu `@api.depends`** | Odoo không lưu cache, mỗi lần view/API gọi đến lại tính lại từ đầu | ```python<br>def _compute_total(self):<br>    for r in self:<br>        r.total = sum(r.line_ids.mapped('price'))<br># Quên @api.depends('line_ids.price')<br>``` | **Khai báo đủ depends để lưu cache:**<br>```python<br>@api.depends('line_ids.price')<br>def _compute_total(self):<br>    for r in self:<br>        r.total = sum(r.line_ids.mapped('price'))<br>``` |
| **4. Mobile gọi HTTP tuần tự trong loop** | Lấy 20 cuộc chat ➔ gọi 20 HTTP requests nối đuôi nhau ➔ lag 10s | ```dart<br>for (final id in channelIds) {<br>    final detail = await api.getChannel(id);<br>    channels.add(detail);<br>}<br>``` | **Gộp Backend Endpoint hoặc `Future.wait`:**<br>```dart<br>// Tốt nhất: Backend trả API batch /channels/bulk<br>// Tạm thời: Chạy song song nếu API chưa gộp<br>final channels = await Future.wait(<br>    channelIds.map((id) => api.getChannel(id))<br>);<br>``` |
| **5. Đếm số lượng bằng `len(search())`** | Kéo hàng vạn recordset vào RAM chỉ để đếm số lượng | ```python<br>count = len(env['helpdesk.ticket'].search([('stage_id', '=', 1)]))<br>``` | **Dùng `search_count()` bắn SQL `COUNT(*)`:**<br>```python<br>count = env['helpdesk.ticket'].search_count([('stage_id', '=', 1)])<br>``` |

---

### 🤦 PHẦN 2: 10 LỖI NGỚ NGẨN & CƠ BẢN BACKEND ODOO / PYTHON

1. **Lỗi `Expected singleton` ngớ ngẩn**:
   - *Lỗi*: Gọi `record.name` hoặc `record.ensure_one()` trên một recordset có 0 bản ghi (rỗng) hoặc nhiều hơn 1 bản ghi.
   - *Cách tránh*: Luôn kiểm tra `if record: ...` hoặc dùng `record[:1].name` nếu chỉ lấy bản ghi đầu tiên, tránh crash API 500.
2. **Lỗi Quên `return` trong HTTP Controller**:
   - *Lỗi*: Xử lý nghiệp vụ xong xuôi nhưng quên dòng `return response` hoặc `return None` ➔ Client nhận 200 rỗng hoặc trắng xoá.
   - *Quy chuẩn*: Mọi route `@http.route` bắt buộc trả về format chuẩn JSON: `return request.make_json_response({'status': 'success', 'data': ...})`.
3. **Lỗi Type Mismatch giữa String và Int (So sánh lệch kiểu)**:
   - *Lỗi*: `if request.params.get('ticket_id') == ticket.id:` (String `"123"` so sánh với Int `123` luôn ra `False`).
   - *Cách tránh*: Luôn ép kiểu rõ ràng: `int(request.params.get('ticket_id') or 0)`.
4. **Lỗi Mutable Default Argument trong hàm Python**:
   - *Lỗi*: `def add_item(item, list_items=[]):` ➔ Danh sách dùng chung vĩnh viễn giữa tất cả các request, gây lẫn lộn dữ liệu giữa các user!
   - *Cách sửa*: `def add_item(item, list_items=None): if list_items is None: list_items = []`.
5. **Lỗi Nuốt chửng ngoại lệ (`except Exception: pass`)**:
   - *Lỗi*: Bọc try/catch rồi bỏ qua lỗi khiến bug bị giấu kín, app mobile không nhận được dữ liệu và không thể debug.
   - *Quy chuẩn*: Bắt buộc log lỗi bằng `_logger.exception("Chi tiết lỗi:")` và trả về mã lỗi rõ ràng cho client.
6. **Lỗi Hardcode ID (`company_id = 1` hay `user_id = 2`)**:
   - *Lỗi*: Gán cứng số ID của database local vào code, khi chạy trên database của khách hàng ID khác là sập ngay.
   - *Quy chuẩn*: Lấy ID động qua `request.env.company.id`, `request.env.user.id` hoặc dùng External ID XML `env.ref('module.xml_id')`.
7. **Lỗi Quên khai báo dependency trong `__manifest__.py`**:
   - *Lỗi*: Code gọi model `helpdesk.ticket` nhưng trong manifest trường `'depends'` quên khai báo `'helpdesk'` ➔ Cài DB mới văng lỗi `KeyError`.
8. **Lỗi Lẫn lộn UTC và Local Timezone**:
   - *Lỗi*: Dùng `datetime.now()` (giờ server local) thay vì `fields.Datetime.now()` (giờ chuẩn UTC của Odoo) làm sai lệch giờ chấm công, hạn chót task.
9. **Lỗi Tự tiện `cr.commit()` trong Controller**:
   - *Lỗi*: Gọi `request.env.cr.commit()` bừa bãi làm phá vỡ cơ chế transaction atomicity của Odoo; nếu bước sau văng lỗi thì không rollback được dữ liệu trước đó.
10. **Lỗi Không cập nhật View/Assets sau khi đổi Model**:
    - *Lỗi*: Xóa hoặc đổi tên một trường trong Python nhưng quên xóa trường đó trong file XML View ➔ Mở giao diện bị văng lỗi màn hình đỏ.

---

### 📱 PHẦN 3: 10 LỖI NGỚ NGẨN & CƠ BẢN FRONTEND FLUTTER / DART

1. **Lỗi `Looking up a deactivated widget's ancestor is unsafe` (Quên `context.mounted`)**:
   - *Lỗi*: Sau một lệnh `await` (gọi API, delay), gọi tiếp `Navigator.of(context)` hoặc `ScaffoldMessenger.of(context)` khi user đã bấm nút Back thoát màn hình.
   - *Cách sửa*: BẮT BUỘC kiểm tra `if (!context.mounted) return;` ngay sau mọi dòng `await`.
2. **Lỗi Bang Operator `!` gây Crash văng app (`Null check operator used on a null value`)**:
   - *Lỗi*: Tự tin viết `user!.name` khi dữ liệu API trả về `null`.
   - *Quy chuẩn*: Dùng toán tử an toàn `user?.name ?? 'Chưa cập nhật'`.
3. **Lỗi Gọi `setState()` hoặc Navigation bên trong hàm `build()`**:
   - *Lỗi*: Gây ra lỗi kinh điển `setState() or markNeedsBuild() called during build`.
   - *Cách sửa*: Chuyển vào `initState()` hoặc bọc trong `WidgetsBinding.instance.addPostFrameCallback((_) { ... })`.
4. **Lỗi Quên `dispose()` Controllers gây rò rỉ RAM (Memory Leak)**:
   - *Lỗi*: Khởi tạo `TextEditingController`, `ScrollController`, `FocusNode` nhưng không dispose trong hàm `dispose()`.
5. **Lỗi Hardcode URL Backend (`http://localhost:8069` hay `http://10.0.2.2`)**:
   - *Lỗi*: Viết cứng URL máy dev vào code, build ra app release cho khách hàng không kết nối được server.
   - *Quy chuẩn*: Bắt buộc đọc từ cấu hình tập trung `Env.odooApiBaseUrl`.
6. **Lỗi Không Handle trạng thái Loading & Error**:
   - *Lỗi*: Chỉ vẽ UI cho trường hợp thành công (Data), khi API lag hoặc lỗi 500 thì hiện màn hình trắng bóc hoặc spinner xoay vô tận.
   - *Quy chuẩn*: Mọi màn hình bắt buộc có đủ 3 trạng thái: `AsyncValue.when(data: ..., loading: ..., error: ...)`.
7. **Lỗi Hardcode chuỗi tiếng Anh hoặc sai chính tả trên UI**:
   - *Lỗi*: Màn hình tiếng Việt nhưng hiện popup nút `"Cancel"`, `"OK"`, `"Submit"` hoặc text sai chính tả lôm côm.
8. **Lỗi Bỏ qua Validation ở Form Client**:
   - *Lỗi*: Không kiểm tra ô input rỗng hoặc sai định dạng email/số điện thoại mà bấm gửi thẳng lên server, bắt server phải gánh lỗi 400.
9. **Lỗi So sánh Reference thay vì Value trong Riverpod State**:
   - *Lỗi*: Cập nhật trường của một object cũ rồi gán lại `state = oldState` ➔ Riverpod không phát hiện thay đổi và UI không tự update.
   - *Cách sửa*: Luôn dùng hàm `.copyWith()` để tạo instance state mới.
10. **Lỗi Bắt lỗi rỗng (`catch (e) {}`)**:
    - *Lỗi*: Bọc try/catch nhưng trong block catch không làm gì cả, user bấm nút không thấy phản hồi gì và tưởng app bị đơ.

---

## 📋 V. PRE-PUSH VERIFICATION CHECKLIST THEO NHÁNH

Trước khi tạo Merge Request (GitLab) hoặc Pull Request (GitHub), Agent bắt buộc tích đủ checklist tương ứng:

### 🦊 1. Nhánh Odoo 17 Backend (`v_mobile_17` ➔ Remote GitLab `17.0`):
- [ ] **Working Tree**: `git status` sạch, không có file tạm (`.pyc`, `.orig`, `__pycache__`).
- [ ] **Syntax Check**: Chạy `python3 -m py_compile $(git ls-files '*.py')` đạt 0 lỗi syntax.
- [ ] **N+1 & Rookie Audit**: Đã rà soát không có query trong vòng lặp `for`, không lỗi singleton, không mutable default arg.
- [ ] **XML Validation**: Toàn bộ file XML không còn bất kỳ thuộc tính `attrs=` nào.
- [ ] **Manifest & Version**: Đã cập nhật version trong `__manifest__.py` và changelog `docs/CHANGELOGS.md`.
- [ ] **Local Server Test**: Đã test restart container và update module thành công trên container `demo-17`:
  ```bash
  ssh local "docker exec demo-17 odoo -d demo-17 -u v_mobile --stop-after-init"
  ```
- [ ] **Git Rule**: Commit có trailer `Authored-By: 360org <support@360.org.vn>`. Đẩy lên task branch `fix/17-...` rồi tạo MR vào `17.0`. *(CẤM push thẳng vào `17.0`)*.

---

### 🦊 2. Nhánh Odoo 19 Backend (`v_mobile_19` ➔ Remote GitLab `19.0`):
- [ ] **Working Tree**: `git status` sạch, không file rác.
- [ ] **Syntax Check**: Chạy `python3 -m py_compile $(git ls-files '*.py')` đạt 0 lỗi syntax.
- [ ] **N+1 & Rookie Audit**: Đã rà soát không có N+1 query, singleton an toàn, không lộ credentials ra log.
- [ ] **Discuss Parity**: Endpoint chat/discuss tương thích chuẩn Odoo 19 (`discuss.channel`).
- [ ] **Manifest & Version**: Đã cập nhật version trong `__manifest__.py` và changelog `docs/CHANGELOGS.md`.
- [ ] **Local Server Test**: Đã test update module thành công trên container `odoo_dev_v19` / database `vcloud_test_v19`:
  ```bash
  ssh local "docker exec odoo_dev_v19 odoo -d vcloud_test_v19 -u v_mobile --stop-after-init"
  ```
- [ ] **Git Rule**: Commit có trailer `Authored-By: 360org <support@360.org.vn>`. Đẩy lên task branch `fix/19-...` rồi tạo MR vào `19.0`. *(CẤM push thẳng vào `19.0`)*.

---

### 🐙 3. Nhánh Frontend Flutter (`vclients` ➔ Remote GitHub `main`):
- [ ] **Static Analysis**: Chạy `flutter analyze` đạt **0 errors / 0 warnings**.
- [ ] **Unit Tests**: Chạy `flutter test` đạt 100% pass cho các bài test liên quan đến tính năng vừa sửa.
- [ ] **N+1 & Rookie Audit**: Đã kiểm tra `context.mounted` sau `await`, không dùng bang `!`, dispose 100% controllers.
- [ ] **Version Parity**: Phiên bản và build number trong `pubspec.yaml` khớp với `docs/CHANGELOGS.md`.
- [ ] **Web Build Check**: Chạy thử `flutter build web --no-pub` biên dịch thành công không văng lỗi.
- [ ] **Clean Code**: Không còn `print()` thô debug dữ liệu nhạy cảm, không thừa import.
- [ ] **Git Rule**: Commit có trailer `Authored-By: 360org <support@360.org.vn>`. Authoritative branch duy nhất là **`main`**. *(Nhánh cũ `release/ios-appstore` ĐÃ BỎ HOÀN TOÀN — CẤM DÙNG)*.

---

## 🧰 VI. KÍCH HOẠT BỘ CÔNG CỤ CHUYÊN TRÁCH AUDIT (SPECIALIZED AUDIT TOOLKIT)

Mỗi khi bước vào giai đoạn Review / Audit trước khi push, Lead Agent hoặc Subagent chuyên trách **BẮT BUỘC** kích hoạt đồng bộ 5 công cụ sau:

1. **Subagent `audit-gate`**:
   - Độc lập đối soát Git SHA thật giữa Local, GitLab và GitHub.
   - Thẩm tra bằng chứng runtime (log Docker thật, curl HTTP status thật), phát hiện các chiêu trò báo cáo pass ảo và kích hoạt Stop-The-Line nếu có sai phạm.
2. **Subagent `tester-security`**:
   - Quét mã nguồn tìm secret bị hardcode, kiểm tra Keychain/Keystore và rà soát các lỗ hổng Anti-IDOR, quyền record rules.
3. **Skill `audit-gate` & `code-review`**:
   - Soi 4 trục code: *Correctness* (logic đúng), *Reuse* (tái sử dụng code cũ), *Over-engineering* (tối giản theo Ponytail), *Security* (bảo mật biên giới).
4. **Lệnh Slash `/ponytail-audit`**:
   - Đo lường độ tối giản của diff, loại bỏ các abstraction thừa, cấu hình không đổi hoặc boilerplate vô nghĩa.
5. **Widget Desktop `ReportFindings`**:
   - Xuất danh sách lỗi có cấu trúc (typed findings) hiển thị trực quan lên giao diện Claude Desktop cho Sếp Tân xem trước khi duyệt.

---

## 📊 VII. MẪU BÁO CÁO NGHIỆM THU CHUẨN TRƯỚC KHI PUSH CODE (PRE-PUSH AUDIT REPORT)

Báo cáo nghiệm thu gửi Sếp Tân **BẮT BUỘC dưới 1.200 ký tự**, trình bày cô đọng dạng bảng theo mẫu:

```markdown
### 🛡️ BÁO CÁO AUDIT PRE-PUSH CODE — VCLOUD SUITE
- **Task / Feature**: [Tên tính năng hoặc mã bug fix]
- **Target Branches**: GitLab `17.0` | GitLab `19.0` | GitHub `main`
- **Audit Confidence**: L4 — VERIFIED (Chứng minh bằng test runtime thật)

| Trục Kiểm Toán | Kết Quả | Bằng Chứng Kỹ Thuật (Evidence) |
|---|---|---|
| **1. Tối ưu hệ thống** | ✅ ĐẠT | 0 N+1 query, dispose 100% controller, payload có pagination |
| **2. Đúng Version** | ✅ ĐẠT | `pubspec.yaml` v2.9.12+144, manifest 17/19 đồng bộ changelog |
| **3. An toàn bảo mật**| ✅ ĐẠT | Anti-IDOR verified, 0 plain password log, SecureStorage active |
| **4. Chịu tải & Concur**| ✅ ĐẠT | Async push notification, worker pool an toàn, timeout 15s |
| **5. Diệt lỗi ngớ ngẩn**| ✅ ĐẠT | 0 singleton crash, đã check context.mounted, không bang (!) |

- **Verification Runtime**:
  * `flutter analyze`: 0 errors / 0 warnings.
  * Backend Local Server: Docker update `demo-17` & `odoo_dev_v19` PASS 100%.
- **Đề xuất**: Kính đề nghị Sếp Tân duyệt mở Merge Request / Push code lên remote!
```

---

## 🛑 VIII. QUY TRÌNH STOP-THE-LINE & ROLLBACK GUARD

Nếu trong quá trình kiểm toán phát hiện bất kỳ vi phạm nào sau đây:
1. `flutter analyze` có cảnh báo hoặc lỗi.
2. Update module Odoo trên Local Server văng traceback hoặc lỗi registry.
3. Phát hiện lỗi N+1 query lặp trong vòng lặp hoặc lỗi ngớ ngẩn (`context.mounted`, bang `!`, `Expected singleton`).
4. Phát hiện endpoint thiếu kiểm tra quyền sở hữu (IDOR) hoặc log lộ mật khẩu/token.
5. Lệch build number giữa `pubspec.yaml` và changelog.
6. Push trực tiếp vào các nhánh bảo vệ `17.0`, `19.0` mà không thông qua Merge Request.

🚨 **HÀNH ĐỘNG BẮT BUỘC**:
- **DỪNG LẠI NGAY LẬP TỨC (STOP-THE-LINE)**.
- **KHÔNG THỰC HIỆN LỆNH GIT PUSH**.
- Báo cáo rõ ràng lỗi phát hiện cho Sếp Tân và kích hoạt Subagent `@dev` phẫu thuật sửa dứt điểm root cause trước khi chạy lại quy trình audit.
