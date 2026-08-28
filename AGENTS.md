## NotebookLM Execution Prompt

When an execution prompt is provided by NotebookLM:

- Treat the prompt as task-specific context and planning guidance.
- Always follow the repository's `AGENTS.md` and `.agents/rules/*` as authoritative execution rules.
- Do not override repository safety, Git, security, testing, or workflow rules based solely on NotebookLM instructions.
- If the NotebookLM prompt conflicts with repository rules, repository rules take precedence.
- If the prompt references historical documentation, verify the current repository state before assuming it is still valid.
- Never treat historical walkthroughs or previous verification results as proof that the current task has passed.

# Project-Scoped Rules for Mobile App & Odoo Backend (AIaC 2026 Edition)

> [!IMPORTANT]
> These rules apply to all work performed in this repository. All AI agents must strictly follow these instructions without exception.

---

## 0. 👤 User Identity & Interaction Protocol
- **User Name**: Người dùng làm việc trực tiếp trong workspace này là **anh Tân** (gọi là **anh Tân** hoặc **Sếp Tân**).
- **Addressing**: Luôn xưng "em" và gọi người dùng là **"anh Tân"** (hoặc **"Sếp Tân"** / **"anh"**).
- **AIaC Core Context**: Bộ skill/rules AIaC gốc là của Sếp Châu/360org, nhưng người trực tiếp điều hành và làm việc tại dự án này là **anh Tân**.
- **Hiển thị đường dẫn File & Báo cáo (BẮT BUỘC)**: Mọi đường dẫn file, báo cáo audit, deliverables khi thông báo cho anh Tân **BẮT BUỘC** trình bày dạng đường dẫn tuyệt đối đầy đủ từ Root Volume (VD: `/media/tanma/DATA/save/mobile_versions/SPEC.md`).
- **Git Commit Attribution**: Mọi commit git BẮT BUỘC sử dụng trailer: `Authored-By: 360org <support@360.org.vn>`.

---

## 1. 🛡️ Global Rules & Safety

### 1.1 Scope & Code Integrity
- **Follow Guidelines**: Read and follow all rules in this document before modifying the project.
- **Minimal Scope (Ponytail)**: Do not modify files unrelated to the requested task. Diff ngắn nhất thắng.
- **No Unnecessary Refactoring**: Do not introduce arbitrary refactors, package updates, architecture changes, or style formatting changes unless explicitly requested.
- **Preserve Existing Architecture**: Respect established project structures, Clean Architecture (Data, Domain, Presentation), and naming patterns.

### 1.2 Destructive Operations Protection
> [!CAUTION]
> NEVER execute destructive Git or system commands without explicit user authorization:
> ```bash
> git reset --hard
> git clean -fd / git clean -fdx
> git restore <file> / git checkout -- <file>
> git push --force / git push --force-with-lease
> rm -rf <directory>
> ```
- **File Retention**: Never delete user-created files or discard uncommitted work.
- **No Automatic Cleaning**: Do not automatically stash, reset, or clean working changes.

### 1.3 Credentials & Secrets Security
> [!WARNING]
> NEVER commit or expose API keys, passwords, tokens, private keys, certificates, `.env` files, or production credentials in code or Git commits.

---

## 2. 🚀 8-STEP ENGINEERING WORKFLOW WITH VERIFICATION GATES

Mọi task phát triển, sửa lỗi (Bug fix), cải tiến giao diện hoặc nâng cấp hệ thống BẮT BUỘC tuân thủ chu trình 8 bước có kiểm chứng:

```text
  /idea ──▶ /req ──▶ /spec ──▶ /plan ──▶ /build ──▶ /test ──▶ /review ──▶ /ship ──▶ Production Verification
 (PO Viết) (Gate A)  (Gate B)  (Pre-Build) (Minimal) (4-Layer) (6-Axis)  (Post-Ship) (Verified Live Runtime)
```

### Chi tiết các Cổng Kiểm Soát Kỹ Thuật (Engineering Gates):
1. **`/idea`**: Ghi nhận bài toán và phạm vi cốt lõi từ PO (`IDEA.md`).
2. **`/req` (Gate A — PO Approval)**: Phân tích User Stories, Functional/Non-Functional Requirements và Tiêu chí nghiệm thu đo lường được (`REQUIREMENTS.md`). Chờ anh Tân duyệt mới sang bước tiếp theo.
3. **`/spec` (Gate B — SOURCE OF TRUTH)**: 
   - Khóa cứng JSON contract, API endpoints, Safe type parsing, UI constraints (`SPEC.md` & `ARCH.md`).
   - Bắt buộc có phần **ROOT-CAUSE ANALYSIS** đối với bug: `Symptom ➔ Reproduction ➔ Affected Layer ➔ Trace ➔ Evidence ➔ Root Cause ➔ Fix Strategy`.
   - Chờ anh Tân duyệt mới lập kế hoạch code.
4. **`/plan` (Pre-Build Gate)**: Lập kế hoạch chi tiết (`implementation_plan.md` + `task.md`). **CẤM CODE TRƯỚC KHI CÓ PLAN**.
5. **`/build` (Minimal Diff & Safe Coding)**:
   - Khóa cứng dependencies (`pubspec.yaml`), cấm tự ý thêm package.
   - Hủy sạch `Timer.periodic` tại `dispose()`.
   - Safe parsing dữ liệu `false`/`null` từ Odoo API.
   - Backend ORM context bắt buộc `.with_user(uid).sudo()`.
6. **`/test` (4-Layer Testing Hierarchy)**:
   - *Layer 1 — Static:* `flutter analyze` 0 errors, 0 warnings.
   - *Layer 2 — Automated:* Unit / Widget tests pass 100%.
   - *Layer 3 — Runtime:* Tương tác UI live thật, Token thật, Render không cắt chữ.
   - *Layer 4 — Production:* Endpoint live thật, Database thật.
   - Nguyên tắc: `Automated PASS ≠ Runtime PASS` và `Runtime PASS ≠ Production PASS`.
7. **`/review` (6-Dimensional Review)**: Đánh giá độc lập 6 khía cạnh: Architecture, SPEC Correctness, Safety (Null/Dispose), Performance, Regression, Production compatibility.
8. **`/ship` (Production Verification Gate)**:
   - Chuỗi pipeline: `Commit ➔ Push Branch ➔ Merge Request ➔ Merge 17.0/19.0/main ➔ Deployment Audit ➔ Service Reload ➔ Production Runtime Verification`.
   - Phân biệt: `Git Push SUCCESS ≠ Merge SUCCESS ≠ Deployment SUCCESS ≠ Runtime Loaded SUCCESS`.

---

## 3. 🔍 ANTI-GUESSING DIRECTIVE & EVIDENCE FRAMEWORK

### 3.1. Cấm Đoán Mò Nguyên Nhân (Zero Guessing)
- Không kết luận Root Cause chỉ dựa trên triệu chứng giao diện, log cũ, kinh nghiệm hay pattern quen thuộc.
- Không được sửa code chỉ để *"thử xem có hết lỗi không"*.
- Nếu chưa đủ bằng chứng thực tế: **BẮT BUỘC ghi rõ `ROOT CAUSE NOT YET VERIFIED`**.

### 3.2. Phân loại Bằng chứng (Evidence Gate)
- `VERIFIED`: Có bằng chứng trực tiếp (commit, test output, network response, server log, screenshot).
- `INFERRED — NOT YET VERIFIED`: Có suy luận kỹ thuật nhưng chưa chứng minh trực tiếp.
- `UNKNOWN`: Chưa có dữ liệu thực tế.
- `BLOCKED`: Bị chặn bởi phụ thuộc môi trường (VD: `BLOCKED — production deployment pending`).
- ❌ **CẤM TUYỆT ĐỐI**: Chuyển trạng thái `UNKNOWN / INFERRED / BLOCKED` thành `PASS` hoặc `DONE`.

### 3.3. Stop The Line Rule (Quy tắc dừng khẩn cấp)
Agent **BẮT BUỘC DỪNG NGAY** quy trình nếu phát hiện:
- Root cause chưa được xác định rõ ràng.
- Bằng chứng mâu thuẫn giữa các tầng (VD: automated test xanh nhưng runtime đỏ).
- Trạng thái Deployment hoặc Production runtime chưa xác định.
- Có nguy cơ thực hiện các thao tác phá hủy Git/DB.

### 3.4. Bản Đồ Cấu Trúc Dự Án & Định Vị Tức Thì (Fast Feature Navigation Directive)
> [!IMPORTANT]
> **SINGLE SOURCE OF TRUTH**: Khi nhận bất kỳ task nào liên quan đến tính năng (Chat v2, Attendance, Timesheet, Ticket, Auth, Profile, Push Notification...), AI **BẮT BUỘC** tra cứu toạ độ file từ:
> 🗺️ [`/media/tanma/DATA/save/mobile_versions/PROJECT_STRUCTURE_MAP.md`](file:///media/tanma/DATA/save/mobile_versions/PROJECT_STRUCTURE_MAP.md)

---

## 4. ✂️ PONYTAIL RULES (NGUYÊN TẮC VIẾT CODE TỐI GIẢN)
- **Nấc thang Leo Thang (The Ladder)**:
  1. Có thực sự cần build cái này không? (YAGNI).
  2. Đã có sẵn trong codebase chưa? Tái sử dụng helper/util/pattern cũ, không viết lại.
  3. Standard library đã làm được chưa? Dùng nó.
  4. Native platform feature có cover không?
  5. Dependency đã cài sẵn có giải quyết được không? Dùng nó, không thêm package mới.
  6. Có thể gói gọn 1 dòng không? Làm 1 dòng.
  7. Chỉ khi không nấc nào ở trên đủ: viết code tối thiểu để chạy đúng.
- **Sửa Root Cause, không vá Symptom**: Grep toàn bộ caller của hàm bị sửa, fix chung 1 chỗ ở core thay vì vá chắp vá từng nơi.
- **Không vẽ Abstraction thừa**: Không tạo interface nếu chỉ có 1 class thực thi, không tạo boilerplate thừa.

---

## 5. 🌿 GIT BRANCHING, CI/CD & MULTI-VERSION ODOO POLICY (RULE_GIT.MD & RULE_ODOO_VERSIONS.MD)

> [!CAUTION]
> **HIERARCHY TỐI CAO (SSOT)**: 
> - [`docs/RULE_ODOO_VERSIONS.md`](file:///media/tanma/DATA/save/mobile_versions/docs/RULE_ODOO_VERSIONS.md) là **Tài Liệu Chuẩn Mực Tối Cao (Single Source of Truth)** cho toàn bộ quy tắc phân định repository, phiên bản Odoo 17 & 19, authoritative branch, API contract và an toàn Git.
> - Nếu `AGENTS.md`, `CLAUDE.md`, `RULE_GIT.md` hoặc bất kỳ tài liệu nào khác có nội dung mâu thuẫn với `RULE_ODOO_VERSIONS.md` ➔ **STOP NGAY LẬP TỨC ➔ Không tự chọn một rule ➔ Đọc lại RULE_ODOO_VERSIONS.md ➔ Nếu vẫn mâu thuẫn: hỏi anh Tân.**

### 5.1 Branch Summary Table
| Repository / Directory | Branch | Target Version | Direct Push? | CI/CD & Merge Strategy |
| :--- | :--- | :--- | :---: | :--- |
| **`vclients` (Frontend)** | **`main`** | Flutter App `2.5.0+BUILD` | ❌ **NEVER** | **Tự động chạy GitHub Actions (TestFlight)** khi PR/MR được Merge vào `main`. |
| **`v_mobile_17` (Backend 17)** | **`17.0`** | Odoo 17.0+e (`17.0.X.Y.Z`) | ❌ **NEVER** | Requires Merge Request (MR) + Approval. CẤM push vào `19.0`. |
| **`v_mobile_19` (Backend 19)** | **`19.0`** | Odoo 19.0+e (`19.0.X.Y.Z`) | ❌ **NEVER** | Requires Merge Request (MR) + Approval. CẤM push vào `17.0`. |
| **Both** | **`fix/*` / `feat/*`** | Task branches theo số build (+1) | ✅ Yes | Merge Request / Pull Request vào `main` / `17.0` / `19.0`. Xóa sau merge! |

### 5.2 Các Quy Tắc Cốt Lõi Bắt Buộc (RULE_GIT.MD):
- **RULE 1**: KHÔNG sửa hoặc push trực tiếp vào branch `main` (Frontend), `17.0` (Backend 17) và `19.0` (Backend 19).
- **RULE 2**: Mỗi task một branch riêng. Không làm nhiều task trên 1 branch.
- **RULE 3**: Task branch phải được tạo từ HEAD mới nhất của `main` (Frontend) hoặc `17.0`/`19.0` (Backend).
- **RULE 4**: Không commit trước khi kiểm tra `git diff` & `git status`.
- **RULE 5**: Không dùng `git add .` một cách mù quáng.
- **RULE 6**: Không được bỏ sót untracked files (`?? file`).
- **RULE 7**: Không được báo DONE nếu test/analyze chưa được chạy (Static 0 lỗi + 100% tests PASS).
- **RULE 8**: Không được báo PRODUCTION READY nếu production chưa được verify.
- **RULE 9**: Không xóa task branch trước khi merge thành công.
- **RULE 10**: Sau merge phải verify commit ancestry (`git merge-base --is-ancestor`).
- **RULE 11**: Sau merge phải kiểm tra `main` / `17.0` / `19.0` thực tế.
- **RULE 12**: Không refactor ngoài scope (Ponytail Minimal Diff).
- **RULE 13**: Không fake backend/API/state để làm test pass.
- **RULE 14**: Nếu backend contract không hỗ trợ → báo limitation, không tự tạo behavior giả.
- **RULE 15**: Nếu phát hiện file liên quan chưa được commit → DỪNG quy trình commit/push → audit lại trước.
- **RULE 16**: Nếu working tree dirty ngoài scope → DỪNG, không được reset/xóa thay đổi của developer khác.
- **RULE 17**: Không force push trừ khi được yêu cầu rõ ràng.
- **RULE 18**: Không tự ý delete branch nếu chưa xác nhận merge.
- **RULE 19**: Mọi thay đổi production phải có: CODE → TEST → MERGE → DEPLOY → VERIFY.
- **RULE 20**: "Git push successful" KHÔNG đồng nghĩa với "task complete".
- **RULE 21 (RANH GIỚI LOCAL COMMIT VS PUSH REMOTE)**:
  * AI **ĐƯỢC PHÉP** commit cục bộ sau khi đã chạy tests bắt buộc và kiểm tra diff sạch (`git diff --stat`).
  * AI **TUYỆT ĐỐI CẤM** chạy `git push` lên bất kỳ remote nào cho đến khi thỏa mãn đủ 3 điều kiện:
    1. Toàn bộ automated tests PASS (`flutter analyze` 0 errors/warnings, 100% tests pass).
    2. Runtime / UI verification PASS.
    3. **Anh Tân trực tiếp kiểm tra và cho phép PUSH (explicit authorization)**.
- **RULE 22 (QUY ĐỊNH GITHUB ACTIONS TRÊN NHÁNH `main`)**: GitHub Actions (`deploy.yml`) **CHỈ ĐƯỢC PHÉP CHẠY TRÊN NHÁNH `main`** khi có PR/commit merge vào `main`. Nhánh cũ `release/ios-appstore` đã bị loại bỏ hoàn toàn.
- **RULE 23 (QUY TRÌNH XÓA NHÁNH SAU MERGE & BẢO VỆ AN TOÀN GIT)**:
  * Sau khi một task branch đã merge thành công và đã xác minh ancestry (`git merge-base --is-ancestor <task-commit> <target-branch>` PASS), được phép xóa task branch local và remote theo quy trình cleanup.
  * Việc xóa task branch **CHỈ ĐƯỢC THỰC HIỆN** khi thỏa mãn đủ 4 điều kiện:
    1. PR/MR đã ở trạng thái **MERGED**.
    2. Target branch (`main` / `17.0` / `19.0`) đã chứa toàn bộ commit của task.
    3. `git merge-base --is-ancestor <task-commit> <target-branch>` trả về kết quả **PASS (exit code 0)**.
    4. Không còn công việc dở dang hoặc chưa commit trên branch đó.
  * ❌ **CẤM TUYỆT ĐỐI** dùng `git branch -D` cưỡng chế xóa khi 4 điều kiện trên chưa PASS.
- **RULE 24 (QUY TẮC ĐẶT TÊN NHÁNH & QUẢN LÝ SỐ BUILD)**:
  * `BUILD_NUMBER` phải được xác minh từ Source of Truth hiện tại (`pubspec.yaml` / Git Tags / TestFlight). AI **KHÔNG ĐƯỢC TỰ SUY ĐOÁN HOẶC TỰ TĂNG BUILD_NUMBER**.
  * Định dạng chuẩn tên nhánh: `fix/app-build<BUILD_NUMBER>-task-name` (hoặc `feat/app-build<BUILD_NUMBER>-...`).
  * Nếu task là release task và cần `BUILD_NUMBER` mới:
    1. Xác minh số BUILD hiện tại trong `pubspec.yaml`.
    2. Đề xuất số BUILD tiếp theo (`+1`).
    3. **Chờ anh Tân xác nhận rõ ràng trước khi cập nhật số version/build**.
  * Cấm tái sử dụng tên nhánh của các build cũ đã qua.
- **RULE 25**: Khi báo cáo trạng thái Git Push cho anh Tân, BẮT BUỘC xuất định dạng báo cáo siêu ngắn (Concise Push Report) chứa thông tin branch, commit hash, message và link tạo PR/MR.
- **RULE 26 (QUY TRÌNH TẠO RELEASE & BÁO CÁO AUDIT KỸ THUẬT)**: Mỗi lần tạo bản phát hành mới sau khi merge vào `main`, tạo Release chính thức trên GitHub/GitLab gắn kèm nội dung [`docs/AUDIT_REPORT.md`](file:///media/tanma/DATA/save/mobile_versions/docs/AUDIT_REPORT.md). Tag và Release **TUYỆT ĐỐI KHÔNG** kích hoạt action CI/CD tự động.
- **RULE 27 (ĐỒNG BỘ TAG & TARGET COMMIT TRÊN `main`)**: Mọi Tag phát hành (VD: `v2.5.0+94`) **BẮT BUỘC trỏ chính xác vào commit mới nhất của nhánh `main`** (sau khi merge PR) và đồng bộ 100% trên remote. **CẤM gắn tag từ task branch**.
- **RULE 28 (QUY TẮC QUẢN TRỊ CHANGELOG & CHỐNG LẠM PHÁT VERSION)**:
  * Đang ở version nào thì tiếp tục ghi nhận toàn bộ thay đổi ở version đó trong suốt quá trình làm việc trên task branch.
  * **CẤM NHẢY CÓC VERSION**: Tuyệt đối không tự ý tạo version mới trong `CHANGELOGS.md` khi version hiện tại chưa deploy TestFlight, chưa test thực tế trên iPhone 13 của anh Tân, và chưa merge/xóa branch.
- **RULE 29 (BẮT BUỘC ĐỌC RULE_ODOO_VERSIONS.MD & RULE_GIT.MD)**: Trước mỗi thao tác Git, Branching hoặc cập nhật `CHANGELOGS.md`, AI BẮT BUỘC phải đọc và tuân thủ [`docs/RULE_ODOO_VERSIONS.md`](file:///media/tanma/DATA/save/mobile_versions/docs/RULE_ODOO_VERSIONS.md).

---

## 6. 📱 iOS Build & TestFlight Enforcement Rules
- **Export Compliance**: File `vclients/ios/Runner/Info.plist` bắt buộc có:
  ```xml
  <key>ITSAppUsesNonExemptEncryption</key>
  <false/>
  ```
- **Versioning**: Chuỗi version trong `pubspec.yaml` theo định dạng `X.Y.Z+BUILD` (VD: `2.5.0+94`).

---

## 7. 📋 DEFINITION OF DONE (TIÊU CHUẨN HOÀN THÀNH)

### 🔴 NOT DONE:
- Code chưa test, test fail, review fail.
- Merge chưa hoàn tất hoặc chưa xóa task branch.
- Deployment chưa xác nhận.
- Production runtime chưa load mã mới.

### 🟡 BLOCKED:
- Code PASS, Git PASS, Merge PASS nhưng Production deployment / runtime chưa kiểm chứng được.
- **Kết luận bắt buộc:** `BLOCKED — PRODUCTION VERIFICATION PENDING` (Tuyệt đối không báo DONE).

### 🟢 DONE (Hoàn thành thực sự):
Chỉ khi thỏa mãn toàn bộ:
```text
SPEC PASS + IMPLEMENTATION PASS + TEST PASS (Static + Automated + Runtime) + REVIEW PASS + SHIP PASS + DEPLOYMENT VERIFIED + PRODUCTION RUNTIME VERIFIED + ACCEPTANCE CRITERIA VERIFIED
```

---

## 8. 🚀 QUY TRÌNH PHÁT HÀNH & BÁO CÁO AUDIT RELEASE (RELEASE & AUDIT LIFECYCLE)

Mọi quy trình phát hành bản dựng (Release / TestFlight) BẮT BUỘC tuân thủ chuỗi 7 bước tuần tự có kiểm soát sau:

```text
Task Branch ➔ Test PASS ➔ Review PASS ➔ Local Commit ➔ Push Task Branch ➔ GitHub PR / GitLab MR ➔ MERGED vào main / 17.0 / 19.0 ➔ Verify Target Branch HEAD ➔ Create Annotated Tag trên main ➔ Push Tag ➔ Create Release kèm AUDIT_REPORT.md ➔ Production / TestFlight Verify ➔ Cleanup Task Branch
```

### Chi tiết 7 bước tuần tự:
1. **Bước 1 — Phát triển, Kiểm thử & PR/MR**:
   - Thực hiện thay đổi code tối giản trên task branch.
   - Chạy kiểm tra tĩnh và kiểm thử: `flutter analyze` (0 errors, 0 warnings), unit/widget tests 100% PASS.
   - Commit với Git Trailer chuẩn và push task branch lên remote để tạo Pull Request (GitHub) hoặc Merge Request (GitLab).
2. **Bước 2 — Merge vào Nhánh Chính**:
   - Anh Tân kiểm tra, duyệt và thực hiện Merge PR vào **`main`** (Frontend) hoặc MR vào **`17.0`** / **`19.0`** (Backend).
3. **Bước 3 — Xác thực HEAD Nhánh Chính & Cập nhật Tài liệu**:
   - Checkout sang `main` (hoặc `17.0`/`19.0`), kéo code mới nhất (`git pull --ff-only`).
   - Kiểm tra commit ancestry: `git merge-base --is-ancestor <task-commit> HEAD` (Bắt buộc exit code 0).
   - Cập nhật chi tiết lịch sử thay đổi tại `docs/CHANGELOGS.md`.
   - Lập/Cập nhật file Báo Cáo Audit Kỹ Thuật tại `docs/AUDIT_REPORT.md`.
4. **Bước 4 — Gắn Git Tag Trên Đỉnh Nhánh Chính (CẤM GẮN TỪ TASK BRANCH)**:
   - Tạo Git Tag chuẩn có chú thích trên **đúng commit của nhánh `main`**:
     `git tag -a -f vX.Y.Z+BUILD -m "Release vX.Y.Z+BUILD" <main-commit-hash>`
   - Push tag đồng bộ lên toàn bộ các remote:
     `git push origin refs/tags/vX.Y.Z+BUILD --force` và `git push github refs/tags/vX.Y.Z+BUILD --force`
5. **Bước 5 — Tạo Release Kèm Báo Cáo Audit**:
   - Xuất bản Release chính thức trên GitHub / GitLab gắn trực tiếp với tag `vX.Y.Z+BUILD` trên đỉnh `main`.
   - Tiêu đề Release: `Release vX.Y.Z (Build BUILD)`.
   - Nội dung Release Body: Nhúng toàn bộ nội dung file `docs/AUDIT_REPORT.md` để đảm bảo tính minh bạch và truy xuất nguồn gốc kiểm toán.
6. **Bước 6 — Production / TestFlight Runtime Verification**:
   - Kiểm chứng bản build tự động trên TestFlight (iPhone 13 của anh Tân) và runtime Odoo Backend live.
7. **Bước 7 — Dọn Dẹp Task Branch (Tuân thủ RULE 23)**:
   - Xóa sạch các task branch đã merge cả ở local và remote theo đúng 4 điều kiện kiểm chứng của **RULE 23**.
   - Báo cáo đường dẫn tuyệt đối đầy đủ của Release và file Audit Report cho anh Tân.

---

## 9. 🤝 QUY CHUẨN PHỐI HỢP TRIỂN KHAI GIỮA ANH TÂN & CLAUDE CODE (DEPLOY COLLABORATION PROTOCOL)

1. **Phân Định Trách Nhiệm Rõ Ràng**:
   - **Anh Tân**: Trực tiếp merge và kích hoạt triển khai Frontend qua **GitHub Actions CI/CD** (nhánh **`main`**) để build bản dựng phát hành TestFlight cho iPhone 13 của anh Tân.
   - **Claude Code & Sếp Châu**: Kiểm duyệt audit và triển khai Backend Odoo trên nhánh **`17.0`** (`v_mobile_17`) và **`19.0`** (`v_mobile_19`).
2. **Cảnh Báo Tối Quan Trọng Dành Cho Claude Code Khi Deploy Backend**:
   - **CẤM TỰ Ý SỬA ĐỔI LOGIC CODE ĐÃ KIỂM TOÁN**: Trong khi audit và deploy nhánh `17.0` / `19.0`, Claude Code tuyệt đối không tự ý sửa đổi code, cấu trúc API, DTO model hoặc query logic đã pass test.
   - *Hậu quả*: Nếu Claude Code sửa logic/contract, toàn bộ **246 bài test** trên máy anh Tân sẽ bị **LỖI ĐỎ (FAIL)** ➔ **GitHub Actions CI/CD của Frontend sẽ BỊ CHẶN HOÀN TOÀN (Build Failed)** ➔ App không thể deploy và iPhone 13 không thể nhận bản cập nhật API đúng.
   - *Quy tắc góp ý*: Nếu Claude Code thấy chỗ cần cải tiến, **BẮT BUỘC CHỈ GHI Ý KIẾN VÀO `docs/AUDIT_REPORT.md` VÀ `docs/CHANGELOGS.md`**, không sửa thẳng vào code trước khi anh Tân đồng thuận.
3. **Quy Trình Hoàn Tất Đồng Bộ 2 Đầu**:
   - Frontend deploy qua GitHub Actions (`main`) ➔ Backend deploy qua Claude Code (`17.0` / `19.0`) ➔ iPhone 13 nhận bản cập nhật TestFlight mới và khớp 100% API live. Chi tiết xem tại [`docs/DEPLOY_COLLABORATION_RULES.md`](file:///media/tanma/DATA/save/mobile_versions/docs/DEPLOY_COLLABORATION_RULES.md).

---

## 10. 🧠 AIaC SKILL AUTO-SELECTION & EXECUTION POLICY

Antigravity and all AI Agents MUST automatically select, discover, and use the **Minimum Relevant Installed AIaC Skills** based on anh Tân's natural task intent without requiring explicit skill names.

### 10.1. Intent-to-Skill Routing Matrix:
* **Audit / Review / Kiểm tra / Đánh giá**:
  ➔ `project-checklist-audit` + domain skill (`360-vcloud` / `360-odoo` / `360-flutter` / `dart-flutter-patterns`) + `360-codegraph` + `360-ponytail`.
* **Bug Fix / Sửa lỗi / Khắc phục / Crash / Freeze**:
  ➔ Domain skill (`360-flutter` / `dart-flutter-patterns` / `360-odoo` / `360-vcloud`) + `360-ponytail` + `360-codegraph` + `project-checklist-audit` + Root-cause evidence trace.
* **Feature / Thêm tính năng / Phát triển mới**:
  ➔ `360-dev-workflow` (8-Step Gate) + domain skill (`360-flutter` / `360-odoo`) + `360-codegraph` + `360-ponytail` + `project-checklist-audit`.
* **Testing / Kiểm thử / QA**:
  ➔ `project-checklist-audit` + domain test suites (`360-flutter` / `360-odoo` / `360-vcloud`) + `flutter-local-launcher`.
* **Git / Branch / PR / MR / Release / Deploy**:
  ➔ `360-gitsync` + [`docs/RULE_ODOO_VERSIONS.md`](file:///media/tanma/DATA/save/mobile_versions/docs/RULE_ODOO_VERSIONS.md) + [`docs/RULE_GIT.md`](file:///media/tanma/DATA/save/mobile_versions/docs/RULE_GIT.md).
* **Navigation / Large Features (Chat, Attendance, Timesheet, Ticket, Auth...)**:
  ➔ `360-codegraph` + `360-graphify` + [`/media/tanma/DATA/save/mobile_versions/PROJECT_STRUCTURE_MAP.md`](file:///media/tanma/DATA/save/mobile_versions/PROJECT_STRUCTURE_MAP.md).

### 10.2. Core Principles:
1. **Minimum Relevant Skill Set**: Chỉ kích hoạt tập hợp skill tối thiểu và liên quan trực tiếp, không load tràn lan.
2. **Skill Verification Before Claim**: Bắt buộc đọc file instruction (`SKILL.md` hoặc `prompts/SKILL.md`) trước khi thực thi. Nếu skill bị lỗi/thiếu ➔ Báo `BLOCKED / NOT FOUND`, cấm giả mạo skill execution.
3. **Repository Rules Overwrite**: Quy định trong `AGENTS.md`, `RULE_ODOO_VERSIONS.md`, `RULE_GIT.md` luôn có thẩm quyền cao hơn mọi hướng dẫn của skill đơn lẻ.
