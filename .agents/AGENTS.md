# Project-Scoped Rules for Mobile App & Odoo Backend

## Mobile Project Workflow Enforcement
Whenever the user requests to work on the Mobile project:
1. **Frontend (Flutter)**: Automatically trigger and use the `dev-workflow-skills` skill.
2. **Backend (Odoo 17 API)**: Automatically trigger and use the `odoo-development` skill.
3. **Review & Documentation**: Always execute the `/review` phase and ensure a `walkthrough.md` artifact is created summarizing the changes upon completion.

---

## 🚫 Git Branching & Push Rules (Quy tắc Push Git chuẩn)

### 1. Nhánh Git & Quyền Hạn (Branches & Permissions)
- **`17.0` (Protected Branch)**: Nhánh sản xuất/staging chính của Odoo 17 API.
  - ❌ **CẤM PUSH TRỰC TIẾP** (`git push origin 17.0` bị chặn tự động).
  - ✅ **QUY TRÌNH CHUẨN**: Tạo nhánh tính năng/sửa lỗi riêng (`fix/*` hoặc `feature/*`) -> Push lên GitLab -> Tạo Merge Request (MR) -> Nhờ Sếp/Reviewer bấm Merge.
- **`fix/<tên-lỗi>`** hoặc **`feature/<tên-tính-năng>`**: Nhánh làm việc tạm thời của lập trình viên.

### 2. Các File CÓ ĐƯỢC Push (`v_mobile`)
- ✅ Mã nguồn Module Python (`__manifest__.py`, `__init__.py`, `controllers/`, `models/`, `hooks.py`, `tests/`).
- ✅ XML Views & Data (`views/`, `data/`, `security/`).
- ✅ Tài liệu dự án (`README.md`, `CHANGELOG.md`, `.gitignore`, `requirements.txt`).

### 3. Các File/Thư Mục TUYỆT ĐỐI CẤM Push
- 🚫 **Các thư mục Odoo Enterprise phụ thuộc môi trường local**:
  - `helpdesk/`, `helpdesk_sms/`, `spreadsheet_dashboard_helpdesk/`, `web_cohort/`.
  - *(Luôn phải giữ trong `.gitignore`)*.
- 🚫 **File rác/Bytecode/Cache**: `__pycache__/`, `*.pyc`, `.DS_Store`.
- 🚫 **Cấu trúc lặp tên module**: Không tự ý tạo thêm thư mục trùng tên `mobile_api/` lặp lại cấu trúc bên trong root repo.

### 4. Quy trình 5 bước chuẩn trước khi tạo Merge Request (MR)
0. **BẮT BUỘC PULL CODE MỚI NHẤT**: Trước khi làm bất kỳ công việc gì, luôn chạy `git checkout 17.0 && git pull origin 17.0` để lấy mã nguồn mới nhất từ server, tránh dùng code cũ đè code mới.
1. `git status` — Kiểm tra xem làm việc đúng nhánh chưa, đảm bảo môi trường không bị dính file rác.
2. `git commit` — Đặt commit message rõ ràng theo chuẩn (`fix(mobile_api): ...`, `docs: ...`).
3. `git push origin fix/<tên-nhánh>` — Push lên nhánh làm việc.
4. Mở link GitLab tạo **Merge Request**, tóm tắt ngắn gọn thay đổi và gửi Sếp review.

---

## Antigravity Autopilot Execution Rules

- **Post-Build Action:** Every time you finish editing UI files, automatically reload the browser UI using:
  - Command: `python3 vcloud-orchestrator-v6.py restart`
- **Pre-Flight Asset Audit:** Before launching the dev server, clear ports and audit assets by running:
  - Command: `python3 vcloud-orchestrator-v6.py clean`

---

## 📱 iOS Build & TestFlight Enforcement Rules

### Mandatory Export Compliance Rule for iOS App Store & TestFlight
Every Flutter iOS project (`vclients/ios/Runner/Info.plist`) **MUST** include the following key to prevent TestFlight builds from stalling or requiring manual export compliance verification:
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```
- **Rationale**: Omitting this key causes App Store Connect to block TestFlight distribution to internal/external groups with "Missing Export Compliance", requiring manual prompts on every build upload.
- **Reference**:
  - File: `ios/Runner/Info.plist`
  - Commit: `276392c` (`fix(ios): add ITSAppUsesNonExemptEncryption key to Info.plist to automate TestFlight export compliance`)
  - Branch: `release/ios-appstore`
  - Repository: `gitlab.com:360org_mobiles/vclients.git`

