# Project-Scoped Rules for Mobile App & Odoo Backend

> [!IMPORTANT]
> These rules apply to all work performed in this repository. All AI agents must strictly follow these instructions without exception.

---

## 1. 🛡️ Global Rules & Safety

### 1.1 Scope & Code Integrity
- **Follow Guidelines**: Read and follow all rules in this document before modifying the project.
- **Minimal Scope**: Do not modify files unrelated to the requested task.
- **No Unnecessary Refactoring**: Do not introduce arbitrary refactors, package updates, architecture changes, or style formatting changes unless explicitly requested.
- **Preserve Existing Architecture**: Respect established project structures, conventions, and naming patterns.

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

## 2. 📱 Mobile Project Workflow Enforcement

When working on the Mobile project, automatically trigger and apply the required skills:

| Sub-System | Required Skill | Description |
| :--- | :--- | :--- |
| **Frontend (Flutter)** | `dev-workflow-skills` | Enforces Flutter Clean Architecture, Riverpod state management, and mobile UI standards. |
| **Backend (Odoo 17 API)** | `odoo-development` | Enforces Odoo 17 ORM, controllers, security rules, views, and Python standards. |

---

## 3. 🌿 Git Branching & Push Policy

### 3.1 Branch Summary Table

| Branch | Purpose | Direct Push Allowed? | Merge Strategy |
| :--- | :--- | :---: | :--- |
| **`17.0`** | Protected Production / Staging branch (Odoo 17 API) | ❌ **NEVER** | Requires Merge Request (MR) + Approval |
| **`fix/*`** | Bug fixes & maintenance | ✅ Yes | Merge Request to `17.0` |
| **`feature/*`** | New features & enhancements | ✅ Yes | Merge Request to `17.0` |
| **`release/ios-appstore`** | iOS App Store & TestFlight release builds | ✅ **Yes** | Direct Push / Codemagic Pipeline |

### 3.2 Protected Branch Rule (`17.0`)
- ❌ **Direct Push Forbidden**: `git push origin 17.0` is strictly blocked.
- ✅ **Standard Workflow**:
  ```text
  17.0 (pull --ff-only)
    └──> Create fix/* or feature/* branch
          └──> Develop & Test
                └──> Execute /review & update walkthrough.md
                      └──> Commit & Push working branch
                            └──> Create GitLab Merge Request (MR) -> Sếp/Reviewer Merges
  ```

### 3.3 Approved iOS Release Branch (`release/ios-appstore`)
- ✅ **Direct Push Allowed**: `git push origin release/ios-appstore` is explicitly permitted for iOS App Store and TestFlight workflows (Info.plist fixes, build version bumps, iOS release configs, Codemagic integration).
- ⚠️ **Scope Restriction**: Do NOT use `release/ios-appstore` for general Odoo backend features or unrelated Flutter development.

---

## 4. 🚫 File Push Constraints & Security

### 4.1 Allowed Files to Commit (`v_mobile` / `vclients`)
- ✅ **Python Modules**: `__manifest__.py`, `__init__.py`, `controllers/`, `models/`, `hooks.py`, `tests/`
- ✅ **Odoo Views & Security**: `views/`, `data/`, `security/`
- ✅ **Flutter Frontend**: `lib/`, `pubspec.yaml`, `ios/`, `android/`
- ✅ **Project Documentation**: `README.md`, `CHANGELOG.md`, `.gitignore`, `requirements.txt`

### 4.2 Forbidden Files & Directories (Strictly Ignored)
- 🚫 **Odoo Enterprise Local Directories**: `helpdesk/`, `helpdesk_sms/`, `spreadsheet_dashboard_helpdesk/`, `web_cohort/` *(Must remain in `.gitignore`)*.
- 🚫 **Bytecode & Build Cache**: `__pycache__/`, `*.pyc`, `.DS_Store`, build build artifacts.
- 🚫 **Nested Duplicate Directories**: Avoid creating duplicate nested directories like `mobile_api/mobile_api/`.

---

## 5. 📱 iOS Build & TestFlight Enforcement Rules

### 5.1 Mandatory Export Compliance Key
Every Flutter iOS project (`vclients/ios/Runner/Info.plist`) **MUST** contain the following key to prevent TestFlight builds from getting stuck in "Missing Export Compliance":

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

> [!TIP]
> **Rationale**: Including this key automates TestFlight export compliance verification, preventing App Store Connect from blocking distribution to internal and external testing groups.

### 5.2 Versioning & Build Numbers
- Version string in `pubspec.yaml` follows `X.Y.Z+BUILD` format (e.g., `version: 2.4.0+31`).
- Never decrement or reuse an existing build number when uploading to TestFlight.

---

## 6. 🚀 Antigravity Autopilot Execution Rules

- **Pre-Flight Asset Audit**: Clear development ports and audit assets before launching dev server:
  ```bash
  python3 vcloud-orchestrator-v6.py clean
  ```
- **Post-Build UI Reload**: Reload browser UI after completing a logical batch of UI edits:
  ```bash
  python3 vcloud-orchestrator-v6.py restart
  ```

---

## 7. 🔍 Testing, Review & Documentation Workflow

Every mobile development task MUST follow this completion cycle:

```text
Implementation ──> Tests / Validation ──> Execute /review ──> Update walkthrough.md ──> Git Commit & Push
```

1. **Code Validation**: Run `flutter analyze` / `flutter test` or Odoo test suites.
2. **Review Phase**: Execute `/review` phase to audit code quality, security, and standards.
3. **Artifact Summary**: Create or update `walkthrough.md` summarizing changes, test results, and verification steps.

---

## 8. 📋 Definition of Done Checklist

Before marking any task as complete, verify:
- [x] Code adheres to Clean Architecture and project standards.
- [x] Tested locally without runtime errors or crashes.
- [x] iOS `Info.plist` contains `ITSAppUsesNonExemptEncryption` set to `false`.
- [x] `/review` phase completed and findings resolved.
- [x] `walkthrough.md` updated in artifact directory.
- [x] Git commits use Conventional Commit messages (`fix(...)`, `feat(...)`, `docs(...)`, `bump(...)`).
- [x] Pushed to correct branch (`fix/*`, `feature/*`, or `release/ios-appstore`).
