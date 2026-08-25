# Báo cáo audit kỹ thuật VCloud

## Cập nhật sau audit — 2026-08-25

- Đã đồng bộ số build trên `main` lên `2.5.0+92` theo tag mới nhất đã fetch.
- Giữ iOS bundle `com.w360s.wcloudapp`; giữ Android package `com.vcloud.vcloud`.
- Đã sửa default Firebase iOS bundle sang `com.w360s.wcloudapp` để giảm rủi ro Push Notification/APNs mismatch khi thiếu dart-define.
- Đã ignore `.claude/aiac/sessions/` để cache phiên AIaC không lọt vào commit.
- Chưa merge toàn bộ `github/release/ios-appstore` vào `main` vì dự báo có conflict; cần task riêng nếu muốn kéo đủ code Build 82–92.

## Phiên bản audit gốc: `v2.5.0+81` — Ngày kiểm toán: 2026-08-24

Phạm vi: Flutter mobile app, CI/CD GitHub/GitLab/Codemagic, Fastlane iOS/Android, tài liệu release và repo hygiene.

---

## 1. Trạng thái release

| Hạng mục | Kết quả |
| --- | --- |
| Git local | Sạch sau release `e5154de` trước audit fix |
| GitLab `origin/main` | Đã đồng bộ `e5154de` trước audit fix |
| GitHub `github/main` | Đã đồng bộ `e5154de` trước audit fix |
| Tag | `v2.5.0+81` đã tồn tại trên GitLab và GitHub |
| GitHub Release | Đã tạo `v2.5.0+81` |
| GitLab Release | Đã tạo `v2.5.0+81` |
| Version app | `pubspec.yaml` = `2.5.0+81` |

---

## 2. Kiểm tra đã chạy

| Kiểm tra | Kết quả |
| --- | --- |
| High-confidence secret scan | PASS — không thấy private key/token/API key/JWT thật |
| `.claude/` secret scan | PASS |
| Git refs GitLab/GitHub | PASS — `main` và tag đã sync trước audit fix |
| GitHub Actions release run | Đang chạy tại thời điểm audit; iOS đã PASS `flutter analyze` + `flutter test` |
| GitLab pipeline | Đang chạy trên `main` tại thời điểm audit do `.gitlab-ci.yml` còn trigger `main` |
| Flutter local | BLOCKED — máy phiên này không có `/Volumes/DATA/DEV/flutter`, `flutter`, `dart`, `fvm` |

---

## 3. Lỗi audit đã phát hiện và xử lý

### 3.1 CI GitLab/Codemagic vẫn build release khi push `main` — ĐÃ SỬA

**Mức độ:** HIGH
**File:** `.gitlab-ci.yml`, `codemagic.yaml`

**Bằng chứng trước sửa:**
- `.gitlab-ci.yml` có `only: main` cho `flutter_test` và `deploy_android`.
- `codemagic.yaml` có `branch_patterns: main` cho iOS TestFlight và Android Release.
- GitLab pipeline `#153` chạy trên `main` sau khi push release.

**Sửa:**
- Gỡ `main` khỏi trigger release/test GitLab trong `.gitlab-ci.yml`.
- Gỡ `main` khỏi trigger iOS/Android Codemagic trong `codemagic.yaml`.

**Lý do:** chính sách VCloud: push/merge `main` chỉ lưu source, không tự build release; release chạy bằng tag `v*`, branch release hoặc manual/web trigger.

### 3.2 Android package upload sai ID — ĐÃ SỬA

**Mức độ:** HIGH
**File:** `fastlane/Fastfile`, `codemagic.yaml`, `android/app/build.gradle.kts`

**Bằng chứng trước sửa:**
- Android app thật dùng `applicationId = "com.vcloud.vcloud"`.
- Fastlane Android upload dùng `package_name: "com.w360s.wcloudapp"`.
- Codemagic Android `PACKAGE_NAME: com.w360s.wcloudapp`.

**Sửa:**
- Đổi Fastlane Android `package_name` sang `com.vcloud.vcloud`.
- Đổi Codemagic Android `PACKAGE_NAME` sang `com.vcloud.vcloud`.

**Lý do:** tránh upload AAB/APK Android lên sai app Google Play.

### 3.3 Android release fallback ký bằng debug key — ĐÃ SỬA

**Mức độ:** HIGH
**File:** `android/app/build.gradle.kts`

**Bằng chứng trước sửa:** release build fallback sang `signingConfigs.getByName("debug")` khi thiếu `android/key.properties`.

**Sửa:** release build fail-fast bằng `error("Missing android/key.properties for release signing")` nếu thiếu signing config.

**Lý do:** không được phát hành package release ký bằng debug key.

### 3.4 iOS ATS cho phép arbitrary loads — ĐÃ SỬA

**Mức độ:** MEDIUM
**File:** `ios/Runner/Info.plist`

**Bằng chứng trước sửa:** `NSAllowsArbitraryLoads` = `true`.

**Sửa:** gỡ block `NSAppTransportSecurity` mở toàn bộ.

**Lý do:** production app đang dùng HTTPS (`https://vuahethong.net`); không cần mở arbitrary HTTP.

---

## 4. Tồn tại chưa xử lý trong phiên này

1. **GitHub Actions release run đang chạy.** Cần xem kết quả cuối sau khi job iOS/Android hoàn tất.
2. **GitLab pipeline cũ trên `main` vẫn có thể đang chạy.** Sau commit audit fix, trigger `main` đã bị gỡ để lần sau không lặp.
3. **Local Flutter toolchain thiếu.** CI GitHub đã chạy được `flutter analyze` + `flutter test` trong iOS job; local vẫn không có Flutter để tái chạy.

---

## 5. Kết luận

Release `v2.5.0+81` đã sync GitLab/GitHub và đã được audit. Audit phát hiện 4 lỗi release-blocking/risk cao trong CI/CD và mobile release config; toàn bộ đã được sửa trong working tree và cần commit/push lại lên `main` GitLab + GitHub theo yêu cầu của Sếp.
