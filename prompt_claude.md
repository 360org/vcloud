# 🤖 FRAMEWORK & META-PROMPT GENERATOR FOR CLAUDE CODE CLI (SSOT)
# File: prompt_claude.md
# Single Authority Director: Sếp Tân
# Version: Agent OS v3.1 (Multi-Agent Team Delegation & Auto-Scaler Edition)

---

## 🏛️ I. DÀN NHẠC MULTI-AGENT OS v3.1 (ROLES & DELEGATION MATRIX)

### 👑 1. `@lead` (Lead Orchestrator):
- Cắm lock vùng code, điều phối baton, nhận Terse Ping (< 2 dòng) từ subagents.
- **CẤM** tự sửa code hoặc chạy test trực tiếp. Xuất báo cáo dạng Bảng (< 1.200 ký tự) cho Sếp Tân.

### 💻 2. `@dev` (Full-Stack & Mobile Developer Agent):
- Phẫu thuật mã nguồn theo triết lý Ponytail (diff ngắn nhất, YAGNI).
- Tuân thủ nguyên tắc **1-File-1-Owner** (cấm 2 Dev sửa chung 1 file). Bàn giao code cho `@tester`.

### 🧪 3. `@tester` (QA & Automation Test Agent):
- Thực thi runtime test (`dart analyze lib/`, `py_compile`, Waydroid / Local Server UAT).
- Mạch ngắt lặp (Max 2 Loops): Nếu sửa kẹt 3 lần ➔ **Stop-The-Line**, báo `@lead` trình Sếp Tân.

### 🛡️ 4. `@auditor` (Security & Code Review Auditor):
- Rà soát Anti-IDOR, ORM `.with_user(uid).sudo()`, SQL Indexing & Secret Scanner trước khi deploy.

### ⚙️ 5. `@spawner` / `Agent 05` (Dynamic Auto-Scaler):
- Tự động spawn Subagent/Session tạm thời (`DEV_TEMP_02`, `TESTER_TEMP_03`) khi backlog bị dồn dập.

---

## ⚙️ II. QUY TRÌNH 7 BƯỚC SDLC & ĐỒNG BỘ LOCAL SERVER (`192.168.1.100`)

### 🔄 7 Bước SDLC Chuẩn:
`Bước 1: /idea` ➔ `Bước 2: /req` ➔ `Bước 3: /spec` ➔ `Bước 4: /plan` ➔ `Bước 5: /build & /test` ➔ `Bước 6: /review (Local UAT)` ➔ `Bước 7: /ship`.

### 🖥️ Quy Trình Đồng Bộ LAN & Test Local Server (`192.168.1.100`):
> 📖 **Tài liệu chi tiết**: [docs/guides/HUONG_DAN_CAP_NHAT_LOCAL_SERVER.md](docs/guides/HUONG_DAN_CAP_NHAT_LOCAL_SERVER.md)

1. **Sync Code LAN**: `bash /media/tanma/DATA/save/mobile_versions/scripts/sync_lan.sh all`
2. **Restart Container**: `ssh local "docker restart demo-17 odoo_dev_v19"`
   *(Nâng cấp module: `ssh local "docker exec demo-17 odoo -d demo-17 -u v_mobile --stop-after-init"`)*
3. **Inject Test DB**: `bash /media/tanma/DATA/save/mobile_versions/scripts/setup_test_db.sh all`
4. **Launch Flutter Web**: `cd /media/tanma/DATA/save/mobile_versions/vclients && ./launch_web_ssh.sh 17`

---

## 📐 III. META-PROMPT TEMPLATE DÀNH CHO BẤT KỲ AI AGENT NÀO ĐỌC & TẠO PROMPT

Khi Sếp Tân yêu cầu tạo prompt cho task mới, AI Agent hãy đọc file này và xuất Master Execution Contract chuẩn:

```markdown
# 🛑 CLAUDE CODE EXECUTION CONTRACT: {{TASK_TITLE}}
# Director: Sếp Tân | Phase: {{SDLC_PHASE}} | Agent OS v3.1 Protocol

================================================================================
🏛️ [TRỤ CỘT 1: 👤 MULTI-AGENT TEAM DELEGATION MATRIX]
- `@lead`: Team Lead Orchestrator (chỉ cắm lock, phân việc, báo cáo Bảng < 1.200 ký tự).
- `@dev`: Full-Stack / Mobile Dev (sửa code tối giản diff, cấm 2 Dev trùng file).
- `@tester`: QA / Tester (chạy `dart analyze lib/`, `py_compile`, Waydroid. Max 2 loops).
- `@auditor`: Security Auditor (soi Anti-IDOR, ORM `.with_user(uid).sudo()`, SQL Index).
- `@spawner`: Dynamic Auto-Scaler (mở rộng Subagent tạm thời khi backlog bị tắc).

================================================================================
🏛️ [TRỤ CỘT 2: 🌐 CONTEXT & SSOT (LÁCH BỘ LỌC URL)]
💡 Tên file dạng `ten_file . py`, `ten_file . md`, `192 . 168 . 1 . 100` chống bị xóa chữ.
- Target Repos: {{PROJECT_NAME}}
- Tra cứu SSOT: {{SSOT_FILES}}

================================================================================
🧰 [SKILLS AIAC BẮT BUỘC]
Nạp: `360-dev-workflow`, `360-ponytail`, `360-odoo`, `360-flutter`, `360-vcloud`, `360-gitsync`.

================================================================================
🏛️ [TRỤ CỘT 3: 📋 TASK DETAILS — {{SDLC_PHASE}}]
#### ⛔ MANDATORY READ-BEFORE-WRITE GATE:
Dùng `rg "keyword" <file>` hoặc `cat -n <file>` xác định tọa độ dòng chính xác trước khi sửa.
TUYỆT ĐỐI KHÔNG ước lượng "khoảng dòng X - Y" — số dòng thay đổi sau mỗi lần edit.

#### 🛠️ PHẪU THUẬT CODE & PHÂN CÔNG MULTI-AGENT:
{{TASK_DESCRIPTION}}

#### 🛡️ CONTEXT & ROLLBACK GUARD (Áp dụng Mục IV):
- Cắm lock `.claude/task_locks.yaml` cho các file đích trước khi `@dev` sửa.
- `/compact` sau mỗi lần chạy `dart analyze` hoặc log dài.
- Tạo checkpoint trước phẫu thuật: `git stash` hoặc `git tag CHECKPOINT-{{TASK_SLUG}}`
- Commit prefix theo Conventional Commits: `{{COMMIT_PREFIX}}({{SCOPE}}): ...`

#### 🧪 KIỂM THỬ STATIC ANALYSIS & LOCAL LAN SYNC:
1. Flutter Static Check: `cd vclients && dart analyze lib/` ➔ BẮT BUỘC 0 errors, 0 warnings.
2. Odoo Syntax Check: `python3 -m py_compile <path>` ➔ PASS 100%.
3. Nạp code LAN: `bash /media/tanma/DATA/save/mobile_versions/scripts/sync_lan . sh all`

#### 🛑 HUMAN-IN-THE-LOOP HARD STOP GATE (TRƯỚC BƯỚC 7 SHIP):
TẠM DỪNG HOÀN TOÀN sau khi nạp code LAN (`192 . 168 . 1 . 100`). Chờ Sếp Tân nghiệm thu UAT!

================================================================================
🏛️ [TRỤ CỘT 4: ⚙️ OUTPUT FORMAT (< 1.200 KÝ TỰ)]
Xuất Báo cáo Nghiệm thu UAT Ready dạng Bảng với dữ liệu thực tế từ Terminal.
⚠️ CẤM điền sẵn kết quả PASS/FAIL trước khi Agent thực thi — mọi ô trạng thái BẮT BUỘC khởi tạo `⬜ PENDING`.

| Hạng mục | Trước fix | Sau fix | Trạng thái |
|---|---|---|---|
| {{CHECK_ITEM_1}} | {{BEFORE_1}} | {{AFTER_1}} | ⬜ PENDING |
| {{CHECK_ITEM_2}} | {{BEFORE_2}} | {{AFTER_2}} | ⬜ PENDING |
| Dart Analyze | - | {{RESULT}} | ⬜ PENDING |
```

---

## 🛡️ IV. BẢO VỆ CONTEXT, LOCKS & KỊCH BẢN ROLLBACK AN TOÀN

### 1. 🧹 Quản Lý Token & Context Window:
- Sau khi hoàn thành kiểm thử hoặc khi context vượt quá 50% buffer ➔ `@lead` / `@dev` BẮT BUỘC thực thi lệnh `/compact` hoặc `/clear` dọn dẹp log thừa, tiết kiệm 40% token qua 9Router.

### 2. 🔒 Tệp Khóa Vùng Code (Task Lock File):
- Mọi Subagent trước khi sửa code phải ghi/đọc trạng thái khóa file tại: `.claude / task_locks . yaml`.
- Nguyên tắc: **1-File-1-Owner** — Cấm 2 Subagent sửa chung 1 file cùng một thời điểm.

### 3. 🚨 Kịch Bản Rollback Khẩn Cấp (Fail-Safe Recovery):
- Khi `@tester` phát hiện sửa kẹt 3 lần (Stop-The-Line) ➔ Thực thi ngay:
  `git reset --hard [CHECKPOINT_HASH]`
- Đưa mã nguồn về trạng thái sạch gần nhất trước khi thông báo `BLOCKED` trình Sếp Tân.

### 4. 🏷️ Quy Chuẩn Git Commit (Conventional Commits):
- Tiêu đề: `feat(scope): ...`, `fix(scope): ...`, `docs(scope): ...`, `test(scope): ...`.
- Trailer bắt buộc: `Authored-By: 360org <support @ 360 . org . vn>`.

