# DEPLOY_GUIDE.md - Hướng Dẫn Chạy, Build & Test VCloud

Tài liệu tổng hợp các lệnh chạy ứng dụng Flutter **VCloud** kết nối đến hệ thống Odoo Backend **`https://vuahethong.net`** (Môi trường Production) và **Localhost**.

---

## 🌐 1. Chạy trên Web Browser (Chrome)
> *Khuyến nghị dùng để kiểm tra nhanh giao diện (UI/UX), Dark Mode, responsive.*

```bash
flutter run -d chrome --dart-define=VCLOUD_ODOO_API_BASE_URL=https://vuahethong.net
```

*(Nếu cần chỉ định tên Database Odoo cụ thể):*
```bash
flutter run -d chrome --dart-define=VCLOUD_ODOO_API_BASE_URL=https://vuahethong.net --dart-define=VCLOUD_ODOO_DB=tên_database
```

---

## 📱 2. Chạy trên Thiết Bị Thật / Máy Ảo (Android / iOS)

```bash
flutter run --dart-define=VCLOUD_ODOO_API_BASE_URL=https://vuahethong.net
```

---

## 📦 3. Build APK Debug để cài trực tiếp vào điện thoại Android

```bash
flutter build apk --debug --dart-define=VCLOUD_ODOO_API_BASE_URL=https://vuahethong.net
```

📍 **Vị trí file APK sau khi build:**
```
build/app/outputs/flutter-apk/app-debug.apk
```

---

## 💻 4. Chạy kết nối về Backend Local (Khi phát triển offline)

```bash
flutter run -d chrome --dart-define=VCLOUD_ODOO_API_BASE_URL=http://localhost:8069
```

---

## 🔧 5. Chạy script Web local với Odoo dev_env tùy chọn

`launch_web.sh` không còn hard-code đường dẫn máy cá nhân. Nếu cần sync module `v_mobile` vào Odoo Docker local, truyền `LOCAL_DEV_DIR` qua env:

```bash
LOCAL_DEV_DIR=/Volumes/DATA/DEV/dev_env/17.0 ./launch_web.sh
```

Nếu không truyền `LOCAL_DEV_DIR`, script chỉ mở Flutter Web và kết nối `API_URL` mặc định `http://127.0.0.1:8069`:

```bash
API_URL=https://vuahethong.net ./launch_web.sh --release
```

---

## 🚀 6. Build phát hành Android / iOS

- Android APK cài trực tiếp: xem `docs/BUILD_ANDROID.md`.
- Android Play Store AAB: xem `docs/BUILD_ANDROID_PLAYSTORE.md`.
- iOS TestFlight CI: xem `docs/IOS_CI_TESTFLIGHT.md`.
- Fastlane secrets/lane: xem `docs/FASTLANE_CI_CD_GUIDE.md`.

Fastlane iOS lấy Apple account từ biến môi trường, không hard-code trong repo:

```bash
export APPLE_ID="email-app-manager@example.com"
export APPLE_APP_PASS="xxxx-xxxx-xxxx-xxxx"
bundle exec fastlane ios beta
```

---

## 🔍 7. Kiểm tra mã nguồn (Linter & Test)

```bash
flutter analyze
flutter test
```
