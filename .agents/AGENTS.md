<!-- # Project-Scoped Rules for Mobile App & Odoo Backend

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
 -->
# Project-Scoped Rules for Mobile App & Odoo Backend

## 0. GLOBAL RULES & SAFETY

These rules apply to all work performed in this project.

### 0.1 Scope

* Follow all rules in this document before modifying the project.
* Do not modify files unrelated to the requested task.
* Do not introduce unnecessary refactors, dependency upgrades, architecture changes, or formatting changes unrelated to the task.
* Preserve the existing project architecture and conventions unless the task explicitly requires a change.
* When unsure whether a change is required, prefer the smallest safe change.

### 0.2 Destructive Operations

NEVER execute the following commands without explicit user approval:

```bash
git reset --hard
git clean -fd
git clean -fdx
git restore <file>
git checkout -- <file>
git push --force
git push --force-with-lease
rm -rf
```

Also:

* Never delete user-created files without explicit approval.
* Never overwrite unrelated uncommitted work.
* Never automatically stash, reset, discard, or clean user changes.
* Never force-push a branch unless explicitly authorized.
* Never modify or remove files only because they appear unused unless the task explicitly requires it.

### 0.3 Secrets & Credentials

NEVER commit or expose:

* API keys
* Access tokens
* Passwords
* Private keys
* Signing certificates
* Provisioning profiles
* `.env` files containing secrets
* Cloud credentials
* Git credentials
* Production credentials

If a task requires credentials that are not available, stop and ask the user.

---

# 1. MOBILE PROJECT WORKFLOW

When working on the Mobile project, the appropriate development skill MUST be used automatically.

## 1.1 Flutter Frontend

For Flutter/mobile frontend work:

* Automatically trigger and use the `dev-workflow-skills` skill.
* Follow the project's existing Flutter architecture and conventions.
* Do not introduce new packages unless required by the task.
* Prefer existing dependencies and utilities when possible.

## 1.2 Odoo 17 Backend

For Odoo 17 API/backend work:

* Automatically trigger and use the `odoo-development` skill.
* Follow Odoo 17 conventions.
* Preserve existing module architecture.
* Respect Odoo security rules, access rights, controllers, models, views, and ORM conventions.

## 1.3 Review & Documentation

Every Mobile task MUST execute the following workflow:

```text
Implementation
    ↓
Tests / Validation
    ↓
Build Validation
    ↓
/review
    ↓
Fix Review Findings
    ↓
Re-test
    ↓
Create / Update walkthrough.md
    ↓
Git Verification
    ↓
Commit
    ↓
Push Feature/Fix Branch
    ↓
Create Merge Request
```

NEVER skip `/review`.

A Mobile task is not considered complete until `walkthrough.md` has been created or updated.

---

# 2. GIT BRANCHING & PUSH RULES

## 2.1 Protected Branch

`17.0` is the protected production/staging branch for the Odoo 17 API.

### NEVER:

```bash
git push origin 17.0
```

NEVER push directly to `17.0`.

NEVER commit work directly on `17.0` for a feature or bug fix.

## 2.2 Working Branches

All development MUST use a dedicated branch:

```text
fix/<bug-name>
```

or:

```text
feature/<feature-name>
```

Examples:

```text
fix/mobile-login-token
fix/ios-testflight-version
feature/mobile-notification
feature/employee-api
```

## 2.3 Standard Git Flow

```text
17.0
  ↓
Create fix/* or feature/*
  ↓
Develop
  ↓
Test
  ↓
Review
  ↓
Commit
  ↓
Push
  ↓
Create GitLab Merge Request
  ↓
Reviewer approval
  ↓
Merge into 17.0
```

The Agent MUST NOT merge the Merge Request automatically unless explicitly instructed.

---

# 3. PRE-FLIGHT GIT CHECK

Before starting any implementation work, ALWAYS inspect the Git state.

## 3.1 Check Current State

Run:

```bash
git status --short
git branch --show-current
```

## 3.2 Dirty Working Tree

If the working tree contains uncommitted changes:

* DO NOT reset them.
* DO NOT discard them.
* DO NOT automatically stash them.
* DO NOT run `git clean`.
* Determine whether the changes belong to the current task.

If it is unclear whether existing changes belong to the current task, STOP and ask the user before modifying them.

## 3.3 Update Protected Branch

Only when the working tree is clean:

```bash
git checkout 17.0
git pull --ff-only origin 17.0
```

Use:

```bash
git pull --ff-only origin 17.0
```

instead of a normal `git pull`.

Do not create automatic merge commits while synchronizing `17.0`.

## 3.4 Create Working Branch

After updating `17.0`:

For bug fixes:

```bash
git checkout -b fix/<bug-name>
```

For features:

```bash
git checkout -b feature/<feature-name>
```

---

# 4. GIT CHANGE ISOLATION

Only modify files required by the requested task.

Before committing:

```bash
git status
git diff
```

Check for:

* Unexpected files
* Generated files
* Cache files
* Local configuration
* Credentials
* Enterprise dependencies
* Unrelated modifications

Remove unrelated changes from the staging area before committing.

NEVER blindly execute:

```bash
git add .
```

Prefer explicitly staging required files:

```bash
git add <file1> <file2> <file3>
```

If `git add .` is used, the staged diff MUST be reviewed before commit.

---

# 5. ALLOWED FILES TO PUSH — `v_mobile`

The following project source files are normally allowed to be committed when they are related to the task.

## 5.1 Python

```text
__manifest__.py
__init__.py
controllers/
models/
hooks.py
tests/
```

## 5.2 Odoo XML / Data / Security

```text
views/
data/
security/
```

## 5.3 Documentation / Configuration

```text
README.md
CHANGELOG.md
.gitignore
requirements.txt
```

Only commit files that are actually required by the current task.

---

# 6. FORBIDDEN FILES & DIRECTORIES

The following MUST NEVER be pushed to Git.

## 6.1 Odoo Enterprise / Local Environment Dependencies

```text
helpdesk/
helpdesk_sms/
spreadsheet_dashboard_helpdesk/
web_cohort/
```

These directories are environment-specific dependencies and MUST remain in `.gitignore`.

## 6.2 Generated / Cache Files

Never commit:

```text
__pycache__/
*.pyc
.DS_Store
```

Also avoid committing unnecessary generated build artifacts unless explicitly required by the repository.

## 6.3 Duplicate Module Structures

Never create duplicated module structures such as:

```text
mobile_api/mobile_api/
```

unless the existing project architecture explicitly requires that structure.

Do not create a second copy of an existing Odoo module under another directory.

---

# 7. `.gitignore` REQUIREMENTS

The repository MUST keep environment-specific and generated files ignored.

At minimum, verify that `.gitignore` protects:

```text
__pycache__/
*.pyc
.DS_Store

helpdesk/
helpdesk_sms/
spreadsheet_dashboard_helpdesk/
web_cohort/
```

Do not remove existing `.gitignore` rules unless the task explicitly requires it.

---

# 8. ANTIGRAVITY AUTOPILOT — DEV ENVIRONMENT

## 8.1 Pre-Flight Asset Audit

Before launching the development server, run:

```bash
python3 vcloud-orchestrator-v6.py clean
```

The `clean` operation MUST NOT delete or modify:

* Git-tracked source code
* User's uncommitted work
* Project source files
* Odoo Enterprise modules
* Environment configuration
* Secrets
* Signing credentials
* Flutter signing assets

The purpose of `clean` is limited to:

* Clearing development ports
* Cleaning safe temporary development state
* Auditing development assets
* Removing stale development processes when supported by the script

If the `clean` command would delete project files or user changes, STOP and ask for approval.

## 8.2 UI Reload

After completing a logical batch of UI changes, reload/restart the browser UI:

```bash
python3 vcloud-orchestrator-v6.py restart
```

Do NOT restart after every individual file modification.

Example:

```text
Modify login UI
Modify home UI
Modify shared widget
Modify theme

        ↓

Restart browser UI once
```

If a restart is specifically required to debug an issue, it may be performed earlier.

---

# 9. FLUTTER DEVELOPMENT RULES

When modifying Flutter code:

## 9.1 Preserve Architecture

* Follow existing project architecture.
* Reuse existing widgets, services, repositories, models, and utilities.
* Do not duplicate existing functionality.
* Avoid unnecessary state-management changes.
* Avoid unnecessary package additions.

## 9.2 Dependencies

Before adding a package:

1. Check whether the project already provides equivalent functionality.
2. Prefer existing dependencies.
3. Only add a new package when it materially improves or is required for the task.
4. Do not upgrade unrelated dependencies.

## 9.3 Generated Files

Do not manually edit generated Flutter files unless explicitly required.

Examples:

```text
*.g.dart
*.freezed.dart
GeneratedPluginRegistrant.*
```

When generated files must change, regenerate them using the project's standard generation process.

---

# 10. ODOO 17 DEVELOPMENT RULES

When modifying the Odoo backend:

* Follow Odoo 17 ORM conventions.
* Prefer ORM methods over direct SQL unless SQL is necessary.
* Respect access rights and record rules.
* Preserve existing API contracts unless the task explicitly requires a breaking change.
* Validate authentication and authorization.
* Avoid exposing sensitive fields through API responses.
* Reuse existing models and utilities.
* Do not duplicate existing business logic.
* Maintain compatibility with existing mobile clients whenever possible.

For API changes, consider:

```text
Authentication
Authorization
Input validation
ORM behavior
Error handling
Response format
Backward compatibility
Performance
Security
```

---

# 11. TESTING & VALIDATION

Before committing changes, perform all relevant validation.

## 11.1 Flutter

When Flutter code is modified, run the relevant:

```bash
flutter analyze
```

and:

```bash
flutter test
```

Run additional project-specific tests when available.

For iOS-related changes, perform the appropriate iOS build validation.

## 11.2 Odoo

When Odoo code is modified:

* Run relevant Odoo tests.
* Validate affected models.
* Validate controllers.
* Validate XML views.
* Validate security/access rules.
* Validate API responses.
* Check logs for errors.

## 11.3 UI Changes

For UI changes:

* Verify the affected screen.
* Verify navigation.
* Verify loading/error/empty states when applicable.
* Verify responsive behavior when applicable.
* Verify the UI after the required restart/reload.

## 11.4 Git Validation

Before commit:

```bash
git status
git diff
git diff --cached
```

Confirm:

* No secrets are staged.
* No generated junk is staged.
* No Enterprise local modules are staged.
* No unrelated files are staged.
* The requested changes are present.
* No accidental deletions are present.

---

# 12. iOS TESTFLIGHT & EXPORT COMPLIANCE

Every Flutter iOS project MUST explicitly declare its export-compliance status.

File:

```text
ios/Runner/Info.plist
```

## 12.1 Exempt Encryption

If the application only uses exempt encryption, include:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

This declaration helps App Store Connect/TestFlight determine the application's export-compliance status without requiring unnecessary manual verification.

## 12.2 Non-Exempt Encryption

If the application uses non-exempt encryption:

* DO NOT automatically set the value to `false`.
* Stop and require export-compliance review.
* Do not make a false compliance declaration simply to unblock TestFlight.

The value MUST reflect the actual encryption used by the application.

## 12.3 Verification

Before creating/uploading an iOS TestFlight build:

Verify:

```text
ios/Runner/Info.plist
```

contains the correct export-compliance declaration.

Also verify:

* Bundle identifier
* Version
* Build number
* Signing configuration
* Provisioning configuration
* Release configuration

---

# 13. TESTFLIGHT BUILD VERSIONING

For every TestFlight release:

Verify:

```text
CFBundleShortVersionString
CFBundleVersion
```

or the corresponding Flutter version configuration.

Ensure:

* The build number is incremented correctly.
* The uploaded build matches the intended commit.
* The correct bundle identifier is used.
* The correct signing configuration is used.

Never modify version/build numbers arbitrarily.

---

# 14. REVIEW PHASE

After implementation and validation, ALWAYS execute:

```text
/review
```

The review MUST happen before the final commit whenever possible.

## 14.1 Review Requirements

The review should check:

* Correctness
* Security
* Architecture
* Code quality
* Regression risk
* API compatibility
* Flutter/Odoo conventions
* Test coverage
* Git hygiene
* Unnecessary changes
* Performance concerns
* iOS/TestFlight configuration when applicable

## 14.2 Fix Review Findings

If `/review` identifies issues:

1. Fix the issues.
2. Re-run relevant tests.
3. Re-run `/review` if necessary.
4. Only continue to commit when the implementation is acceptable.

---

# 15. `walkthrough.md`

Every completed Mobile task MUST create or update:

```text
walkthrough.md
```

The file MUST summarize the completed work.

## Required Sections

```markdown
# Walkthrough

## Summary

Brief description of the task and final result.

## Changes

List the important changes made.

## Files Changed

List the important files/modules modified.

## Implementation Details

Explain important technical decisions.

## Testing

List tests and validation performed.

## Build Validation

Describe relevant build validation.

## Review

Summarize `/review` results.

## Known Limitations

List known limitations, if any.

## Follow-up

List optional future improvements, if any.
```

`walkthrough.md` must be kept concise and relevant to the current task.

---

# 16. COMMIT MESSAGE CONVENTION

Commit messages MUST be clear and follow Conventional Commit style.

Examples:

```text
fix(mobile_api): fix employee authentication
```

```text
feat(mobile_api): add employee notification endpoint
```

```text
fix(ios): add export compliance declaration
```

```text
docs: update mobile API walkthrough
```

```text
test(mobile_api): add authentication coverage
```

```text
refactor(mobile_api): simplify employee service
```

Preferred format:

```text
type(scope): description
```

Allowed types include:

```text
feat
fix
docs
test
refactor
chore
build
ci
```

Avoid vague commit messages such as:

```text
update
fix bug
change code
test
new version
```

---

# 17. COMMIT WORKFLOW

Before committing:

```bash
git status
git diff
```

Stage only required files.

Example:

```bash
git add <file1> <file2> <file3>
```

Then inspect:

```bash
git diff --cached
```

Only commit after confirming the staged diff is correct.

Commit using:

```bash
git commit -m "fix(mobile_api): <description>"
```

---

# 18. PUSH RULES

NEVER push directly to `17.0`.

Only push the feature/fix branch.

For a fix:

```bash
git push -u origin fix/<bug-name>
```

For a feature:

```bash
git push -u origin feature/<feature-name>
```

NEVER use:

```bash
git push origin 17.0
```

NEVER use force push unless explicitly authorized.

---

# 19. MERGE REQUEST

After a successful push, create a GitLab Merge Request.

Target branch:

```text
17.0
```

Source branch:

```text
fix/<name>
```

or:

```text
feature/<name>
```

## MR Description

The Merge Request should contain:

### Summary

What was changed.

### Technical Changes

Important implementation details.

### Testing

Tests performed and results.

### Build Validation

Relevant build results.

### Review

Whether `/review` was completed.

### Documentation

Mention:

```text
walkthrough.md
```

### Known Limitations

Mention any known limitations or follow-up work.

The Agent MUST NOT merge the MR automatically.

Wait for Sếp/Reviewer approval.

---

# 20. DEFINITION OF DONE

A Mobile task is considered DONE only when ALL applicable requirements are satisfied.

```text
[ ] Correct repository/project identified
[ ] Working tree inspected
[ ] Existing uncommitted work preserved
[ ] Latest 17.0 pulled using --ff-only
[ ] Correct fix/* or feature/* branch created
[ ] Only required files modified
[ ] No forbidden files added
[ ] No secrets exposed or committed
[ ] Flutter validation completed when applicable
[ ] Odoo validation completed when applicable
[ ] UI validation completed when applicable
[ ] iOS configuration validated when applicable
[ ] TestFlight export compliance validated when applicable
[ ] Build validation completed when applicable
[ ] /review executed
[ ] Review findings resolved
[ ] walkthrough.md created/updated
[ ] git status reviewed
[ ] git diff reviewed
[ ] git diff --cached reviewed
[ ] Commit message follows convention
[ ] Feature/fix branch pushed
[ ] Merge Request created
[ ] MR targets 17.0
[ ] Waiting for reviewer approval
```

A task MUST NOT be described as fully complete if critical applicable items above remain unfinished.

---

# 21. PRIORITY RULE

When two instructions conflict, follow this priority:

```text
1. User's explicit request
2. Safety / data preservation
3. Protected Git branch rules
4. Project architecture and existing conventions
5. This project-scoped workflow
6. Optimization / convenience
```

Never sacrifice data safety or Git integrity for convenience.

---

# 22. FINAL RESPONSE REQUIREMENTS

When reporting completion of a task, provide a concise summary containing:

```text
### Completed

- Main changes
- Tests performed
- Build status
- Review status
- walkthrough.md status
- Git branch
- Commit
- Push status
- Merge Request status
```

If something could not be completed, explicitly state:

```text
NOT COMPLETED
```

and explain why.

Never claim that:

* A build passed when it was not verified.
* A test passed when it was not run.
* A push succeeded when it was not verified.
* An MR was created when it was not verified.
* `/review` was completed when it was not executed.
* TestFlight is ready when the required validation has not been completed.
* A deployment succeeded when it was not confirmed.
