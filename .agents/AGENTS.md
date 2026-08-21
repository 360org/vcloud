# Instruction Authority

This file is the authoritative project-level instruction source for AI agents
working in this repository.

All AI agents must follow this file when performing repository work.

External knowledge sources, including NotebookLM, documentation, previous
walkthroughs, examples, or historical project notes, provide context and
technical knowledge but MUST NOT override this file.

When instructions conflict, follow this priority:

1. Explicit user instruction for the current task
2. This `AGENTS.md`
3. Project/tool-specific instructions and skills
4. External project knowledge sources such as NotebookLM
5. General best practices

NotebookLM may explain, recommend, or provide historical context, but it must
never be used to bypass Git protection, security requirements, destructive
operation restrictions, testing requirements, or other mandatory rules defined
in this file.
# Project-Scoped Rules for Mobile App & Odoo Backend

> [!IMPORTANT]
> These rules apply to all work performed in this repository. All AI agents must strictly follow these instructions.

---

# 1. 🛡️ Global Rules & Safety

## 1.1 Scope & Code Integrity

* Read and follow all rules in this document before modifying the project.
* Do not modify files unrelated to the requested task.
* Do not introduce arbitrary refactors, dependency upgrades, architecture changes, or formatting changes unless explicitly requested or required to complete the task.
* Preserve the existing project architecture, conventions, naming patterns, and folder structure.
* Prefer the smallest safe change that completely solves the requested problem.
* Do not rewrite working code unnecessarily.

---

## 1.2 Destructive Operations Protection

> [!CAUTION]
> NEVER execute destructive Git or system commands without explicit user authorization.

The following commands are forbidden unless explicitly authorized:

```bash
git reset --hard
git clean -fd
git clean -fdx
git restore <file>
git checkout -- <file>
git push --force
git push --force-with-lease
rm -rf <directory>
```

Rules:

* Never delete user-created files without explicit approval.
* Never discard uncommitted work.
* Never automatically stash user changes.
* Never automatically reset the repository.
* Never automatically clean the working tree.
* Never overwrite unrelated user changes.
* Never use force push unless explicitly authorized.
* Never use destructive commands merely to make Git status clean.

---

## 1.3 Credentials & Secrets Security

> [!WARNING]
> NEVER commit, expose, print, or upload secrets.

Never commit or expose:

* API keys
* Access tokens
* Passwords
* Private keys
* Signing certificates
* Provisioning profiles
* `.env` files containing secrets
* Production credentials
* Cloud credentials
* Git credentials
* Service account credentials

If a task requires unavailable credentials, stop and ask the user.

---

# 2. 📱 Mobile Project Workflow Enforcement

When working on the Mobile project, automatically trigger and apply the appropriate development skill.

| Sub-System                | Required Skill        | Purpose                                                                         |
| :------------------------ | :-------------------- | :------------------------------------------------------------------------------ |
| **Frontend — Flutter**    | `dev-workflow-skills` | Flutter architecture, Riverpod, UI standards, testing, and development workflow |
| **Backend — Odoo 17 API** | `odoo-development`    | Odoo 17 ORM, controllers, security, views, APIs, and Python standards           |

## 2.1 Flutter

When modifying Flutter code:

* Follow the existing Flutter architecture.
* Follow existing Riverpod/state-management conventions.
* Reuse existing widgets, services, repositories, utilities, and models.
* Do not add packages unless required.
* Do not upgrade unrelated dependencies.
* Do not manually modify generated files unless required.

## 2.2 Odoo 17

When modifying Odoo 17:

* Follow Odoo 17 ORM conventions.
* Respect access rights and record rules.
* Respect existing controllers, models, views, and security architecture.
* Prefer ORM over raw SQL unless SQL is necessary.
* Preserve existing API contracts when possible.
* Validate authentication and authorization.
* Do not expose sensitive information through API responses.
* Avoid duplicating existing business logic.

---

# 3. 🌿 Git Branching & Push Policy

## 3.1 Branch Summary

| Branch                     | Purpose                                     | Direct Push | Merge Strategy                    |
| :------------------------- | :------------------------------------------ | :---------: | :-------------------------------- |
| **`17.0`**                 | Protected Odoo 17 production/staging branch | ❌ **NEVER** | Merge Request + Reviewer approval |
| **`fix/*`**                | Bug fixes and maintenance                   |    ✅ Yes    | Merge Request → `17.0`            |
| **`feature/*`**            | New features and enhancements               |    ✅ Yes    | Merge Request → `17.0`            |
| **`release/ios-appstore`** | iOS App Store / TestFlight release workflow |  ✅ **Yes**  | Direct Push / Codemagic           |

---

## 3.2 Protected Branch — `17.0`

`17.0` is the protected production/staging branch for the Odoo 17 API.

### Direct Push Forbidden

NEVER execute:

```bash
git push origin 17.0
```

The AI agent MUST NOT push directly to `17.0`.

### Standard Workflow

```text
17.0
  ↓
git pull --ff-only
  ↓
Create fix/* or feature/*
  ↓
Develop
  ↓
Test / Validate
  ↓
Execute /review
  ↓
Update walkthrough.md
  ↓
Commit
  ↓
Push working branch
  ↓
Create GitLab Merge Request
  ↓
Sếp / Reviewer reviews
  ↓
Reviewer merges into 17.0
```

The AI agent MUST NOT merge the Merge Request automatically unless explicitly instructed by the user.

---

## 3.3 Bug-Fix Branches — `fix/*`

Use `fix/*` for:

* Bug fixes
* Regression fixes
* Maintenance
* Small corrections
* Non-release-specific configuration fixes

Examples:

```text
fix/mobile-login
fix/employee-api
fix/odoo-authentication
fix/flutter-navigation
```

Create from the latest `17.0`:

```bash
git checkout 17.0
git pull --ff-only origin 17.0
git checkout -b fix/<name>
```

Push:

```bash
git push -u origin fix/<name>
```

Then create a Merge Request targeting:

```text
17.0
```

---

## 3.4 Feature Branches — `feature/*`

Use `feature/*` for:

* New features
* New API endpoints
* New Flutter screens
* New Odoo functionality
* Major enhancements
* New integrations

Examples:

```text
feature/mobile-notification
feature/employee-management
feature/mobile-dashboard
feature/push-notification
```

Create from the latest `17.0`:

```bash
git checkout 17.0
git pull --ff-only origin 17.0
git checkout -b feature/<name>
```

Push:

```bash
git push -u origin feature/<name>
```

Then create a Merge Request targeting:

```text
17.0
```

---

# 4. 📱 Approved iOS Release Branch — `release/ios-appstore`

`release/ios-appstore` is an officially approved release branch.

Direct push to this branch is explicitly allowed.

## 4.1 Allowed Scope

Use `release/ios-appstore` ONLY for iOS release-related work, including:

* Flutter iOS release builds
* TestFlight releases
* App Store releases
* iOS build configuration
* iOS version/build number changes
* `ios/Runner/Info.plist`
* Export Compliance configuration
* iOS signing/release configuration
* Codemagic iOS configuration
* iOS-specific release fixes
* App Store Connect preparation

## 4.2 Direct Push Allowed

The following workflow is valid:

```text
release/ios-appstore
  ↓
Release Development / Fix
  ↓
Testing / Validation
  ↓
Execute /review
  ↓
Update walkthrough.md
  ↓
Commit
  ↓
Push directly to release/ios-appstore
  ↓
Codemagic
  ↓
App Store Connect / TestFlight
```

Allowed:

```bash
git checkout release/ios-appstore
git pull --ff-only origin release/ios-appstore
git add <required-files>
git commit -m "fix(ios): <description>"
git push origin release/ios-appstore
```

## 4.3 Merge Request Exception

A Merge Request is **NOT required** for changes intentionally made directly to:

```text
release/ios-appstore
```

unless the user explicitly requests an MR.

## 4.4 Scope Restriction

DO NOT use `release/ios-appstore` for unrelated:

* Odoo backend development
* General Flutter features
* Experimental features
* General refactoring
* Unrelated UI changes
* Temporary debugging
* New Odoo API functionality

For those tasks, use:

```text
fix/*
```

or:

```text
feature/*
```

---

# 5. 🔍 Git Pre-Flight

Before starting development work, ALWAYS run:

```bash
git status --short
git branch --show-current
```

## 5.1 Dirty Working Tree

If there are uncommitted changes:

* Do NOT reset them.
* Do NOT discard them.
* Do NOT automatically stash them.
* Do NOT run `git clean`.
* Do NOT overwrite them.

Determine whether the changes belong to the current task.

If it is unclear whether the existing changes belong to the current task:

> STOP and ask the user before modifying them.

---

# 6. 🔄 Updating Base Branches

## 6.1 Normal Development

For `fix/*` or `feature/*` tasks:

```bash
git checkout 17.0
git pull --ff-only origin 17.0
```

Then create the working branch:

```bash
git checkout -b fix/<name>
```

or:

```bash
git checkout -b feature/<name>
```

Never create automatic merge commits when updating `17.0`.

---

## 6.2 iOS Release Development

For iOS release tasks:

```bash
git checkout release/ios-appstore
git pull --ff-only origin release/ios-appstore
```

Before modifying the branch:

```bash
git status --short
git branch --show-current
```

Do not switch branches if doing so could overwrite uncommitted work.

---

# 7. 🔎 Pre-Commit Git Verification

Before EVERY commit, run:

```bash
git branch --show-current
git status
git diff
```

Before committing staged files, run:

```bash
git diff --cached
```

Verify:

* No unrelated files are staged.
* No secrets are staged.
* No credentials are staged.
* No forbidden directories are staged.
* No generated cache files are staged.
* No user changes unrelated to the task are included.
* No accidental file deletions are included.
* The staged diff contains only the intended changes.

Do not blindly commit without inspecting the staged diff.

---

# 8. 📦 File Push Constraints

## 8.1 Allowed Source Files

Normally allowed when required by the task:

### Odoo / Python

```text
__manifest__.py
__init__.py
controllers/
models/
hooks.py
tests/
```

### Odoo Views / Data / Security

```text
views/
data/
security/
```

### Flutter

```text
lib/
pubspec.yaml
ios/
android/
```

### Documentation / Configuration

```text
README.md
CHANGELOG.md
.gitignore
requirements.txt
```

Only commit files actually required by the current task.

---

# 9. 🚫 Forbidden Files & Directories

NEVER commit or push:

## 9.1 Odoo Enterprise Local Directories

```text
helpdesk/
helpdesk_sms/
spreadsheet_dashboard_helpdesk/
web_cohort/
```

These directories MUST remain ignored by `.gitignore`.

## 9.2 Generated / Cache Files

Never commit:

```text
__pycache__/
*.pyc
.DS_Store
```

Also avoid committing unnecessary generated build artifacts unless explicitly required by the repository.

## 9.3 Duplicate Module Structures

Never create duplicate structures such as:

```text
mobile_api/mobile_api/
```

unless explicitly required by the existing project architecture.

---

# 10. 📝 `.gitignore` Requirements

The repository MUST protect environment-specific and generated files.

At minimum verify that `.gitignore` contains appropriate rules for:

```text
__pycache__/
*.pyc
.DS_Store

helpdesk/
helpdesk_sms/
spreadsheet_dashboard_helpdesk/
web_cohort/
```

Do not remove existing `.gitignore` rules unless explicitly required.

---

# 11. 📱 Flutter Development Rules

When modifying Flutter:

* Preserve the existing architecture.
* Follow the existing Riverpod/state-management approach.
* Reuse existing components.
* Avoid duplicated functionality.
* Avoid unnecessary package additions.
* Avoid unrelated dependency upgrades.
* Preserve existing API contracts.
* Preserve existing navigation patterns.
* Preserve existing error/loading/empty-state patterns.

Generated files should not be manually modified unless explicitly required.

Examples:

```text
*.g.dart
*.freezed.dart
GeneratedPluginRegistrant.*
```

When generated files must change, use the project's normal generation process.

---

# 12. ⚙️ Odoo 17 Development Rules

When modifying Odoo:

* Follow Odoo 17 ORM conventions.
* Respect access rights.
* Respect record rules.
* Validate authentication and authorization.
* Validate API input.
* Validate API output.
* Preserve backward compatibility where possible.
* Avoid unnecessary raw SQL.
* Reuse existing business logic.
* Do not duplicate existing models or services.
* Do not expose sensitive fields through APIs.

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

# 13. 🚀 Antigravity Autopilot Rules

## 13.1 Pre-Flight Asset Audit

Before launching the development server, run:

```bash
python3 vcloud-orchestrator-v6.py clean
```

The `clean` command MUST NOT delete or modify:

* Git-tracked source code
* Uncommitted user changes
* Project source files
* Odoo Enterprise dependencies
* Environment configuration
* Secrets
* Signing credentials
* Flutter signing assets

If `clean` would affect source code or user work:

> STOP and ask for explicit approval.

---

## 13.2 Post-UI Change Reload

After completing a logical batch of UI changes:

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
Restart once
```

---

# 14. 🌐 Browser Automation Policy

Browser automation and UI restart are different operations.

The command:

```bash
python3 vcloud-orchestrator-v6.py restart
```

does NOT grant permission to launch browser automation.

Unless explicitly requested by the user, the AI agent MUST NOT automatically launch:

* `browsermcp`
* Playwright
* `playwright-cli`
* Chromium automation
* Selenium
* Other browser automation tools

Browser automation is allowed only when the user explicitly requests it, for example:

```text
sử dụng trình duyệt ngầm
```

or:

```text
chạy Playwright tự động
```

If browser automation is not requested, use manual Visual QA instructions instead.

---

# 15. 👁️ Visual QA Rules

When modifying UI, including:

* Flutter UI
* Odoo XML views
* Odoo Web UI
* Mobile screens
* Layouts
* Forms
* Buttons
* Navigation
* Dialogs
* Visual styling

the AI agent MUST provide a Visual QA Checklist.

The checklist should contain:

| Test ID | UI Component      | File / Location | Expected Behavior    | Manual Test              |
| :------ | :---------------- | :-------------- | :------------------- | :----------------------- |
| VQA-001 | Example component | `path/to/file`  | Expected UI behavior | Manual verification step |

The checklist should help the user test the UI manually through the available UI inspection method, such as Gemini Chrome Side Panel.

### Important

The AI agent MUST NOT claim:

```text
PASS
```

unless the UI was actually verified by the user or by an authorized automated browser test.

If not verified, use:

```text
PENDING USER VERIFICATION
```

Do not automatically launch browser automation to obtain a PASS result.

---

# 16. 🧪 Testing & Validation

Every relevant task MUST run appropriate validation.

## 16.1 Flutter

When Flutter code is modified, run when applicable:

```bash
flutter analyze
flutter test
```

Run additional project-specific tests when available.

## 16.2 Odoo

When Odoo code is modified:

* Run relevant Odoo tests.
* Validate affected models.
* Validate controllers.
* Validate XML views.
* Validate security/access rules.
* Validate API responses.
* Check application logs.

## 16.3 UI

For UI changes:

* Verify affected screen.
* Verify navigation.
* Verify loading state.
* Verify error state.
* Verify empty state.
* Verify responsive behavior when applicable.
* Perform Visual QA.

## 16.4 Build

When release/build configuration changes:

* Run the appropriate build validation.
* Verify the build result.
* Do not claim a successful build unless it was actually verified.

---

# 17. 🍎 iOS Build & TestFlight Rules

## 17.1 Export Compliance

Every Flutter iOS project MUST explicitly declare its export-compliance status in:

```text
ios/Runner/Info.plist
```

If the application only uses exempt encryption, it MUST contain:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

If the application uses non-exempt encryption:

* Do NOT automatically set the value to `false`.
* Stop and request an export-compliance review.
* Never make a false compliance declaration just to unblock TestFlight.

The declaration MUST reflect the actual encryption used by the application.

---

## 17.2 Version & Build Number

Flutter versioning follows:

```text
X.Y.Z+BUILD
```

Example:

```yaml
version: 2.4.0+31
```

Rules:

* Never decrement a release build number.
* Never reuse an existing TestFlight build number.
* Increment the build number for every new upload.
* Keep the version number consistent with the intended release.
* Verify the bundle identifier before release.
* Verify signing configuration before release.

---

# 18. 🧩 Codemagic / TestFlight Release

For iOS release tasks on:

```text
release/ios-appstore
```

verify as applicable:

* Flutter version
* iOS version
* Build number
* Bundle identifier
* `Info.plist`
* Export compliance
* Signing configuration
* Provisioning configuration
* Codemagic configuration
* Release build result
* App Store Connect upload result

Never claim that TestFlight is ready unless the relevant build/upload status was verified.

---

# 19. 🔍 Review & Documentation Workflow

Every Mobile development task MUST follow:

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
Update walkthrough.md
    ↓
Git Verification
    ↓
Commit
    ↓
Push
```

## 19.1 `/review`

The `/review` phase MUST be executed before declaring the task complete.

Review:

* Correctness
* Security
* Architecture
* Code quality
* Regression risk
* API compatibility
* Flutter/Odoo conventions
* Test coverage
* Git hygiene
* Performance
* iOS/TestFlight configuration when applicable

If `/review` finds problems:

1. Fix the issues.
2. Re-run relevant tests.
3. Re-run `/review` when necessary.
4. Continue only when the implementation is acceptable.

---

# 20. 📚 `walkthrough.md` — Per-Task Documentation

`walkthrough.md` is a **historical project walkthrough and verification log**.

It is NOT a persistent Definition of Done checklist.

Existing content in `walkthrough.md` represents previous tasks and MUST NOT be treated as evidence that the CURRENT task has been completed.

---

## 20.1 Every Task Requires a Current Entry

For every completed Mobile development task, the AI agent MUST create or update `walkthrough.md` with a **new entry for the CURRENT task**.

Do NOT simply verify that `walkthrough.md` already exists.

Do NOT mark the current task complete because previous entries exist.

Do NOT overwrite previous task history unless explicitly requested.

The current task MUST have its own:

* Task description
* Date
* Changes
* Files affected
* Tests / validation
* Build validation when applicable
* `/review` result
* Visual QA result when applicable
* Git information when applicable
* Known limitations when applicable

---

## 20.2 Append / Update, Do Not Reset History

When `walkthrough.md` already contains previous tasks:

```text
Previous Task
Previous Task
Previous Task
        ↓
CURRENT TASK
```

The AI agent MUST preserve the previous entries.

Normally, add the newest task entry at the top or bottom according to the existing project convention.

Never delete previous verification history merely because a new task has started.

---

## 20.3 Current Task Must Be Independently Verified

Previous entries such as:

```text
flutter analyze: PASS
flutter test: PASS
/review: PASS
Build: PASS
```

refer ONLY to the task in which those results were recorded.

They MUST NOT be reused as evidence for a new task.

For example:

```text
Task A:
flutter test → PASS
```

does NOT mean:

```text
Task B:
flutter test → PASS
```

Task B must be tested independently when testing is applicable.

---

## 20.4 Recommended Current Task Format

When adding a new entry, use:

```markdown
## [CURRENT DATE] — <Task Name>

### 🎯 Task

Brief description of the current task.

### 🔧 Changes

- Change 1
- Change 2
- Change 3

### 📁 Files Changed

- `path/to/file1`
- `path/to/file2`

### 🧪 Testing & Validation

- `flutter analyze`: PASS / FAIL / NOT RUN
- `flutter test`: PASS / FAIL / NOT RUN
- Odoo tests: PASS / FAIL / NOT RUN
- Build: PASS / FAIL / NOT RUN

### 🔍 Review

- `/review`: PASS / FINDINGS / NOT RUN
- Review findings:
- Resolution:

### 👁️ Visual QA

- VQA-001: PASS / FAIL / PENDING USER VERIFICATION

### 🍎 iOS / TestFlight

Only include when applicable:

- Version:
- Build number:
- Export compliance:
- Codemagic:
- TestFlight:

### 🌿 Git

- Branch:
- Commit:
- Push:
- Merge Request:

### ⚠️ Known Limitations

- None / describe limitations

### 📌 Follow-up

- None / describe follow-up work
```

---

## 20.5 No False Verification

The AI agent MUST NOT copy previous results into the CURRENT task entry.

For example, if the previous task had:

```text
flutter test: PASS 62/62
```

and the current task has not run tests yet, the current entry MUST say:

```text
flutter test: NOT RUN
```

It MUST NOT say:

```text
flutter test: PASS 62/62
```

unless the current task actually ran and produced that result.

---

## 20.6 Definition of Done vs Walkthrough

These two files/concepts have different purposes:

### `AGENTS.md`

Defines:

```text
RULES
REQUIREMENTS
WORKFLOW
SAFETY POLICIES
```

It does NOT store task completion state.

### `walkthrough.md`

Stores:

```text
HISTORICAL TASKS
CHANGES
TEST RESULTS
REVIEW RESULTS
BUILD RESULTS
GIT HISTORY
VERIFICATION RESULTS
```

It records what actually happened for each task.

Therefore:

```text
AGENTS.md = What MUST be done
walkthrough.md = What WAS done
```

Previous entries in `walkthrough.md` MUST NEVER be treated as completion of a new task.

---

# 21. 📝 Commit Convention

Commit messages MUST follow Conventional Commit style.

Preferred format:

```text
type(scope): description
```

Allowed types:

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

Examples:

```bash
git commit -m "fix(mobile_api): fix employee authentication"
```

```bash
git commit -m "feat(mobile): add push notification"
```

```bash
git commit -m "fix(ios): update export compliance configuration"
```

```bash
git commit -m "docs: update AGENTS rules"
```

Avoid vague messages:

```text
update
fix
change
test
new version
```

---

# 22. 📤 Push Rules

## 22.1 Normal Development

For:

```text
fix/*
feature/*
```

workflow:

```text
Commit
  ↓
Push branch
  ↓
Create MR
  ↓
Target 17.0
  ↓
Reviewer approval
```

Push:

```bash
git push -u origin fix/<name>
```

or:

```bash
git push -u origin feature/<name>
```

---

## 22.2 iOS Release

For:

```text
release/ios-appstore
```

direct push is allowed:

```bash
git push origin release/ios-appstore
```

No MR is required unless explicitly requested.

---

## 22.3 Protected Branch

For:

```text
17.0
```

direct push is NEVER allowed.

---

# 23. 🛡️ Rule Enforcement

Before executing any Git operation that changes branches, commits, or remote repositories, the AI agent MUST verify that the operation complies with these rules.

If an action conflicts with these rules:

1. STOP before executing the conflicting action.
2. Explain which rule would be violated.
3. Ask for explicit user confirmation.
4. Do not silently override or reinterpret the rule.

The AI agent MUST NOT silently switch branches.

The AI agent MUST NOT claim an operation succeeded unless the result was actually verified.

The AI agent MUST NOT claim:

* Tests passed unless tests were actually run.
* Build succeeded unless the build result was verified.
* Push succeeded unless the push result was verified.
* Merge Request was created unless its creation was verified.
* `/review` was completed unless `/review` was actually executed.
* Visual QA passed unless the UI was actually verified.
* TestFlight is available unless the uploaded build was verified.
* Deployment succeeded unless deployment was actually verified.

---

24. ✅ Definition of Done — Per Task

The Definition of Done is a per-task checklist.

These checks MUST be evaluated from scratch for EVERY task.

Previous task completion MUST NOT be reused as evidence for the current task.

The AI agent MUST NOT assume that an item is complete because:

It was completed in a previous task.
It was checked in a previous conversation.
It appears as completed in an existing document.
The repository was previously in a valid state.
A previous build or review passed.
A previous walkthrough.md already exists.

For EVERY new task, independently verify all applicable requirements.

24.1 Required Per-Task Checks

Before declaring the CURRENT task complete, verify:

Correct repository/project identified.
Current Git branch verified.
Working tree inspected.
Existing user changes preserved.
Correct base branch synchronized when required.
Correct working branch selected.
Only required files modified.
No secrets or credentials exposed.
No forbidden files staged.
No generated cache files staged.
Flutter validation completed when Flutter code was changed.
Odoo validation completed when Odoo code was changed.
UI validation completed when UI was changed.
Visual QA checklist provided when UI was changed.
iOS Info.plist export compliance verified when applicable.
iOS version/build number verified when applicable.
Build validation completed when applicable.
/review executed.
Review findings resolved.
Relevant tests re-run after review when applicable.
walkthrough.md created or updated for the CURRENT task.
git status reviewed.
git diff reviewed.
git diff --cached reviewed before commit.
Commit message follows Conventional Commits.
Correct branch verified immediately before push.
Normal development pushed to fix/* or feature/*.
iOS release work pushed to release/ios-appstore when applicable.
17.0 was NOT directly pushed.
Merge Request created for fix/* or feature/* when applicable.
Merge Request is NOT required for release/ios-appstore unless explicitly requested.
24.2 Task-Specific State

The AI agent MUST evaluate the checklist against the CURRENT task only.

For example:

Task A:
Flutter UI changed
→ Run Flutter validation
→ Run /review
→ Update walkthrough.md
→ Verify Git
→ Commit
→ Push

Later:

Task B:
Odoo API changed
→ Run Odoo validation
→ Run /review
→ Update walkthrough.md
→ Verify Git again
→ Commit
→ Push

The successful completion of Task A MUST NOT be treated as completion of Task B.

24.3 No Persistent Completion State

Do NOT store task completion state in AGENTS.md.

Do NOT change these rules from:

[ ] → [x]

after completing a task.

AGENTS.md defines requirements, not the completion status of a specific task.

The completion status belongs to the current task's:

terminal output
test results
walkthrough.md
Git diff
commit
build result
review result
24.4 Final Verification

Before reporting the task as complete, the AI agent MUST perform a fresh verification pass for the CURRENT task.

The agent should explicitly distinguish:

VERIFIED THIS TASK

from:

KNOWN FROM PREVIOUS TASK

Previous evidence may provide context, but MUST NOT replace current verification when the requirement is applicable to the current task.
---

# 25. 📊 Final Task Report

When reporting completion, provide a concise summary:

```text
### Completed

- Main changes:
- Files changed:
- Tests:
- Build:
- Review:
- Visual QA:
- walkthrough.md:
- Git branch:
- Commit:
- Push:
- Merge Request:
```

If something could not be completed, explicitly state:

```text
NOT COMPLETED
```

and explain why.

Never hide incomplete validation or failed steps.
