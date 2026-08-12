# Walkthrough: Fastlane + GitHub Actions / GitLab CI + Webhook Automation Setup

Replaced Codemagic with an open, zero-cost CI/CD pipeline powered by **Fastlane** (`https://fastlane.tools/`), **GitHub Actions**, **GitLab CI/CD**, and **Automated Webhooks** for building, signing, and deploying Flutter iOS (TestFlight) and Android releases.

---

## 🛠️ 1. Files Created & Configured

### 1. **Ruby & Fastlane Core Dependencies**
- **[Gemfile](file:///media/tanma/DATA/save/mobile/vclients/Gemfile)**:
  - Defines `fastlane` and `cocoapods` gem dependencies for deterministic build execution.

### 2. **Fastlane Pipeline Configuration**
- **[Fastfile](file:///media/tanma/DATA/save/mobile/vclients/fastlane/Fastfile)**:
  - `ios beta`: Builds signed `.ipa` via Flutter, uploads to TestFlight using App Store Connect API Key (`.p8`) or App Password, and dispatches real-time Webhook notifications.
  - `android beta`: Builds universal `.apk` and `.aab`, uploads to Google Play Console, and dispatches real-time Webhook notifications.
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
| Webhook Notification Dispatch | ✅ `COMPLETE` |
| App Store Connect API Key (`.p8`) Support | ✅ `COMPLETE` |
| Fastlane `Gemfile` & `Fastfile` | ✅ `COMPLETE` |
| GitHub Actions Workflow (`.github/workflows/deploy.yml`) | ✅ `COMPLETE` |
| GitLab CI Configuration (`.gitlab-ci.yml`) | ✅ `COMPLETE` |
| Fastlane Setup & Maintenance Guide | ✅ `COMPLETE` |
