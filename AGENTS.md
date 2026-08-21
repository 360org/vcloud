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
- **Hiển thị đường dẫn File & Báo cáo (BẮT BUỘC)**: Mọi đường dẫn file, báo cáo audit, deliverables khi thông báo cho anh Tân **BẮT BUỘC** trình bày dạng đường dẫn tuyệt đối đầy đủ từ Root Volume (VD: `/media/tanma/DATA/save/mobile/SPEC.md`).
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
   - Chuỗi pipeline: `Commit ➔ Push Branch ➔ Merge Request ➔ Merge 17.0 ➔ Deployment Audit ➔ Service Reload ➔ Production Runtime Verification`.
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

## 5. 🌿 GIT BRANCHING & PUSH POLICY (27 HARD RULES)

### 5.1 Branch Summary Table
| Branch | Purpose | Direct Push Allowed? | Merge Strategy |
| :--- | :--- | :---: | :--- |
| **`17.0`** | Protected Production / Staging branch (Odoo 17 API) | ❌ **NEVER** | Requires Merge Request (MR) + Approval |
| **`fix/*`** | Bug fixes & maintenance | ✅ Yes | Merge Request to `17.0` |
| **`feature/*`** | New features & enhancements | ✅ Yes | Merge Request to `17.0` |
| **`release/ios-appstore`** | iOS App Store & TestFlight release builds | ✅ **Yes** | Direct Push / Codemagic Pipeline |

### 5.2 27 Hard Rules Bắt Buộc:
- **RULE 1**: KHÔNG sửa trực tiếp branch `17.0`.
- **RULE 2**: Mỗi task một branch riêng.
- **RULE 3**: Task branch phải được tạo từ HEAD mới nhất của `17.0`.
- **RULE 4**: Không commit trước khi kiểm tra `git diff` & `git status`.
- **RULE 5**: Không dùng `git add .` một cách mù quáng.
- **RULE 6**: Không được bỏ sót untracked files (`?? file`).
- **RULE 7**: Không được báo DONE nếu test/analyze chưa được chạy.
- **RULE 8**: Không được báo PRODUCTION READY nếu production chưa được verify.
- **RULE 9**: Không xóa task branch trước khi merge thành công.
- **RULE 10**: Sau merge phải verify commit ancestry (`git merge-base --is-ancestor`).
- **RULE 11**: Sau merge phải kiểm tra `17.0` thực tế.
- **RULE 12**: Không refactor ngoài scope.
- **RULE 13**: Không fake backend/API/state để làm test pass.
- **RULE 14**: Nếu backend contract không hỗ trợ → báo limitation, không tự tạo behavior giả.
- **RULE 15**: Nếu phát hiện file liên quan chưa được commit → DỪNG quy trình commit/push → audit lại trước.
- **RULE 16**: Nếu working tree dirty ngoài scope → DỪNG, không được reset/xóa thay đổi của developer khác.
- **RULE 17**: Không force push trừ khi được yêu cầu rõ ràng.
- **RULE 18**: Không tự ý delete branch nếu chưa xác nhận merge.
- **RULE 19**: Mọi thay đổi production phải có: CODE → TEST → MERGE → DEPLOY → VERIFY.
- **RULE 20**: "Git push successful" KHÔNG đồng nghĩa với "task complete".
- **RULE 21**: TUYỆT ĐỐI KHÔNG tự ý `git push` khi chưa được anh Tân kiểm tra giao diện (UI test) và cho phép.
- **RULE 22 (QUY ĐỊNH PUSH NHÁNH RELEASE FRONTEND `release/ios-appstore`)**: Đối với repository Frontend (`vclients`), anh Tân cho phép Agent có thể push trực tiếp vào nhánh `release/ios-appstore` trên GitLab (`origin`) và GitHub (`github`) để phục vụ quy trình build CI/CD TestFlight / App Store theo yêu cầu hoặc khi phát hành bản dựng mới.
- **RULE 23 (QUY TRÌNH XÓA NHÁNH SAU MERGE)**: Sau khi một nhánh làm việc (feature/fix/task branch) đã được merge thành công vào nhánh đích (`17.0` / `main`), BẮT BUỘC xóa ngay lập tức nhánh nguồn đó trên cả Remote (GitLab `origin` & GitHub `github`) và Local (`git push origin --delete <branch>` & `git branch -D <branch>`). Tuyệt đối KHÔNG giữ lại nhánh rác và KHÔNG tái sử dụng nhánh cũ đã merge để code tiếp (tránh lệch commit ancestry và xung đột code). Đợt làm việc mới luôn tạo nhánh mới từ đỉnh `17.0`.
- **RULE 24 (QUY TẮC ĐẶT TÊN NHÁNH THEO SỐ BUILD +1 BẮT BUỘC)**: Mỗi lần nâng cấp phiên bản / đợt làm việc mới, tên nhánh làm việc BẮT BUỘC được đặt chuẩn hóa theo số Build và tự động tăng +1:
  * **Định dạng chuẩn**: `fix/app-build<BUILD_NUMBER>-stabilization` (hoặc `feat/app-build<BUILD_NUMBER>-...`).
  * **Ví dụ thực tế**: Phiên bản Build 80 dùng nhánh `fix/app-build80-stabilization` ➔ Khi lên Build 81, BẮT BUỘC tạo nhánh mới `fix/app-build81-stabilization` từ đỉnh `17.0`. Khi lên Build 82 ➔ tạo nhánh `fix/app-build82-stabilization`...
  * **Cấm tái sử dụng**: Tuyệt đối KHÔNG dùng lại tên nhánh của các build cũ đã qua. Sau khi nhánh được merge vào `17.0` và release xong, nhánh sẽ được xóa sạch theo **RULE 23** và đợt làm việc kế tiếp BẮT BUỘC tạo nhánh mới với số Build +1.
- **RULE 25**: Khi báo cáo trạng thái Git Push cho anh Tân, BẮT BUỘC xuất định dạng báo cáo siêu ngắn (Concise Push Report) chứa thông tin branch, trạng thái sync `origin`, commit hash, message và link tạo MR trực tiếp trên GitLab.
- **RULE 26 (QUY TRÌNH TẠO RELEASE & BÁO CÁO AUDIT KỸ THUẬT BẮT BUỘC)**: Mỗi lần tạo bản phát hành mới (Release / TestFlight / Tag mới), BẮT BUỘC đồng thời tạo Release chính thức trên GitHub / GitLab gắn kèm toàn bộ nội dung **Báo Cáo Audit Kỹ Thuật (Technical Audit Report)** chuẩn hóa (`360-flutter` & AIaC Dev Standard).
- **RULE 27 (ĐỒNG BỘ TAG & TARGET COMMIT)**: Mọi Tag phát hành (VD: `v2.5.0+78`) BẮT BUỘC trỏ chính xác vào commit mới nhất của nhánh release (`release/ios-appstore`) và đồng bộ 100% trên toàn bộ các remote (GitLab `origin`, GitHub `github`, `github-build`).

---

## 6. 📱 iOS Build & TestFlight Enforcement Rules
- **Export Compliance**: File `vclients/ios/Runner/Info.plist` bắt buộc có:
  ```xml
  <key>ITSAppUsesNonExemptEncryption</key>
  <false/>
  ```
- **Versioning**: Chuỗi version trong `pubspec.yaml` theo định dạng `X.Y.Z+BUILD` (VD: `2.5.0+78`).

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

Mọi quy trình phát hành bản dựng (Release / TestFlight) BẮT BUỘC tuân thủ 5 bước chuẩn hóa sau:

1. **Bước 1 — Nâng cấp Phiên bản & Kiểm thử Toàn diện**:
   - Cập nhật số phiên bản chính xác trong `pubspec.yaml` (VD: `version: 2.5.0+78`).
   - Chạy kiểm tra tĩnh và kiểm thử: `flutter analyze` (0 errors, 0 warnings), `flutter test` (100% PASS).
2. **Bước 2 — Cập nhật Tài liệu Kỹ thuật & Báo Cáo Audit**:
   - Cập nhật chi tiết lịch sử thay đổi tại `docs/CHANGELOGS.md`.
   - Lập/Cập nhật file Báo Cáo Audit Kỹ Thuật tại `docs/AUDIT_REPORT.md` theo bộ khung chuẩn 4 phần của `360-flutter`:
     * *Phần 1:* Tổng quan hệ thống mã nguồn (Số files, dòng code, kiến trúc, kiểm thử).
     * *Phần 2:* Kết quả audit chi tiết 5 trụ cột: Clean Architecture 3 lớp (100/100), Async/RAM & iPhone Freeze Safety (≥95/100), Apple HIG & UI/UX (100/100), Tiêu chuẩn Ponytail (≥95/100), Tuân thủ App Store Connect & CI/CD (100/100).
     * *Phần 3:* Bảng tổng kết điểm số các hạng mục kiểm toán.
     * *Phần 4:* Kết luận và kiến nghị phát hành TestFlight / App Store.
3. **Bước 3 — Commit, Push & Gắn Git Tag**:
   - Commit toàn bộ thay đổi và push lên nhánh `release/ios-appstore`.
   - Tạo Git Tag chuẩn có chú thích: `git tag -a -f vX.Y.Z+BUILD -m "Release vX.Y.Z+BUILD" <commit-hash>`.
   - Push tag đồng bộ lên toàn bộ các remote: `git push origin refs/tags/vX.Y.Z+BUILD --force` và `git push github refs/tags/vX.Y.Z+BUILD --force`.
4. **Bước 4 — Tạo / Cập nhật Release Kèm Báo Cáo Audit**:
   - Xuất bản Release chính thức trên GitHub / GitLab gắn trực tiếp với tag `vX.Y.Z+BUILD`.
   - Tiêu đề Release: `Release vX.Y.Z (Build BUILD)`.
   - Nội dung Release Body: Nhúng toàn bộ nội dung file `docs/AUDIT_REPORT.md` để đảm bảo tính minh bạch và truy xuất nguồn gốc kiểm toán.
5. **Bước 5 — Dọn Dẹp Nhánh Nguồn & Xác Nhận**:
   - Sau khi merge/release hoàn tất, lập tức xóa sạch các nhánh làm việc tạm/source branch cả ở local và remote theo **RULE 23**.
   - Báo cáo đường dẫn tuyệt đối đầy đủ của Release và file Audit Report cho anh Tân.

---

## 9. 🤝 QUY CHUẨN PHỐI HỢP TRIỂN KHAI GIỮA ANH TÂN & CLAUDE CODE (DEPLOY COLLABORATION PROTOCOL)

1. **Phân Định Trách Nhiệm Rõ Ràng**:
   - **Anh Tân**: Trực tiếp merge và kích hoạt triển khai Frontend qua **GitHub Actions CI/CD** (nhánh `release/ios-appstore`) để build bản dựng phát hành TestFlight cho iPhone 13 của anh Tân.
   - **Claude Code & Sếp Châu**: Kiểm duyệt audit và triển khai Backend Odoo trên nhánh **`17.0`** (`v_mobile` / Odoo SaaS Zero-Downtime Upgrade).
2. **Cảnh Báo Tối Quan Trọng Dành Cho Claude Code Khi Deploy Backend**:
   - **CẤM TỰ Ý SỬA ĐỔI LOGIC CODE ĐÃ KIỂM TOÁN**: Trong khi audit và deploy nhánh `17.0`, Claude Code tuyệt đối không tự ý sửa đổi code, cấu trúc API, DTO model hoặc query logic đã pass test.
   - *Hậu quả*: Nếu Claude Code sửa logic/contract, toàn bộ **207 bài test** trên máy anh Tân sẽ bị **LỖI ĐỎ (FAIL)** ➔ **GitHub Actions CI/CD của Frontend sẽ BỊ CHẶN HOÀN TOÀN (Build Failed)** ➔ App không thể deploy và iPhone 13 không thể nhận bản cập nhật API đúng.
   - *Quy tắc góp ý*: Nếu Claude Code thấy chỗ cần cải tiến, **BẮT BUỘC CHỈ GHI Ý KIẾN VÀO `docs/AUDIT_REPORT.md` VÀ `docs/CHANGELOGS.md`**, không sửa thẳng vào code trước khi anh Tân đồng thuận.
3. **Quy Trình Hoàn Tất Đồng Bộ 2 Đầu**:
   - Frontend deploy qua GitHub Actions ➔ Backend deploy qua Claude Code (`17.0`) ➔ iPhone 13 nhận bản cập nhật TestFlight mới và khớp 100% API live. Chi tiết xem tại [`docs/DEPLOY_COLLABORATION_RULES.md`](file:///media/tanma/DATA/save/mobile/docs/DEPLOY_COLLABORATION_RULES.md).
