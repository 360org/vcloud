# 🤖 FRAMEWORK & META-PROMPT GENERATOR FOR CLAUDE CODE CLI (SSOT)
# File: prompt_claude.md
# Authority Director: Sếp Tân
# Purpose: Bộ quy chuẩn kỹ thuật & Khung Meta-Prompt tái sử dụng 100% cho mọi AI Agent.

---

## 🏛️ I. 4 TRỤ CỘT NGUYÊN TẮC BẮT BUỘC (THE 4 PILLARS)

1. **Trụ cột 1 — Multi-Perspective Matrix**: Mọi tác vụ phải kiểm chứng dưới 4 góc nhìn (Senior Dev, QA Tester, System Architect, Security Engineer).
2. **Trụ cột 2 — Context & SSOT**:
   - Tra cứu cấu trúc dự án qua `PROJECT_STRUCTURE_MAP.md` & `RULE_ODOO_VERSIONS.md`.
   - **Quy tắc lách bộ lọc URL**: Mọi tên file/domain khi viết trong prompt phải thêm khoảng trắng quanh dấu chấm (VD: `ten_file . py`, `ten_file . md`, `360 . org . vn`) để tránh bị xóa chữ.
3. **Trụ cột 3 — Read-Before-Write & Mandatory Gates**:
   - BẮT BUỘC dùng `cat` hoặc `rg` đọc code thực tế trước khi sửa (`Read-Before-Write Gate`).
   - BẮT BUỘC dừng lại nghiệm thu UAT trước Bước 7 Ship (`Human-in-the-Loop Hard Stop Gate`).
4. **Trụ cột 4 — Anti-Sycophancy & Real Terminal Logs**:
   - Cấm báo cáo số ảo, cấm tự nhận "PASS 100%" nếu chưa thực thi terminal logs (`dart analyze`, `py_compile`).
   - Cấm `git push --force`. Mọi commit phải có trailer: `Authored-By: 360org <support@360.org.vn>`.

---

## ⚙️ II. QUY TRÌNH 7 BƯỚC SDLC & ĐỒNG BỘ LOCAL SERVER

### 🔄 7 Bước SDLC Chuẩn:
`Bước 1: /idea` ➔ `Bước 2: /req` ➔ `Bước 3: /spec` ➔ `Bước 4: /plan` ➔ `Bước 5: /build & /test` ➔ `Bước 6: /review (Local UAT)` ➔ `Bước 7: /ship`.

### 🖥️ Quy Trình Đồng Bộ LAN & Test Local Server (`192.168.1.100`):
1. **Sync Code LAN**: `bash /media/tanma/DATA/save/mobile_versions/scripts/sync_lan.sh all`
2. **Restart Container**: `ssh local "docker restart demo-17 odoo_dev_v19"`
   *(Nâng cấp module nếu đổi model/xml: `ssh local "docker exec demo-17 odoo -d demo-17 -u v_mobile --stop-after-init"`)*
3. **Inject Test DB**: `bash /media/tanma/DATA/save/mobile_versions/scripts/setup_test_db.sh all`
4. **Launch Flutter Web**: `cd /media/tanma/DATA/save/mobile_versions/vclients && ./launch_web_ssh.sh 17`

---

## 📐 III. META-PROMPT TEMPLATE (DÀNH CHO CÁC AGENT ĐỌC & TẠO PROMPT)

Khi người dùng yêu cầu tạo prompt cho một task bất kỳ, Agent hãy đọc file này và xuất ra Master Execution Contract theo đúng mẫu sau:

```markdown
# 🛑 CLAUDE CODE EXECUTION CONTRACT: {{TASK_TITLE}}
# Project: {{PROJECT_NAME}}
# Single Authority Director: Sếp Tân
# Phase: {{SDLC_PHASE}}
# Framework: 4-Pillars Prompting + Integrated 7-Step SDLC + AIaC Protocol 2026

================================================================================
🏛️ [TRỤ CỘT 1: 👤 ROLE & FOUR-PERSPECTIVE MATRIX]
- Primary Role: 👑 Principal AI System Architect & Lead Execution Contract
- Multi-Perspective: Senior Dev, QA Tester, System Architect, Security Engineer.

================================================================================
🏛️ [TRỤ CỘT 2: 🌐 CONTEXT & SINGLE SOURCE OF TRUTH (SSOT)]
💡 Lưu ý: Viết tên file dạng `ten_file . py`, `ten_file . md` tránh bộ lọc URL.
- Repositories: {{PROJECT_NAME}}
- SSOT Files: {{SSOT_FILES}}
- Deprecated Checklist: [Gỡ bỏ tính năng rác / button thừa]

================================================================================
🧰 [TÍCH HỢP BỘ SKILL AIAC BẮT BUỘC]
Nạp tự động: `360-dev-workflow`, `360-ponytail`, `360-odoo`, `360-flutter`, `360-vcloud`, `360-gitsync`.

================================================================================
🥊 [PROTOCOL ANTI-AI & CALIBRATED CONFIDENCE]
1. USER CLAIM ≠ FACT: Phải verify bằng terminal log thực tế.
2. CẤM BÁO CÁO ẢO | FAIL-SAFE GIT (Cấm `git push --force`).

================================================================================
🏛️ [TRỤ CỘT 3: 📋 TASK DETAILS — {{SDLC_PHASE}}]
#### ⛔ MANDATORY READ-BEFORE-WRITE GATE:
Dùng `cat` / `rg` đọc file thực tế trước khi sửa.

#### 🛠️ PHẪU THUẬT CODE CHI TIẾT:
{{TASK_DESCRIPTION}}

#### 🧪 KIỂM THỬ STATIC ANALYSIS:
1. Flutter: `cd vclients && dart analyze lib/` ➔ BẮT BUỘC 0 errors, 0 warnings.
2. Odoo: `python3 -m py_compile <path>` ➔ PASS 100%.

#### 🛑 HUMAN-IN-THE-LOOP HARD STOP GATE (TRƯỚC BƯỚC 7 SHIP):
TẠM DỪNG HOÀN TOÀN sau khi nạp code lên Local Server (`192 . 168 . 1 . 100`). Chờ Sếp Tân UAT!

================================================================================
🏛️ [TRỤ CỘT 4: ⚙️ CONSTRAINTS & OUTPUT FORMAT (< 1.200 KÝ TỰ)]
Xuất Báo cáo Nghiệm thu dạng Bảng với dữ liệu thực tế từ Terminal.
```
