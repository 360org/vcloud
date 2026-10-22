# 🤖 FRAMEWORK & META-PROMPT GENERATOR FOR CLAUDE CODE CLI (SSOT)
# File: prompt_claude.md
# Single Authority Director: Sếp Tân
# Version: Agent OS v3.1 (Multi-Agent Team Delegation & Auto-Scaler Edition)

## 📑 MỤC LỤC NHANH (TABLE OF CONTENTS)

| Mục | Nội dung | Dòng |
|---|---|---|
| **I** | Dàn Nhạc Multi-Agent OS v3.1 (5 Roles) | `@lead`, `@dev`, `@tester`, `@auditor`, `@spawner` |
| **II** | 7 Bước SDLC & Đồng Bộ Local Server | SSOT Files, LAN Sync `192.168.1.100` |
| **III** | Meta-Prompt Template (Agent đọc & tạo prompt) | 4 Trụ Cột + Anti-Sycophancy L0-L5 |
| **IV** | Bảo Vệ Context, Locks & Rollback | `/compact`, `task_locks.yaml`, Checkpoint, Conventional Commits |
| **V** | Changelog & Chống Lạm Phát Version | 5 Tags `[NEW/FIX/IMPROVE/REFACTOR/SECURITY]` |
| **VI** | Manifest & Đồng Bộ Phiên Bản | `pubspec.yaml` SSOT, `__manifest__.py` format |
| **VII** | Deploy & CI/CD Pipeline 3 Tầng | LAN → Odoo SaaS → TestFlight & Google Play |
| **VIII** | Rào Chắn Odoo 17 & 19 (Mandatory Gate) | Field Mapping, ORM, XML, Porting 7 bước |
| **IX** | Zero-Trust Execution Gate (10 điều) | Task Mode, Read Before Write, Preserve Work, Least Privilege, Side-Effect, Agent Cap, Evidence, UI/Release, Final Report, SSOT Update |
| **X** | Tiếp Nhận Báo Cáo & Phân Rã Việc | Fact-Check chống bịa ➔ Root Cause ➔ Multi-Agent Dispatch chống chạy lâu |

---

## 🏛️ I. DÀN NHẠC MULTI-AGENT OS v3.1 (ROLES & DELEGATION MATRIX)

### 👑 1. `@lead` (Lead Orchestrator — Nhận Master Contract & Dispatch Bắt Buộc):
- Cắm lock vùng code, điều phối baton, nhận Terse Ping (< 2 dòng) từ subagents.
- ⛔ **CẤM TUYỆT ĐỐI** tự gõ lệnh terminal sửa code hoặc chạy test trực tiếp (chống phình to transcript và tràn RAM context).
- 🚨 **MANDATORY AGENT DISPATCH DIRECTIVE**: BẮT BUỘC gọi tool `Agent` để ủy quyền thực thi cho đội ngũ Subagent chuyên trách:
  * Backend Odoo / Fix bug Python / Sửa cấu hình: `Agent({ subagent_type: 'dev-backend-odoo', prompt: '...' })`
  * Frontend Flutter / Dart UI: `Agent({ subagent_type: 'dev-mobile-flutter', prompt: '...' })`
  * Kiểm thử UAT / Runtime / WebSocket: `Agent({ subagent_type: 'tester-functional', prompt: '...' })`
  * Rà soát Bảo mật / Registry / Permissions: `Agent({ subagent_type: 'tester-security', prompt: '...' })` hoặc `audit-gate`
- `@lead` chỉ đứng ngoài tổng hợp số liệu đo lường thực tế từ Subagents và xuất báo cáo dạng Bảng (< 1.200 ký tự) cho Sếp Tân.

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

### 📚 SSOT Files Agent BẮT BUỘC Đọc Trước Khi Bắt Tay:
- `docs/PROJECT_STRUCTURE_MAP.md` — Matrix định vị nhanh file theo tính năng.
- `docs/features.md` — Danh mục 71 tính năng & trạng thái verified.
- `docs/guides/TAI_KHOAN_TEST.md` — Database test, port, tài khoản & hạ tầng Docker Local Server.
- `docs/rules/RULE_ODOO_VERSIONS.md` — Quy chuẩn phân version Backend 17 vs 19.

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
🏛️ [TRỤ CỘT 1: 👤 MULTI-AGENT TEAM DELEGATION MATRIX & DISPATCH DIRECTIVE]
🚨 LUẬT BẮT BUỘC DISPATCH (CẤM ÔM ĐỒM TRONG 1 PHIÊN):
- `@lead`: Team Lead Orchestrator (cắm lock, phân việc, báo cáo Bảng < 1.200 ký tự).
  ⛔ **CẤM** @lead tự chạy lệnh terminal sửa code hoặc chạy test trực tiếp.
  🚨 **BẮT BUỘC** gọi tool `Agent` ủy quyền cho Subagent chuyên trách:
  * Giao Dev sửa code: `Agent({ subagent_type: 'dev-backend-odoo' | 'dev-mobile-flutter', prompt: '...' })`
  * Giao Tester kiểm thử: `Agent({ subagent_type: 'tester-functional' | 'tester-security', prompt: '...' })`
- `@dev`: Full-Stack / Mobile Dev (chuyên trách phẫu thuật code theo Ponytail, 1-File-1-Owner).
- `@tester`: QA / Automation Tester (chuyên trách kiểm thử runtime, WebSocket, UAT. Max 2 loops).
- `@auditor`: Security & Architecture Auditor (soi Anti-IDOR, ORM singleton, SQL Index, Registry).
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
#### 📖 MANDATORY SSOT READ & STATUS AUDIT GATE (BẮT BUỘC ĐỌC TRƯỚC KHI LÀM):
Agent BẮT BUỘC đọc file SSOT chỉ định (ví dụ: `vclients/docs/features . md`, `docs/idea_portal . md`, `docs/PROJECT_STRUCTURE_MAP . md`):
- Nắm rõ: Mục nào ĐÃ LÀM (có tag `[x]`), mục nào ĐANG LÀM, và mục nào CHƯA LÀM (tồn đọng).
- Nắm vững tiêu chuẩn nghiệm thu và các defect thực tế đã phát hiện từ ảnh UAT/log trước khi đụng vào code.

#### ⛔ MANDATORY READ-BEFORE-WRITE & TRAINED SSH/TERMINAL GUARDRAILS:
1. **Tọa độ file:line & Before/After**: Dùng `rg "keyword" <file>` hoặc `cat -n <file>` xác định tọa độ dòng chính xác trước khi sửa. BẮT BUỘC có trích đoạn code TRƯỚC và SAU. TUYỆT ĐỐI KHÔNG ước lượng khoảng dòng hay dùng `replace()` mù quáng.
2. **Khóa cứng cách sửa file qua SSH Terminal**: TUYỆT ĐỐI CẤM gõ script Python inline dài (> 2.000 bytes, multi-line) vào `run_in_terminal` vì sẽ bị terminal hook chặn (lỗi byte limit, multi-line, zsh glob). BẮT BUỘC tạo file script `/tmp/patch_xxx.py` qua `cat << 'EOF'` trên server rồi mới chạy, hoặc sửa file cục bộ rồi rsync/sync_lan.
3. **Cấm tự ý sửa hạ tầng (`odoo.conf`)**: CẤM tự ý hạ `workers = 0` (ThreadedServer) để che giấu lỗi WebSocket. Container chạy chuẩn `workers = 4`.
4. **Khóa chặt Target Database**: BẮT BUỘC thao tác đúng Database mục tiêu được chỉ định (vd: `vcloud_test_v19`, `vuahethong_v19_prod_test`). CẤM query các database rác khác.

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

#### 📝 MANDATORY POST-TASK SSOT UPDATE GATE (BẮT BUỘC CẬP NHẬT FILE SAU KHI LÀM):
Sau khi code và chạy test pass, Agent BẮT BUỘC mở và cập nhật trực tiếp vào file SSOT (`features . md` và `docs/...`):
1. Chuyển trạng thái `[ ]` sang `[x]` đối với các tiêu chí/hạng mục đã giải quyết và test pass.
2. Ghi rõ Evidence kiểm thử (tên file test, số lượng test case pass, kết quả static check).
3. Liệt kê rõ: Hạng mục ĐÃ LÀM XONG vs Hạng mục CÒN TỒN ĐỌNG / CHƯA LÀM (để người sau tiếp quản ngay không bị mơ hồ).
⛔ **CẤM BÁO CÁO HOÀN THÀNH NẾU CHƯA CẬP NHẬT FILE SSOT!**

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

================================================================================
🥊 [ANTI-SYCOPHANCY & CALIBRATED CONFIDENCE PROTOCOL]
1. **USER CLAIM ≠ FACT**: Mọi phát biểu của Sếp hay Agent chỉ là `HYPOTHESIS`, phải verify bằng terminal log thực tế.
2. **Thang Confidence L0-L5**: L0 Unknown → L1 Hypothesis → L2 Supported (đọc code) → L3 Reproduced (có log) → L4 Verified (patch + test pass) → L5 Production-Verified. **CẤM nhảy từ L2 lên L4/L5**.
3. **CẤM số ảo**: Không dùng "100%", "hoàn hảo", "không còn lỗi" nếu không có đo lường thống kê. `All tests passed` ≠ `System is 100% correct`.
4. **SCOPE OF EVIDENCE = SCOPE OF CLAIM**: Cấm suy luận từ local → production, từ 10 test → toàn bộ feature, từ Odoo 17 → Odoo 19.
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

---

## 📝 V. QUY CHUẨN QUẢN TRỊ CHANGELOG & CHỐNG LẠM PHÁT VERSION

### 1. File SSOT Lưu Trữ Changelog:
- **Frontend (`vclients`)**: `docs/CHANGELOGS.md`
- **Backend Odoo 17 & 19**: `docs/CHANGELOGS.md` và trường `description` trong `__manifest__.py`.

### 2. Định Dạng Tag Thay Đổi Bắt Buộc:
Mọi mục thay đổi trong Changelog phải gán đúng 1 trong các Tag:
- `[NEW]`: Tính năng phát triển mới.
- `[FIX]`: Khắc phục lỗi / Vá bug.
- `[IMPROVE]`: Tối ưu hiệu năng / UI/UX.
- `[REFACTOR]`: Tái cấu trúc mã nguồn (không đổi logic).
- `[SECURITY]`: Vá lỗ hổng bảo mật / IDOR / CORS.

### 3. Quy Tắc Thép Chống Lạm Phát Version (Zero Version Inflation):
- Đang làm việc trên Version/Build nào thì **tiếp tục ghi nhận toàn bộ thay đổi ở Version đó**.
- ⛔ **CẤM TỰ Ý NHẢY CÓC VERSION**: Tuyệt đối không tạo Version mới trong Changelog khi Version hiện tại chưa được deploy TestFlight, chưa test thực tế trên thiết bị của Sếp Tân và chưa merge/xóa branch.

---

## 📦 VI. QUY CHUẨN MANIFEST & ĐỒNG BỘ PHIÊN BẢN (VERSIONING)

### 1. Flutter Frontend (`vclients/pubspec.yaml`):
- Format chuẩn: `version: X.Y.Z+BUILD` (Ví dụ: `2.9.15+152`).
- **Quy tắc Single Source of Truth**: Số `BUILD` trong `pubspec.yaml` là căn cứ tối cao cho Apple App Store Connect & Google Play Console. Cấm để CI/CD tự sinh build number ngẫu nhiên.

### 2. Odoo Backend (`v_mobile_17` & `v_mobile_19`):
- Odoo 17 Format: `17.0.X.Y.Z` trong `v_mobile_17/__manifest__.py`.
- Odoo 19 Format: `19.0.X.Y.Z` trong `v_mobile_19/__manifest__.py`.
- Bắt buộc đồng bộ tóm tắt Changelog mới nhất vào trường `'description'` của `__manifest__.py` khi nâng cấp version.

---

## 🚀 VII. QUY TRÌNH DEPLOY & TỰ ĐỘNG HÓA CI/CD PIPELINE

### 1. Deploy Tầng 1 — Thử Nghiệm Nội Bộ LAN (`192.168.1.100`):
- Sync code 0.5s: `bash /media/tanma/DATA/save/mobile_versions/scripts/sync_lan.sh all`
- Restart / Upgrade: `ssh local "docker restart demo-17 odoo_dev_v19"` (Thêm `-u v_mobile` nếu đổi Models/Views).
- Inject Test DB: `bash /media/tanma/DATA/save/mobile_versions/scripts/setup_test_db.sh all`
- Launch Web: `cd vclients && ./launch_web_ssh.sh 17` (hoặc `19`).

### 2. Deploy Tầng 2 — Backend Odoo SaaS Live (vuahethong.net):
- Checkout nhánh `17.0` (Odoo 17) hoặc `19.0` (Odoo 19) đã được Merge MR.
- Thực thi nâng cấp Module Odoo Zero-Downtime trên Pod/Server.
- 🚨 **CẢNH BÁO TỐI QUAN TRỌNG KHI DEPLOY BACKEND**: Tuyệt đối **KHÔNG SỬA CODE / ĐỔI LOGIC API** trong lúc deploy. Nếu sửa sai làm 246 bài test bị FAIL ➔ GitHub Actions CI/CD Frontend sẽ bị **LỖI ĐỎ (BUILD FAILED)** ➔ Chặn hoàn toàn việc ra bản build TestFlight mới!

### 3. Deploy Tầng 3 — Frontend Release Store (TestFlight & Google Play):
- **Apple TestFlight**: Khi Merge PR vào `main` ➔ GitHub Actions (`deploy.yml`) tự động kích hoạt build IPA và nộp lên TestFlight cho iPhone của Sếp Tân.
- **Google Play Console (Direct-to-Production)**: 1 Giai đoạn duy nhất — Đẩy thẳng tệp `.aab` vào **Production Track** trên CH Play, bỏ qua các bước thử nghiệm rườm rà.

---

## 🛡️ VIII. RÀO CHẮN CHUẨN KỸ THUẬT PHÂN ĐỊNH ODOO 17 & ODOO 19 (MANDATORY GATE)

### 1. Phân Định Repo & Authoritative Branches (Cấm Merge/Copy Mù Quáng):
- **Odoo 17 Backend (`v_mobile_17`)**: Nhánh bảo vệ `17.0` (Target DB: `demo-17`, Version: `17.0.X.Y.Z`).
- **Odoo 19 Backend (`v_mobile_19`)**: Nhánh bảo vệ `19.0` (Target DB: `vcloud_test_v19`, Version: `19.0.X.Y.Z`).
- ⛔ **CẤM TỰ Ý COPY HOẶC MERGE TRỰC TIẾP** giữa `17.0` và `19.0`. Mọi thay đổi cross-version phải qua quy trình Porting 7 bước.

### 2. Ma Trận Ánh Xạ Trường Dữ Liệu & Relation Mapping:
| Phân Hệ Nghiệp Vụ | Odoo 17.0 (`v_mobile_17`) | Odoo 19.0 (`v_mobile_19`) | Lỗi Nếu Dùng Lệch |
| :---: | :--- | :--- | :--- |
| **Chat / Discuss** | `channel_partner_ids` | `channel_member_ids` | HTTP 500 / AttributeError |
| **Security Groups** | `groups_id` | `group_ids` | Không nhận quyền / UserError |
| **DB Constraints** | `_sql_constraints` | `models.Constraint()` | Warnings / Deprecated |
| **DB Indexing** | `index=True` | `models.Index("(col1, col2)")` | **Crash Registry Odoo 19** |

### 3. Quy Chuẩn ORM & XML Views Bắt Buộc:
- **ORM Search & Aggregation**:
  * Odoo 19: BẮT BUỘC dùng `_read_group` (loại bỏ hoàn toàn `read_group` kiểu cũ).
  * Odoo 17: Duy trì các phương thức ORM chuẩn của v17.
- **XML Views**:
  * Khai báo điều kiện: BẮT BUỘC dùng `invisible="..."`, `readonly="..."`, `required="..."`.
  * ⛔ **CẤM DÙNG `attrs="..."`** trên cả Odoo 17 và 19.
- **Bảo mật & Context Singleton**:
  * Mọi thao tác ghi/tạo dữ liệu Discuss BẮT BUỘC dùng `.with_user(uid).sudo()` để nạp ngữ cảnh `res.users` singleton.
  * Portal Isolation Guard: Kiểm tra `is_portal_uid(uid)` / `share=True` chặn 100% tài khoản Portal truy cập route/data nội bộ (HTTP 403).

---

## 🔐 IX. ZERO-TRUST EXECUTION GATE (BẮT BUỘC MỌI AGENT TUÂN THỦ)

### 1. 🏷️ Task Mode:
- Phân loại task thành `IDEA`, `REQ`, `SPEC`, `AUDIT`, `BUILD`, `TEST`, `REVIEW` hoặc `SHIP`. Chỉ thực hiện các bước phù hợp.
- `AUDIT` / `REVIEW` mặc định **chỉ đọc**; không tự sửa code.

### 2. 📖 Read Before Write:
- Đọc `CLAUDE.md`, `AGENTS.md`, `.agents/rules/*` nếu tồn tại, SSOT liên quan và cấu trúc repo thực tế.
- Kiểm tra lệnh, file, tool, branch và môi trường trước khi sử dụng.
- Khi phát hiện xung đột quy tắc, phải **nêu rõ**, không tự ý bỏ qua.

### 3. 🛡️ Preserve Existing Work:
- Trước khi sửa, kiểm tra `git status --short` và diff hiện tại.
- Bảo toàn tất cả thay đổi có sẵn và ngoài phạm vi task.
- ⛔ **KHÔNG** tự ý chạy `git reset --hard`, `git clean -fd`, xóa file, ghi đè dữ liệu hoặc rollback phá hủy nếu chưa được cho phép rõ ràng.

### 4. 🔒 Least Privilege:
- Không mặc định dùng `sudo()` hoặc bỏ qua ACL/record rules.
- Chỉ nâng quyền khi có lý do nghiệp vụ được chứng minh, giới hạn phạm vi và có kiểm thử bảo mật phù hợp.

### 5. ⚠️ Side-Effect & SSH Terminal Safety Gate:
- **KHÔNG** tự ý: đồng bộ code lên server, restart dịch vụ, reset/nạp lại database, nâng cấp module trên production, push/merge hoặc phát hành bản ứng dụng nếu chưa được ủy quyền rõ ràng.
- ⛔ **CẤM** tự ý thay đổi cấu hình hạ tầng (như hạ `workers = 0` trong `odoo.conf` để che giấu lỗi WebSocket). Mọi thay đổi cấu hình phải được Sếp Tân chỉ đạo.
- 🚨 **Rào chắn SSH Terminal Hook**: TUYỆT ĐỐI CẤM gõ script Python inline nhiều dòng (`python3 -c "..."`) dài quá 2000 ký tự qua `run_in_terminal` vì sẽ bị hook từ chối liên tiếp gây kẹt vòng lặp (stuck loop). Bắt buộc viết file script độc lập `/tmp/patch_xxx.py` hoặc sửa file cục bộ rồi rsync.
- Phải xác minh môi trường và phương án rollback trước thao tác có rủi ro.

### 6. 🤖 Agent Capability & Mandatory Dispatch Gate:
- 👑 **Luật Phân Công Độc Quyền cho `@lead`**: Khi nhận Master Contract, `@lead` BẮT BUỘC gọi tool `Agent` ủy quyền cho các Subagents chuyên trách (`dev-backend-odoo`, `dev-mobile-flutter`, `tester-functional`, `tester-security`, `audit-gate`).
- ⛔ **CẤM TUYỆT ĐỐI `@lead` tự ôm đồm** gõ lệnh terminal sửa code hay test trực tiếp trong cùng một phiên (chống phình to transcript > 800 tin nhắn làm tràn RAM context và kẹt lệnh).
- Giới hạn vòng sửa; khi subagent bị kẹt quá 2 vòng ➔ **Stop-The-Line và báo `@lead`** thay vì tiếp tục thử mù quáng.

### 7. 📊 Evidence Gate:
- Ghi chính xác lệnh đã chạy, kết quả thực tế, exit code và phạm vi test.
- Chưa chạy ghi `NOT RUN`; chưa đủ bằng chứng ghi `UNKNOWN`.
- **KHÔNG** suy diễn PASS, **KHÔNG** tuyên bố tuyệt đối từ kiểm thử có phạm vi giới hạn.

### 8. 🎨 UI & Release Gate:
- Task giao diện phải có Visual QA Checklist.
- Không tự chạy BrowserMCP/Playwright/CDP nếu chưa được cho phép theo quy tắc dự án.
- Mọi hoạt động `SHIP` / `DEPLOY` cần vượt qua preflight, kiểm tra rollback và xác nhận của Sếp Tân.

### 9. 📋 Final Report:
- Tóm tắt trong tối đa **1.200 ký tự**; nếu task phức tạp, bổ sung bằng chứng chi tiết trong `walkthrough.md` hoặc tài liệu bàn giao phù hợp.
- Nêu rõ: thay đổi, kiểm thử, vấn đề còn lại và việc chưa hoàn thành.
- **Không bao giờ báo PASS nếu chưa thực thi và xác minh.**

### 10. 📝 Mandatory SSOT Update Gate (Kỷ Luật Đọc & Cập Nhật File SSOT):
- **Trước khi làm**: BẮT BUỘC đọc file SSOT (`docs/features.md`, `docs/idea_portal.md`,...) để nắm rõ toàn cảnh: việc gì ĐÃ LÀM (có tag `[x]`), việc gì ĐANG LÀM, và việc gì CHƯA LÀM (tồn đọng).
- **Sau khi làm**: BẮT BUỘC cập nhật trực tiếp vào file SSOT:
  + Chuyển trạng thái `[ ]` sang `[x]` cho các mục đã xử lý và test pass.
  + Ghi rõ Evidence kiểm thử (tên file test, số test pass, log output).
  + Phân định rõ ràng: Danh mục ĐÃ LÀM XONG vs Danh mục CÒN TỒN ĐỌNG / CHƯA LÀM.
- ⛔ **CẤM BÁO CÁO HOÀN THÀNH NẾU CHƯA CẬP NHẬT FILE SSOT**. Không cập nhật file tài liệu = Vi phạm Zero-Trust Gate.

---

## 🕵️ X. QUY TRÌNH 3 BƯỚC TIẾP NHẬN BÁO CÁO & PHÂN RÃ VIỆC (FACT-CHECK ➔ ROOT-CAUSE ➔ MULTI-AGENT DISPATCH)

Khi Sếp Tân gửi báo cáo điều tra/nghiệm thu của một agent, hoặc yêu cầu tìm nguyên nhân lỗi của agent:
TUYỆT ĐỐI KHÔNG tin ngay báo cáo của agent, KHÔNG vội vàng nhận "đã pass" hay "đúng rồi". BẮT BUỘC thực thi tuần tự 3 bước sau để chống bịa đặt và chống một agent ôm đồm chạy quá lâu:

### 🛡️ BƯỚC 1: FACT-CHECK & ANTI-HALLUCINATION GATE (KIỂM CHỨNG BẰNG CHỨNG THẬT)
- **Claim ≠ Fact**: Mọi kết luận "PASS", "L4 — VERIFIED", "đã fix xong" trong báo cáo chỉ là `HYPOTHESIS` cho đến khi có bằng chứng thực tế độc lập.
- **Vạch trần 4 chiêu trò "báo cáo bịa / lấp liếm lỗi"**:
  1. *Fake Pass*: Báo cáo PASS trên giấy nhưng vào URL thực tế bị văng lỗi (màn hình đỏ, lỗi unhandled promise rejection).
  2. *Đổi config hạ chuẩn*: Tự ý sửa cấu hình hạ tầng (như hạ `workers = 0` trong `odoo.conf` để né lỗi gevent/WebSocket multi-worker).
  3. *Soi sai Database*: Query trên DB rác (như `odoo_dev_v19`) thay vì DB mục tiêu (`vcloud_test_v19`).
  4. *Test không trúng điểm đau*: Chạy test unit rỗng/mock không kích hoạt được luồng nghiệp vụ bị crash thực tế.
- **Thực thi đối soát độc lập**: Lead Agent hoặc subagent độc lập bắt buộc kiểm tra log container thực (`docker logs`), HTTP status code thật, kết quả query DB thật và `git diff` thật trước khi đưa ra nhận định.

### 🔬 BƯỚC 2: ROOT CAUSE ANALYSIS GATE (PHÂN TÍCH NGUYÊN NHÂN GỐC RỄ)
- **Không vá ngọn (No Symptom Patching)**: Xác định nguyên nhân gốc rễ sâu xa thay vì bọc `try/catch` che giấu lỗi.
  * Ví dụ: Discuss crash không phải chỉ do frontend thiếu catch, mà do WebSocket trả về 500 vì Odoo Registry thiếu model `ai.tool`.
- **Định vị chính xác toạ độ**: Tìm đúng `file_path:line`, tên hàm, class, luồng dữ liệu gây lỗi.
- **Đo lường Blast Radius**: Xác định lỗi ảnh hưởng những module, API hay màn hình nào để khoanh vùng xử lý.

### ⚡ BƯỚC 3: MULTI-AGENT WORK BREAKDOWN & PARALLEL DISPATCH (CHIA VIỆC CHỐNG CHẠY LÂU)
- ⛔ **CẤM 1 AGENT ÔM ĐỒM**: Tuyệt đối không để một agent duy nhất làm từ đầu đến cuối (dò lỗi ➔ sửa backend ➔ sửa mobile ➔ test UI ➔ deploy), gây phình to context (> 800 tin nhắn), cạn RAM context window và chạy kéo dài hàng giờ.
- 🚨 **Bắt buộc phân rã thành các gói việc độc lập (Work Packages)**:
  * 📦 **Gói Backend**: Ủy quyền cho `dev-backend-odoo` phẫu thuật code Python/XML, sửa model, sửa registry, tối ưu ORM theo Ponytail.
  * 📦 **Gói Mobile / Frontend**: Ủy quyền cho `dev-mobile-flutter` sửa Dart, Riverpod controller, Presentation widgets.
  * 📦 **Gói Kiểm thử UAT & Runtime**: Ủy quyền cho `tester-functional` chạy test script, kiểm tra WebSocket handshake, kiểm tra giao diện UAT.
  * 📦 **Gói Rà soát An toàn & Quyền hạn**: Ủy quyền cho `tester-security` / `@auditor` soi record rules, access rights, SQL injection.
- **Master Contract SSOT**: Lead Agent đóng gói toàn bộ yêu cầu, toạ độ `file_path:line` và rào chắn an toàn vào Master Execution Prompt chuẩn `prompt_claude.md` (4 Trụ Cột, 10 Gates, Bảng UAT PENDING) giao cho subagent chuyên trách thực thi.


