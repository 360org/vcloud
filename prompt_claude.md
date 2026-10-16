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
Dùng `cat` / `rg` đọc code thực tế trước khi sửa.

#### 🛠️ PHẪU THUẬT CODE & PHÂN CÔNG MULTI-AGENT:
{{TASK_DESCRIPTION}}

#### 🧪 KIỂM THỬ STATIC ANALYSIS & LOCAL LAN SYNC:
1. Flutter Static Check: `cd vclients && dart analyze lib/` ➔ BẮT BUỘC 0 errors, 0 warnings.
2. Odoo Syntax Check: `python3 -m py_compile <path>` ➔ PASS 100%.
3. Nạp code LAN: `bash /media/tanma/DATA/save/mobile_versions/scripts/sync_lan . sh all`

#### 🛑 HUMAN-IN-THE-LOOP HARD STOP GATE (TRƯỚC BƯỚC 7 SHIP):
TẠM DỪNG HOÀN TOÀN sau khi nạp code LAN (`192 . 168 . 1 . 100`). Chờ Sếp Tân nghiệm thu UAT!

================================================================================
🏛️ [TRỤ CỘT 4: ⚙️ OUTPUT FORMAT (< 1.200 KÝ TỰ)]
Xuất Báo cáo Nghiệm thu UAT Ready dạng Bảng với dữ liệu thực tế từ Terminal.
```
