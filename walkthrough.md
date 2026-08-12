# Walkthrough: Fastlane + GitHub Actions / GitLab CI + Webhook Automation Setup

Replaced Codemagic with an open, zero-cost CI/CD pipeline powered by **Fastlane** (`https://fastlane.tools/`), **GitHub Actions**, **GitLab CI/CD**, and **Automated Webhooks** for building, signing, and deploying Flutter iOS (TestFlight) and Android releases.

---

## 🛠️ 1. Files Created & Configured

### 1. **Ruby & Fastlane Core Dependencies**
- **[Gemfile](file:///media/tanma/DATA/save/mobile/vclients/Gemfile)**:
  - Defines `fastlane` and `cocoapods` gem dependencies for deterministic build execution.

### 2. **Fastlane Pipeline Configuration**
- **[Fastfile](file:///media/tanma/DATA/save/mobile/vclients/fastlane/Fastfile)**:
  - `ios beta`: Builds signed `.ipa` via Flutter, extracts git commit message for TestFlight Release Notes ("What to Test"), uploads to TestFlight using App Store Connect API Key (`.p8`) or App Password, and dispatches real-time Webhook notifications.
  - `android beta`: Builds universal `.apk` and `.aab`, uploads to Google Play Console, and dispatches real-time Webhook notifications.
  - `lane :bump`: Automatically increments the build number (`+1`) in `pubspec.yaml` (e.g. `2.4.0+40` -> `2.4.0+41`).
  - `send_webhook`: Custom Ruby helper supporting Discord, Slack, Telegram, and custom HTTP POST Webhook endpoints.
- **[ios Appfile](file:///media/tanma/DATA/save/mobile/vclients/ios/fastlane/Appfile)**: Configured Bundle Identifier (`com.w360s.wcloudapp`), Apple ID (`tanmnn@360.org.vn`), and Team IDs.
- **[android Appfile](file:///media/tanma/DATA/save/mobile/vclients/android/fastlane/Appfile)**: Configured Android Package Name (`com.w360s.wcloudapp`).

### 3. **CI/CD Workflows**
- **[.github/workflows/deploy.yml](file:///media/tanma/DATA/save/mobile/vclients/.github/workflows/deploy.yml)**:
  - GitHub Actions pipeline running on `macos-latest` (iOS) and `ubuntu-latest` (Android).
  - Triggers automatically on push to `main`, `release/*`, `release/ios-appstore`, `release/android-playstore`, manual `workflow_dispatch`, or HTTP POST `repository_dispatch`.
- **[.gitlab-ci.yml](file:///media/tanma/DATA/save/mobile/vclients/.gitlab-ci.yml)**:
  - GitLab CI pipeline for native execution on GitLab repository `git@gitlab.com:360org_mobiles/vclients.git`.

### 4. **Documentation**
- **[docs/FASTLANE_CI_CD_GUIDE.md](file:///media/tanma/DATA/save/mobile/vclients/docs/FASTLANE_CI_CD_GUIDE.md)**: Complete guide covering Repository Secrets setup, Webhook triggers, App Store Connect API Key `.p8` usage, and local Fastlane CLI commands.

---

## 📊 2. Verification Checklist

| Requirement | Status |
| :--- | :--- |
| Replace Codemagic with Fastlane + GitHub Actions / GitLab CI | ✅ `COMPLETE` |
| Automated TestFlight Release Notes from Git Commit | ✅ `COMPLETE` |
| Auto-Bump Build Number (`lane :bump`) | ✅ `COMPLETE` |
| Webhook Notification Dispatch | ✅ `COMPLETE` |
| App Store Connect API Key (`.p8`) Support | ✅ `COMPLETE` |
| Fastlane `Gemfile` & `Fastfile` | ✅ `COMPLETE` |
| GitHub Actions Workflow (`.github/workflows/deploy.yml`) | ✅ `COMPLETE` |
| GitLab CI Configuration (`.gitlab-ci.yml`) | ✅ `COMPLETE` |
| Fastlane Setup & Maintenance Guide | ✅ `COMPLETE` |
| iOS Code Signing & App Store Export Options (`export_options.plist`) | ✅ `COMPLETE` |
| Fastlane TestFlight App-Specific Password Authentication | ✅ `COMPLETE` |

---

## 🔧 3. iOS Code Signing & TestFlight Pipeline Root Cause & Fix Details

### 1. **Root Cause Analysis**
- **Issue A (`No valid code signing certificates were found`):** Xcode on GitHub Actions macOS runner lacked local development signing certificates in Keychain.
- **Issue B (`No profiles for 'com.w360s.wcloudapp' were found`):** Without an explicit `export_options.plist`, `flutter build ipa --release` defaults to Development export mode instead of App Store / TestFlight distribution.
- **Issue C (`Could not find option 'app_specific_password'`):** Fastlane's `upload_to_testflight` action expects App Password credentials via the standard environment variable `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD`.

### 2. **Fixes Applied**
- **Created [ios/export_options.plist](file:///media/tanma/DATA/save/mobile/vclients/ios/export_options.plist):** Configured `method: app-store` and `teamID: 3J68D9JX79` for TestFlight / App Store Distribution.
- **Configured `DEVELOPMENT_TEAM` in [ios/Runner.xcodeproj/project.pbxproj](file:///media/tanma/DATA/save/mobile/vclients/ios/Runner.xcodeproj/project.pbxproj):** Added `DEVELOPMENT_TEAM = 3J68D9JX79;` and `CODE_SIGN_STYLE = Automatic;` for Debug and Release build configurations.
- **Updated [fastlane/Fastfile](file:///media/tanma/DATA/save/mobile/vclients/fastlane/Fastfile):**
  - Added `--export-options-plist=ios/export_options.plist` to `flutter build ipa`.
  - Set `ENV["FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD"] = app_pass` for TestFlight authentication.
  - Ensured `WEBHOOK_URL` is safely optional without causing pipeline failure when unconfigured.
- **Documented Troubleshooting Knowledgebase in [docs/FASTLANE_CI_CD_GUIDE.md](file:///media/tanma/DATA/save/mobile/vclients/docs/FASTLANE_CI_CD_GUIDE.md):** Recorded all 5 error patterns and resolutions for long-term project maintainability.
