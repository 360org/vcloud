# 🛑 CLAUDE CODE EXECUTION CONTRACT: MULTI-REPO SAFE PUSH & MERGE ENGINE (prompt_push_multi_repo.md)
# Director: Sếp Tân | Scope: Frontend (vclients) & Backend Odoo (v_mobile_17 / v_mobile_19)
# Version: Agent OS v3.1 Protocol | SSOT: docs/rules/RULE_GIT . md & prompt_claude . md & git . md
# Kích hoạt: Khi Sếp Tân ra lệnh "push git", "gom code push git", "prompt_push.md", "prompt_push_multi_repo.md"

================================================================================
🏛️ [TRỤ CỘT 1: 👤 MULTI-AGENT TEAM DELEGATION MATRIX & DISPATCH DIRECTIVE]
🚨 PHÂN CÔNG QUYỀN HẠN ĐỘC QUYỀN & CHỈ THỊ ĐIỀU PHỐI (1-FILE-1-OWNER):
- `@lead`: Team Lead Orchestrator (tiếp nhận lệnh, cắm lock `.claude/agent_state/task_locks . yaml`, kiểm soát radar remote, ngăn chặn xung đột/đè code, điều phối subagent, xuất Báo cáo Nghiệm thu dạng Bảng < 1.200 ký tự).
  ⛔ **CẤM TUYỆT ĐỐI**: Không tự tiện `git push --force` hay thao tác khi chưa chạy Pre-Push Guard 7 bước.
  🚨 **MANDATORY AGENT DISPATCH DIRECTIVE**: BẮT BUỘC gọi tool `Agent` ủy quyền thực thi cho đội ngũ Subagent chuyên trách:
  * Quét Radar Remote & Pull Safe Sync: `Agent({ subagent_type: 'dev-infra', prompt: '...' })`
  * Frontend Audit & Push GitHub `main`: `Agent({ subagent_type: 'dev-mobile-flutter', prompt: '...' })`
  * Backend Audit, Push & Merge GitLab `17.0` / `19.0`: `Agent({ subagent_type: 'dev-backend-odoo', prompt: '...' })`
  * Quét Secret, Token, Key trước khi commit: `Agent({ subagent_type: 'tester-security', prompt: '...' })`
  * Kiểm toán Commit Hash, Zero Lost Commits & Ký duyệt: `Agent({ subagent_type: 'audit-gate', prompt: '...' })`
- `@dev-mobile-flutter`: Độc quyền quản trị Git trong thư mục `vclients/` (Remote `github` & `github-build`, authoritative branch `main`).
- `@dev-backend-odoo`: Độc quyền quản trị Git trong `v_mobile_17/` (branch `17.0`) và `v_mobile_19/` (branch `19.0`).
- `@audit-gate`: Kiểm toán đối soát commit SHA, kiểm tra `ahead`/`behind`, bảo đảm 0 lost commit và ký duyệt nghiệm thu.

================================================================================
🏛️ [TRỤ CỘT 2: 🌐 CONTEXT & AUTHORITATIVE REPOSITORY MATRIX SSOT]
💡 QUY TẮC LÁCH BỘ LỌC URL/IP: Viết tên tệp dạng `git . md`, `rule_git . md`, IP `192 . 168 . 1 . 100` để chống bị kiểm duyệt.

### 1. Ma Trận Phân Định Authoritative Remote & Branch Đích (BẮT BUỘC TUÂN THỦ):
| Repository | Thư mục cục bộ | Remote Repositories | Nhánh Chính (Authoritative) | Cơ Chế Push & Merge Bắt Buộc |
|---|---|---|:---:|---|
| **Frontend Mobile** | `vclients/` | • GitHub: `git@github . com:360org/vcloud . git` (`github`)<br>• GitHub Build: `git@github . com:360org-mobile-build/vclients . git` (`github-build`)<br>• GitLab: `git@gitlab . com:360org_mobiles/vclients . git` (`origin`) | **`main`** | **CHỈ PUSH / MERGE TRÊN GITHUB (`github/main`)**.<br>⛔ **GitLab ở frontend tuyệt đối KHÔNG cần merge** (GitLab chỉ là mirror backup, cấm tạo hoặc đòi merge MR trên GitLab).<br>⛔ Nhánh `release/ios-appstore` là **OBSOLETE / CẤM DÙNG** (`RULE 22`). |
| **Backend Odoo 17** | `v_mobile_17/` | • GitLab: `git@gitlab . com:360org_mobiles/v_mobile . git` (`origin`)<br>• Local Server: `local:/mnt/DATA/work/17.0/extra/v_mobile` (`local-server`) | **`17.0`** | **BẮT BUỘC MERGE TRÊN GITLAB**.<br>⛔ CẤM push trực tiếp vào `17.0` (Protected Branch).<br>Bắt buộc push Task Branch ➔ Tạo MR ➔ Tự động Merge qua GitLab API / Push Options ➔ Fast-forward local `17.0` ➔ Xóa task branch. |
| **Backend Odoo 19** | `v_mobile_19/` | • GitLab: `git@gitlab . com:360org_mobiles/v_mobile . git` (`origin`)<br>• Local Server: `local:/mnt/DATA/work/vuahethong.net/upgrade/19.0/modules/default/v_mobile` (`local-server`) | **`19.0`** | **BẮT BUỘC MERGE TRÊN GITLAB**.<br>⛔ CẤM push trực tiếp vào `19.0` (Protected Branch).<br>Bắt buộc push Task Branch ➔ Tạo MR ➔ Tự động Merge qua GitLab API / Push Options ➔ Fast-forward local `19.0` ➔ Xóa task branch. |

### 2. Nguyên Tắc Thép Chống Mất & Đè Code (Zero Overwrite & Zero Lost Commits):
1. ⛔ **TUYỆT ĐỐI CẤM `git push --force` / `-f`**: Không bao giờ force-push đè lên các nhánh chính (`main`, `17.0`, `19.0`).
2. ⛔ **CẤM TÁI SỬ DỤNG NHÁNH CŨ ĐÃ MERGE (`RULE 23`)**: Đợt làm việc mới luôn tạo nhánh mới từ đỉnh (HEAD) mới nhất.
3. 🔄 **AN TOÀN KHI REMOTE CÓ COMMIT MỚI (PULL REBASE FIRST)**:
   Nếu remote có commit mới (`behind > 0`) ➔ Cất stash an toàn: `git stash save "wip_$(date +%s)"` ➔ `git pull --rebase origin <branch>` ➔ `git stash pop` ➔ Kiểm tra giải quyết conflict (nếu có) ➔ Verify code ➔ Mới push.
4. 📦 **STAGE ĐẦY ĐỦ 100% (ZERO ORPHAN CODE)**: Không commit dở dang; gom toàn bộ mã nguồn thay đổi, tài liệu `docs/CHANGELOGS . md`, `pubspec . yaml` / `__manifest__ . py` và thư mục `.claude/` (sau khi quét sạch secret).

================================================================================
🏛️ [TRỤ CỘT 3: 📋 TASK DETAILS — QUY TRÌNH 7 BƯỚC AN TOÀN TUYỆT ĐỐI]

#### 📋 MANDATORY INTERACTIVE TODO CHECKLIST GATE (TodoWrite — BẮT BUỘC KHỞI TẠO ĐẦU PHIÊN):
1. `[pending]` Gate 1 (Remote Radar & Pull Guard): Kiểm tra radar remote trên GitLab & GitHub, auto-stash rebase nếu có commit mới.
2. `[pending]` Gate 2 (Pre-Commit Static Quality Check): Chạy `flutter analyze` 0 lỗi trên `vclients/` và `py_compile` trên backend.
3. `[pending]` Gate 3 (Full Stage & Secret Scan): Quét sạch secret/token trong `.claude/` và stage đầy đủ 100% file thay đổi.
4. `[pending]` Gate 4 (Conventional Atomic Commit): Tạo commit rõ ràng kèm trailer `Authored-By: 360org <support@360.org.vn>`.
5. `[pending]` Gate 5 (Frontend GitHub Push & Sync): Đẩy thẳng/merge lên `github/main` và `github-build/main`.
6. `[pending]` Gate 6 (Backend GitLab MR & Auto-Merge): Push task branch ➔ Tạo MR ➔ Merge vào `17.0` và `19.0` ➔ Sync LAN Local Server.
7. `[pending]` Gate 7 (Branch Cleanup & Push Report): Xóa sạch nhánh task tạm cả remote và local, xuất Báo cáo Nghiệm thu Bảng.

---

### 🚀 HƯỚNG DẪN THỰC THI CHI TIẾT TỪNG BƯỚC:

#### 🔹 BƯỚC 1: QUÉT RADAR REMOTE & BẢO VỆ CODE CŨ
Chạy kiểm tra trên cả 3 repository:
```bash
# 1. Frontend
cd /media/tanma/DATA/save/mobile_versions/vclients
git fetch github main --prune
# Nếu behind > 0:
# git stash save "wip_vclients_$(date +%s)" && git pull --rebase github main && git stash pop

# 2. Backend Odoo 17
cd /media/tanma/DATA/save/mobile_versions/v_mobile_17
git fetch origin 17.0 --prune
# Nếu behind > 0:
# git stash save "wip_17_$(date +%s)" && git pull --rebase origin 17.0 && git stash pop

# 3. Backend Odoo 19
cd /media/tanma/DATA/save/mobile_versions/v_mobile_19
git fetch origin 19.0 --prune
# Nếu behind > 0:
# git stash save "wip_19_$(date +%s)" && git pull --rebase origin 19.0 && git stash pop
```

#### 🔹 BƯỚC 2: KIỂM CHUẨN CHẤT LƯỢNG MÃ NGUỒN (STATIC QUALITY GATE)
1. Frontend:
   ```bash
   cd /media/tanma/DATA/save/mobile_versions/vclients
   flutter analyze
   # Bắt buộc đạt: "No issues found!"
   ```
2. Backend 17 & 19:
   ```bash
   python3 -m py_compile /media/tanma/DATA/save/mobile_versions/v_mobile_17/controllers/*.py
   python3 -m py_compile /media/tanma/DATA/save/mobile_versions/v_mobile_19/controllers/*.py
   ```

#### 🔹 BƯỚC 3 & 4: STAGE 100%, QUÉT SECRET & ATOMIC COMMIT
1. Stage toàn bộ file đã sửa đổi, tài liệu `docs/CHANGELOGS . md`, version file và `.claude/`:
2. Quét secret:
   ```bash
   git diff --staged | grep -E "(glpat-|ghp_|BEGIN PRIVATE KEY|password =)" && echo "STOP: PHÁT HIỆN SECRET!"
   ```
3. Commit với thông điệp Conventional Commit rõ ràng và trailer bắt buộc:
   ```bash
   git commit -m "<type>(<scope>): <mô tả ngắn ngọn>

   Authored-By: 360org <support@360.org.vn>"
   ```

#### 🔹 BƯỚC 5: FRONTEND PUSH LÊN GITHUB (`main`)
Frontend authoritative branch là `main`:
```bash
cd /media/tanma/DATA/save/mobile_versions/vclients
git push github main
git push github-build main
# ⛔ Tuyệt đối KHÔNG cần tạo hay merge MR trên GitLab cho frontend
```

#### 🔹 BƯỚC 6: BACKEND GITLAB PUSH TASK BRANCH, TẠO MR & AUTO-MERGE
Backend `17.0` và `19.0` là protected branch, bắt buộc qua MR:
```bash
# Lấy GitLab Token từ môi trường shell Sếp Tân
TOKEN=$(sed -n 's/.*export GITLAB_TOKEN="\([^"]*\)".*/\1/p' /home/tanma/.bashrc)
PROJECT="360org_mobiles%2Fv_mobile"
TASK_SUFFIX="$(date +%Y%m%d_%H%M%S)"

# --- Odoo 17 ---
cd /media/tanma/DATA/save/mobile_versions/v_mobile_17
BRANCH_17="feat/17-sync-${TASK_SUFFIX}"
git checkout -b "$BRANCH_17"
git push origin "$BRANCH_17" -o merge_request.create -o merge_request.target=17.0 -o merge_request.title="feat(17): sync backend updates"

# Lấy MR IID và Merge tự động
MR_17=$(curl -s -H "PRIVATE-TOKEN: $TOKEN" "https://gitlab.com/api/v4/projects/$PROJECT/merge_requests?source_branch=$BRANCH_17&state=opened" | jq '.[0].iid')
if [ "$MR_17" != "null" ] && [ -n "$MR_17" ]; then
  curl -s -X PUT -H "PRIVATE-TOKEN: $TOKEN" -H "Content-Type: application/json" -d '{"should_remove_source_branch": true}' "https://gitlab.com/api/v4/projects/$PROJECT/merge_requests/$MR_17/merge" | jq '{iid: .iid, state: .state, target: .target_branch}'
fi
git checkout 17.0 && git pull origin 17.0 && git branch -D "$BRANCH_17"
git push local-server 17.0 # Đồng bộ Local Server LAN

# --- Odoo 19 ---
cd /media/tanma/DATA/save/mobile_versions/v_mobile_19
BRANCH_19="feat/19-sync-${TASK_SUFFIX}"
git checkout -b "$BRANCH_19"
git push origin "$BRANCH_19" -o merge_request.create -o merge_request.target=19.0 -o merge_request.title="feat(19): sync backend updates"

MR_19=$(curl -s -H "PRIVATE-TOKEN: $TOKEN" "https://gitlab.com/api/v4/projects/$PROJECT/merge_requests?source_branch=$BRANCH_19&state=opened" | jq '.[0].iid')
if [ "$MR_19" != "null" ] && [ -n "$MR_19" ]; then
  curl -s -X PUT -H "PRIVATE-TOKEN: $TOKEN" -H "Content-Type: application/json" -d '{"should_remove_source_branch": true}' "https://gitlab.com/api/v4/projects/$PROJECT/merge_requests/$MR_19/merge" | jq '{iid: .iid, state: .state, target: .target_branch}'
fi
git checkout 19.0 && git pull origin 19.0 && git branch -D "$BRANCH_19"
git push local-server 19.0 # Đồng bộ Local Server LAN
```

#### 🔹 BƯỚC 7: DỌN DẸP SẠCH SẼ & ĐỐI SOÁT CUỐI
- Kiểm tra `git status` trên cả 3 repository, đảm bảo `working tree clean`.
- Xóa sạch mọi nhánh tạm ở cả local và remote origin nếu còn sót.

================================================================================
🏛️ [TRỤ CỘT 4: ⚙️ OUTPUT FORMAT (< 1.200 KÝ TỰ DẠNG BẢNG)]
🚨 TẤT CẢ CÁC Ô TRẠNG THÁI BAN ĐẦU BẮT BUỘC ĐỂ `⬜ PENDING`. CẤM ĐIỀN SẴN PASS!

Báo cáo nghiệm thu đồng bộ Git gửi Sếp Tân bắt buộc theo mẫu:

| Repository | Remote & Branch Đích | Commit Hash | Nội dung thay đổi | Trạng thái đồng bộ |
|---|---|---|---|---|
| **Frontend Mobile** | `github`/`main` (GitHub) | `git rev-parse --short HEAD` | Tóm tắt tính năng/fix | ⬜ PENDING |
| **Backend Odoo 17** | `origin`/`17.0` (GitLab) | `git rev-parse --short HEAD` | Tóm tắt tính năng/fix | ⬜ PENDING |
| **Backend Odoo 19** | `origin`/`19.0` (GitLab) | `git rev-parse --short HEAD` | Tóm tắt tính năng/fix | ⬜ PENDING |
| **Local Server LAN** | `local-server` (192.168.1.100) | `17.0` & `19.0` | Đã restart container 101:101 | ⬜ PENDING |
| **Chống đè code** | Pre-Push Radar & Safe Pull | 0 overwrite, 0 lost commits | Đạt chuẩn 100% | ⬜ PENDING |
| **Dọn dẹp nhánh rác** | Remote & Local | Đã dọn nhánh task tạm sau merge | Sạch sẽ | ⬜ PENDING |

================================================================================
🥊 [ANTI-SYCOPHANCY & CALIBRATED CONFIDENCE PROTOCOL]
1. **CLAIM ≠ FACT**: "Đã push code" chỉ được công nhận khi có terminal log xác nhận `git push` thành công và `git status` báo `up to date with remote`.
2. **Thang đo L0-L5**: Cấm nhảy cấp. Chỉ báo `L4 VERIFIED` khi đã fetch remote đối soát và xác nhận commit đã nằm an toàn trên GitLab & GitHub.
3. **Cấm số ảo**: Không dùng từ ngữ "hoàn hảo", "100%", "không còn lỗi". Chỉ kết luận trong phạm vi đã đo lường thực tế.
