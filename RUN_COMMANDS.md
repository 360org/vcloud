# 🚀 Hướng Dẫn Chạy & Test Flutter Mobile (`vclients`)

Tài liệu tổng hợp các lệnh chạy ứng dụng Flutter `vclients` kết nối đến hệ thống Odoo Backend **`https://vuahethong.net`** (Môi trường Production) và **Localhost**.

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

## 🔍 5. Kiểm tra mã nguồn (Linter & Test)

```bash
flutter analyze
flutter test
```
