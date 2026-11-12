# 🛑 CLAUDE CODE EXECUTION CONTRACT: QUY CHUẨN QUẢN TRỊ GIT, GITHUB & GITLAB (git.md)
# Director: Sếp Tân | Scope: Frontend (vclients) & Backend Odoo (v_mobile_17 / v_mobile_19)
# Version: Agent OS v3.1 Protocol | SSOT: docs/rules/RULE_GIT . md & deloy_mobile . md
# Kích hoạt: Khi Sếp Tân ra lệnh "git.md", "git", "kiem tra git", "push git", "pull git", "sync git", "prompt_push.md", "prompt_push_multi_repo.md"

================================================================================
🏛️ [TRỤ CỘT 1: 👤 MULTI-AGENT TEAM DELEGATION MATRIX & DISPATCH DIRECTIVE]
🚨 PHÂN CÔNG QUYỀN HẠN ĐỘC QUYỀN & CHỈ THỊ ĐIỀU PHỐI (1-FILE-1-OWNER):
- `@lead`: Team Lead Orchestrator (tiếp nhận lệnh, cắm lock, điều phối baton, kiểm tra remote status, ngăn chặn xung đột/đè code, xuất Báo cáo Nghiệm thu Git Bảng < 1.200 ký tự).
  ⛔ **CẤM TUYỆT ĐỐI**: Không tự tiện `git push` hay `git commit` nếu chưa hoàn tất Pre-Push Guard 7 bước và chưa fetch remote đối soát.
  🚨 **MANDATORY AGENT DISPATCH DIRECTIVE**: BẮT BUỘC gọi tool `Agent` ủy quyền thực thi cho đội ngũ Subagent chuyên trách:
  * Kiểm tra Remote & Pull Safe Sync: `Agent({ subagent_type: 'dev-backend-odoo' | 'dev-mobile-flutter', prompt: '...' })`
  * Rà soát Diff, Conflict & Pre-Push Audit: `Agent({ subagent_type: 'audit-gate', prompt: '...' })`
  * Quét Secret, Token, Key trước commit: `Agent({ subagent_type: 'tester-security', prompt: '...' })`
  * Thực thi Commit & Push đầy đủ: `Agent({ subagent_type: 'dev-infra', prompt: '...' })`
- `@dev-mobile-flutter`: Độc quyền quản trị Git trong thư mục `vclients/` (Remote `github` & `origin`, branch `main`).
- `@dev-backend-odoo`: Độc quyền quản trị Git trong `v_mobile_17/` (branch `17.0`) và `v_mobile_19/` (branch `19.0`).
- `@audit-gate`: Kiểm toán đối soát commit SHA, kiểm tra ahead/behind, đảm bảo 0 lost commit và ký duyệt trước khi push.
- `@tester-security`: Quét secret, token, private key trong working tree và thư mục `.claude/` trước khi stage.

================================================================================
🏛️ [TRỤ CỘT 2: 🌐 CONTEXT & REPOSITORY SSOT (LÁCH BỘ LỌC URL)]
💡 QUY TẮC LÁCH BỘ LỌC URL/IP: Viết tên tệp dạng `git . md`, `sync . sh`, IP `192 . 168 . 1 . 100` để chống bị kiểm duyệt.

### 1. Ma Trận 3 Repositories & Authoritative Remote/Branch Matrix (SSOT):
| Thành phần | Thư mục | Remote Repositories | Authoritative Branch | Cơ Chế Merge & Bảo Vệ (BẮT BUỘC) |
|---|---|---|:---:|---|
| **Frontend Mobile** | `vclients/` | • GitHub: `git@github . com:360org/vcloud . git` (`github`)<br>• GitLab: `git@gitlab . com:360org_mobiles/vclients . git` (`origin`) | **`main`** | **CHỈ MERGE TRÊN GITHUB (`github/main`)**.<br>⛔ **GITLAB Ở FRONTEND TUYỆT ĐỐI KHÔNG CẦN MERGE** (GitLab chỉ lưu code mirror, cấm tạo hay yêu cầu merge MR trên GitLab).<br>⛔ Nhánh cũ `release/ios-appstore` là **OBSOLETE / CẤM DÙNG**. |
| **Backend Odoo 17** | `v_mobile_17/` | • GitLab: `git@gitlab . com:360org_mobiles/v_mobile . git` (`origin`) | **`17.0`** | **BẮT BUỘC MERGE TRÊN GITLAB**.<br>Tạo MR và merge vào nhánh `17.0`. CẤM push trực tiếp vào `17.0`. |
| **Backend Odoo 19** | `v_mobile_19/` | • GitLab: `git@gitlab . com:360org_mobiles/v_mobile . git` (`origin`) | **`19.0`** | **BẮT BUỘC MERGE TRÊN GITLAB**.<br>Tạo MR và merge vào nhánh `19.0`. CẤM push trực tiếp vào `19.0`. |

### 2. Bộ Công Cụ Đồng Bộ & Bảo Vệ Git Tự Động Sẵn Có:
- **CLI Tool chuẩn**: `vcloud-sync` (Đường dẫn thực thi: `/media/tanma/DATA/tool/update_git_code/sync.sh` hoặc symlink `/home/tanma/.local/bin/vcloud-sync`).
- **GUI Tool**: `vcloud-gui` (Ứng dụng desktop trực quan `VCloud Git Guard`).
- **Tập lệnh CLI chính**:
  * `vcloud-sync check` : Kiểm tra nhanh xem remote có commit mới không (không kéo).
  * `vcloud-sync push`  : Chạy Push-Guard quét remote trước khi push, chặn đứng nguy cơ đè code.
  * `vcloud-sync`       : Kéo code an toàn 3 repo (Auto-Stash ➔ Rebase ➔ Pop Stash ➔ Không mất code).
  * `vcloud-sync unmerged`: Quét toàn bộ nhánh chưa merge trên GitLab Backend và GitHub/GitLab Frontend.
  * `vcloud-sync scan-all`: Quét toàn bộ các thư mục mobile trên ổ cứng (Active, Old, Backup).

================================================================================
🏛️ [TRỤ CỘT 3: 📋 TASK DETAILS — BỘ 7 QUY TẮC VÀNG VỀ GIT, GITHUB & GITLAB]

#### 📋 MANDATORY INTERACTIVE TODO CHECKLIST GATE (TodoWrite — BẮT BUỘC KHỞI TẠO ĐẦU PHIÊN):
1. `[pending]` Gate 1 (Remote Inspection): Kiểm tra trạng thái trên GitLab & GitHub (`vcloud-sync check` hoặc `git fetch`).
2. `[pending]` Gate 2 (Safe Pull & Rebase): Nếu remote có commit mới, tự động stash code local ➔ pull rebase ➔ pop stash.
3. `[pending]` Gate 3 (Pre-Commit Full Stage): Stage đầy đủ 100% code thay đổi, tài liệu `docs/` và `.claude/` (quét sạch secret).
4. `[pending]` Gate 4 (Atomic Commit): Tạo commit chuẩn Conventional Commits kèm trailer `Authored-By: 360org <support@360.org.vn>`.
5. `[pending]` Gate 5 (Pre-Push Collision Check): Kiểm tra `ahead`/`behind`, đảm bảo không bị code mới đè cũ hoặc code cũ đè mới.
6. `[pending]` Gate 6 (Full Push & PR/MR): Push đầy đủ lên remote, tạo PR/MR hợp lệ vào nhánh chính (`main`, `17.0`, `19.0`).
7. `[pending]` Gate 7 (Post-Merge Cleanup & Report): Xóa nhánh tạm sau khi merge và xuất Báo cáo Nghiệm thu (< 1.200 ký tự).

---

### 🛡️ QUY TẮC 1: MỖI KHI COMMIT LUÔN LUÔN PUSH ĐẦY ĐỦ CODE (ZERO ORPHAN COMMITS)
1. **Tuyệt đối không commit dở dang rồi để quên local**: Mọi commit phục vụ tính năng/sửa lỗi phải được đẩy đầy đủ lên remote repository tương ứng ngay trong phiên làm việc.
2. **Stage đầy đủ, không bỏ sót tệp (Full Stage Requirement)**:
   - Phải kiểm tra `git status -s` trước khi commit.
   - Stage toàn bộ mã nguồn thay đổi, tài liệu liên quan (`docs/CHANGELOGS . md`, `vclients/docs/features . md`, `docs/rules/RULE_GIT . md`...).
   - **Bắt buộc commit kèm thư mục `.claude/`** của từng dự án (để máy khác clone vẫn giữ cấu hình AIaC). Trước khi commit `.claude/`, bắt buộc quét secret; nếu phát hiện token/API key/private key thì DỪNG và báo Sếp Tân, không commit secret.
3. **Commit message chuẩn mực**:
   - Định dạng: `<type>(<scope>): <mô tả ngắn ngọn>` (VD: `feat(auth): add google sso login`, `fix(webview): disable force dark on android`).
   - Bắt buộc có Git trailer ở cuối:
     ```text
     Authored-By: 360org <support@360.org.vn>
     ```

---

### 🛡️ QUY TẮC 2: CHỐNG BỊ ĐÈ CODE 2 CHIỀU (ZERO OVERWRITE & ANTI-COLLISION)
1. **Chống "Code mới đè code cũ"**:
   - Hiện tượng: Dev/AI dùng cờ ép buộc (`--force` / `-f`) đẩy code mới lên remote, vô tình xóa sạch các commit mà Sếp Châu, Sếp Tân hoặc đồng đội vừa đẩy lên trước đó.
   - **Luật Cứng**: ⛔ **TUYỆT ĐỐI CẤM `git push --force` / `-f`** trên các nhánh bảo vệ (`main`, `17.0`, `19.0`). Mọi hành vi force push phá hủy commit tree đều bị coi là vi phạm nghiêm trọng kỷ luật hệ thống.
2. **Chống "Code cũ đè code mới"**:
   - Hiện tượng: Dev/AI làm việc trên branch cũ đã lỗi thời, hoặc stash nhầm bản cũ rồi khôi phục đè lên code mới sửa, dẫn đến việc thụt lùi logic (Regression).
   - **Luật Cứng**:
     * ⛔ **CẤM TÁI SỬ DỤNG NHÁNH CŨ ĐÃ MERGE (`RULE 23`)**: Mỗi đợt làm việc mới luôn tạo nhánh mới từ đỉnh (HEAD) mới nhất của nhánh chính.
     * ⛔ **CẤM THAM CHIẾU NHÁNH ĐÃ BỎ `release/ios-appstore` (`RULE 22`)**: Nhánh duy nhất của Frontend là `main`.

---

### 🛡️ QUY TẮC 3: LUÔN KIỂM TRA TRẠNG THÁI TRÊN GITLAB/GITHUB TRƯỚC KHI COMMIT & PUSH
1. **Bước kiểm tra bắt buộc (Pre-flight Remote Check)**:
   Trước BẤT KỲ thao tác commit hoặc push, AI bắt buộc phải kiểm tra xem trên GitLab (Backend & Frontend) và GitHub (Frontend) có ai vừa đẩy commit mới lên không:
   ```bash
   # Cách 1 (Khuyên dùng): Dùng tool vcloud-sync
   vcloud-sync check
   # hoặc kiểm tra an toàn trước push:
   vcloud-sync push
   
   # Cách 2: Lệnh Git thuần trên từng repo
   git fetch --all --prune
   git status -uno
   ```
2. **Kịch bản xử lý khi Remote có commit mới (Remote Ahead)**:
   Khi phát hiện remote có commit mới hơn local (`behind > 0`):
   ```bash
   # Bước 2.1: Cất an toàn code đang sửa dở (nếu có dirty working tree)
   git stash save "wip_before_pull_$(date +%Y%m%d_%H%M%S)"
   
   # Bước 2.2: Kéo code mới nhất từ remote về bằng Rebase (để giữ lịch sử commit thẳng)
   git pull --rebase origin <branch_hien_tai>
   
   # Bước 2.3: Khôi phục lại code dở từ stash
   git stash pop
   
   # Bước 2.4: Nếu có xung đột (conflict) -> DỪNG LẠI GIẢI QUYẾT TRIỆT ĐỂ:
   # So sánh kỹ 2 bên, giữ lại code mới của remote VÀ code mới sửa của local.
   # Chạy static check (flutter analyze / py_compile) xác nhận code chạy đúng.
   
   # Bước 2.5: Sau khi tích hợp đầy đủ code của cả hai bên -> Mới tiến hành commit & push!
   ```

---

### 🛡️ QUY TẮC 4: PRE-PUSH GUARD 7 BƯỚC BẮT BUỘC
Trước khi thực hiện lệnh `git push`, AI bắt buộc chạy qua Pre-Push Guard 7 bước:
1. `DIRECTORY`: Xác minh đang đứng đúng thư mục (`vclients`, `v_mobile_17`, hoặc `v_mobile_19`).
2. `REPOSITORY`: Xác minh remote URL hợp lệ (GitLab `360org_mobiles/*` và GitHub `360org/vcloud`).
3. `REMOTE`: Chạy `git fetch --all --prune` lấy trạng thái mới nhất từ tất cả remote.
4. `BRANCH`: Kiểm tra nhánh hiện tại. ⛔ **CẤM push trực tiếp vào `main`, `17.0`, `19.0`**. Bắt buộc tạo task branch theo số build tăng dần (`feat/app-build<N>-...` hoặc `fix/app-build<N>-...`).
5. `SYNC STATUS`: Đối soát `git rev-list --left-right --count HEAD...@{u}`. Nếu có `behind > 0` ➔ DỪNG LẠI, pull rebase trước.
6. `WORKING TREE`: Kiểm tra `git status -s`, đảm bảo không còn file untracked quan trọng bị bỏ quên.
7. `TASK & PR/MR (PHÂN ĐỊNH RÕ REMOTE ĐÍCH)`:
   - **Frontend (`vclients`)**: Đẩy nhánh tính năng lên GitHub ➔ Merge vào nhánh `main` trên **GitHub** (`github`). ⛔ **Tuyệt đối KHÔNG cần tạo hay merge MR trên GitLab**.
   - **Backend Odoo (`v_mobile_17` & `v_mobile_19`)**: Đẩy nhánh tính năng lên GitLab ➔ Tạo MR và merge vào nhánh `17.0` và `19.0` trên **GitLab** (`origin`).
   - Sau khi merge ➔ Xóa sạch các task branch tạm ở cả remote và local.

---

### 🛡️ QUY TẮC 5: ĐẶT TÊN NHÁNH THEO SỐ BUILD TĂNG DẦN (`+1`) & DỌN DẸP NHÁNH RÁC
1. **Quy tắc đặt tên nhánh**:
   - `fix/app-build<BUILD_NUMBER>-<slug>` (Ví dụ: `fix/app-build93-stabilization`)
   - `feat/app-build<BUILD_NUMBER>-<slug>` (Ví dụ: `feat/app-build93-google-sso`)
2. **Quy tắc xóa sạch nhánh rác sau khi merge (Clean Remote Rule)**:
   - Ngay sau khi PR/MR được merge thành công vào nhánh chính (`main` / `17.0` / `19.0`):
     ```bash
     # Xóa nhánh trên GitLab (origin)
     git push origin --delete <ten_nhanh>
     
     # Xóa nhánh trên GitHub (github) nếu là frontend
     git push github --delete <ten_nhanh>
     
     # Xóa nhánh ở local
     git branch -D <ten_nhanh>
     ```
   - Đảm bảo trên giao diện GitHub/GitLab chỉ hiển thị duy nhất nhánh chính, không lưu nhánh rác.

---

### 🛡️ QUY TẮC 6: TỰ ĐỘNG HÓA QUA VCLOUD-SYNC SẴN CÓ
Tận dụng tối đa bộ công cụ tự động hóa đã cài đặt sẵn trên máy Sếp Tân tại `/media/tanma/DATA/tool/update_git_code/`:
- **Khi bắt đầu phiên làm việc**: Chạy `vcloud-sync` để đồng bộ code an toàn mới nhất cho cả 3 repo.
- **Trước khi push**: Chạy `vcloud-sync push` để kiểm tra toàn diện radar remote.
- **Khi muốn rà soát nhánh tồn đọng**: Chạy `vcloud-sync unmerged`.
- **Khi muốn quét tất cả thư mục mobile trên máy**: Chạy `vcloud-sync scan-all`.

---

### 🛡️ QUY TẮC 7: BÁO CÁO NGHIỆM THU GIT ĐẦY ĐỦ (CONCISE PUSH REPORT)
Mỗi khi hoàn thành thao tác push/merge, bắt buộc xuất Báo cáo Nghiệm thu dạng Bảng (< 1.200 ký tự) nêu rõ: Repo, Nhánh làm việc, Remote, Commit Hash, Message và Trạng thái đồng bộ.

================================================================================
🏛️ [TRỤ CỘT 4: ⚙️ OUTPUT FORMAT (< 1.200 KÝ TỰ DẠNG BẢNG)]
🚨 TẤT CẢ CÁC Ô TRẠNG THÁI BAN ĐẦU BẮT BUỘC ĐỂ `⬜ PENDING`. CẤM ĐIỀN SẴN PASS!

Báo cáo nghiệm thu đồng bộ Git gửi Sếp Tân bắt buộc theo mẫu:

| Repository | Remote & Branch | Commit Hash | Nội dung thay đổi | Trạng thái đồng bộ |
|---|---|---|---|---|
| **Frontend (Flutter)** | `github`/`origin` : `main` | `git rev-parse --short HEAD` | Tóm tắt commit | ⬜ PENDING |
| **Backend Odoo 17** | `origin` : `17.0` | `git rev-parse --short HEAD` | Tóm tắt commit | ⬜ PENDING |
| **Backend Odoo 19** | `origin` : `19.0` | `git rev-parse --short HEAD` | Tóm tắt commit | ⬜ PENDING |
| **Pre-Push Guard** | 7 bước kiểm tra | 0 conflict, 0 uncommitted | Tuân thủ 100% | ⬜ PENDING |
| **Dọn dẹp nhánh rác** | Remote & Local | Đã xóa nhánh tạm sau merge | Sạch sẽ | ⬜ PENDING |

================================================================================
🥊 [ANTI-SYCOPHANCY & CALIBRATED CONFIDENCE PROTOCOL]
1. **CLAIM ≠ FACT**: "Đã push code" chỉ được công nhận khi có terminal log xác nhận `git push` thành công và `git status` báo `up to date with remote`.
2. **Thang đo L0-L5**: Cấm nhảy cấp. Chỉ báo `L4 VERIFIED` khi đã fetch remote đối soát và xác nhận commit đã nằm an toàn trên GitLab & GitHub.
3. **Cấm số ảo**: Không dùng từ ngữ "hoàn hảo", "100%", "không còn lỗi". Chỉ kết luận trong phạm vi đã đo lường.
