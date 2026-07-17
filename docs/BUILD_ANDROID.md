# Build & cài đặt VCloud cho Android

Tài liệu này hướng dẫn tạo APK Android để kiểm thử nội bộ hoặc chuẩn bị phát hành.
Ứng dụng yêu cầu **Android 6.0 (API 23)** trở lên. Bản APK mặc định chỉ chứa kiến
trúc **arm64-v8a**, phù hợp với đa số điện thoại Android hiện nay.

## 1. Chuẩn bị cấu hình kết nối

Ứng dụng cần biết địa chỉ **Odoo master resolver**. Không ghi mật khẩu, JWT, tên
database nội bộ, hoặc URL production vào mã nguồn. Truyền cấu hình bằng
`--dart-define` khi chạy/build.

Giá trị tối thiểu:

```text
VCLOUD_ODOO_API_BASE_URL=https://master-odoo.example.com
```

Tùy chọn cho Firebase push notification:

```text
VCLOUD_FIREBASE_API_KEY=...
VCLOUD_FIREBASE_APP_ID=...
VCLOUD_FIREBASE_MESSAGING_SENDER_ID=...
VCLOUD_FIREBASE_PROJECT_ID=...
VCLOUD_FIREBASE_IOS_BUNDLE_ID=com.vcloud.vcloud
```

Nếu không truyền cấu hình Firebase, app vẫn chạy; chỉ tính năng đăng ký thông báo
push bị tắt. Xem [`.env.example`](../.env.example) để biết đủ tên biến.

## 2. Cách nhanh nhất: build bằng Docker

Đây là cách khuyến nghị vì không cần cài Flutter, Dart, Android SDK hay Java trên
máy. Cần Docker Desktop đang chạy và còn ít nhất 10 GB dung lượng trống cho image,
Android SDK và Gradle cache ở lần build đầu.

Từ thư mục gốc dự án, chạy trên macOS/Linux/Git Bash:

```bash
mkdir -p dist
docker run --rm -v "$PWD":/src:ro -v "$PWD/dist":/out \
  ghcr.io/cirruslabs/flutter:stable bash -c '
    set -e
    cp -r /src /app
    cd /app
    rm -rf build .dart_tool pubspec.lock
    # Image hiện dùng Dart 3.12.0; chỉ nới SDK trong bản sao build.
    sed -i "s/3.12.2/3.12.0/" pubspec.yaml
    sed -i "s|^org.gradle.jvmargs=.*|org.gradle.jvmargs=-Xmx3G -XX:MaxMetaspaceSize=512m|" android/gradle.properties
    flutter pub get
    flutter build apk --release --target-platform android-arm64 \
      --dart-define=VCLOUD_ODOO_API_BASE_URL=https://master-odoo.example.com
    cp build/app/outputs/flutter-apk/app-release.apk /out/vcloud.apk
  '
```

Thay URL mẫu bằng Odoo master resolver của môi trường cần kiểm thử. Lệnh chỉ chỉnh
`pubspec.yaml` và Gradle **trong container**, không làm thay đổi file dự án trên máy.

Kết quả: `dist/vcloud.apk`.

### Windows PowerShell

Trong PowerShell, mở Docker Desktop trước, rồi chạy lệnh tương đương sau. Nếu dấu
nháy bị terminal của bạn xử lý khác, hãy dùng Git Bash và lệnh ở trên.

```powershell
$root = (Get-Location).Path
New-Item -ItemType Directory -Force "$root\dist" | Out-Null
docker run --rm -v "${root}:/src:ro" -v "${root}/dist:/out" `
  ghcr.io/cirruslabs/flutter:stable bash -c '
    set -e; cp -r /src /app; cd /app; rm -rf build .dart_tool pubspec.lock;
    sed -i "s/3.12.2/3.12.0/" pubspec.yaml;
    sed -i "s|^org.gradle.jvmargs=.*|org.gradle.jvmargs=-Xmx3G -XX:MaxMetaspaceSize=512m|" android/gradle.properties;
    flutter pub get;
    flutter build apk --release --target-platform android-arm64 --dart-define=VCLOUD_ODOO_API_BASE_URL=https://master-odoo.example.com;
    cp build/app/outputs/flutter-apk/app-release.apk /out/vcloud.apk
  '
```

Lần build đầu có thể mất nhiều phút vì Docker tải Flutter image, Android SDK, NDK,
CMake và Gradle. Các lần sau nhanh hơn đáng kể.

## 3. Build trên máy đã có Flutter

Điều kiện:

- Flutter 3.44+ và Dart 3.12.2+.
- Java 17+ có trong `JAVA_HOME` và `PATH`.
- Android SDK, Android SDK Platform 34+, NDK và CMake được cài qua Android Studio.

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64 \
  --dart-define=VCLOUD_ODOO_API_BASE_URL=https://master-odoo.example.com
```

APK được tạo tại:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Để đặt tên nhất quán cho bản gửi tester:

```bash
mkdir -p dist
cp build/app/outputs/flutter-apk/app-release.apk dist/vcloud.apk
```

Trên PowerShell, thay dòng cuối bằng:

```powershell
New-Item -ItemType Directory -Force dist | Out-Null
Copy-Item build\app\outputs\flutter-apk\app-release.apk dist\vcloud.apk
```

## 4. Cài APK để kiểm thử

### Cài trực tiếp trên điện thoại

1. Chép `dist/vcloud.apk` vào điện thoại.
2. Mở file bằng trình quản lý tệp.
3. Cho phép ứng dụng đang mở file cài "ứng dụng không rõ nguồn gốc" nếu Android yêu cầu.
4. Chọn **Cài đặt**, sau đó mở VCloud.

### Cài bằng ADB

Bật **Developer options** và **USB debugging** trên điện thoại, kết nối USB rồi chạy:

```bash
adb devices
adb install -r dist/vcloud.apk
```

`-r` giữ lại dữ liệu ứng dụng nếu package đã được cài. Nếu Android báo lỗi chữ ký khi
nâng cấp từ APK khác, gỡ bản cũ rồi cài lại:

```bash
adb uninstall com.vcloud.vcloud
adb install dist/vcloud.apk
```

## 5. Xác nhận bản build trước khi gửi tester

```bash
flutter analyze
flutter test
```

Kiểm tra file APK:

```bash
ls -lh dist/vcloud.apk
sha256sum dist/vcloud.apk
```

PowerShell:

```powershell
Get-Item dist\vcloud.apk | Select-Object Name,Length,LastWriteTime
Get-FileHash dist\vcloud.apk -Algorithm SHA256
```

Khi gửi APK cho tester, gửi thêm số version trong `pubspec.yaml`, môi trường Odoo
được dùng và mã SHA-256 để họ xác nhận file nhận được không bị hỏng.

## 6. Phát hành chính thức

Hiện cấu hình Android ký `release` bằng debug key để thuận tiện kiểm thử nội bộ.
Không đưa APK này lên Google Play hoặc dùng để phát hành công khai.

Trước khi phát hành chính thức, cần:

1. Tạo upload keystore riêng, lưu an toàn ngoài repository.
2. Cấu hình `android/key.properties` (file này đã được gitignore) và signing config
   release trong `android/app/build.gradle.kts`.
3. Tăng `version` trong `pubspec.yaml`.
4. Chạy kiểm thử, build Android App Bundle (`flutter build appbundle --release`) và
   upload `.aab` lên Play Console.

## 7. Xử lý lỗi thường gặp

| Triệu chứng | Cách xử lý |
|---|---|
| `JAVA_HOME is not set` | Cài Java 17+, đặt `JAVA_HOME` trỏ tới thư mục JDK và mở terminal mới; hoặc dùng Docker. |
| Dart SDK `3.12.0` không thỏa `^3.12.2` trong Docker | Dùng đúng lệnh Docker ở trên; nó chỉ hạ giới hạn SDK trong bản sao container. Không sửa `pubspec.yaml` ở máy. |
| Docker build bị hết bộ nhớ | Để Docker Desktop tối thiểu 8 GB RAM; lệnh đã hạ Gradle heap xuống 3 GB. |
| APK không cài được do chữ ký | Gỡ APK cũ có chữ ký khác hoặc dùng cùng keystore cho các bản cập nhật. |
| App không đăng nhập được | Kiểm tra `VCLOUD_ODOO_API_BASE_URL` trỏ tới master resolver và tenant mapping trong Odoo đã được tạo. |
| Vẫn thấy web/app cũ sau build web | Gỡ service worker, xóa cache trình duyệt và hard reload. |

