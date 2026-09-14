# Hướng Dẫn Phát Hành & Quản Lý Google Play (V_Cloud Android)

Tài liệu lưu trữ quy trình ký số, cấu hình kỹ thuật, chuẩn bị tài nguyên đồ họa và từng bước phát hành ứng dụng V_Cloud lên Google Play Console.

---

## 1. Thông Tin Kỹ Thuật & Chứng Chỉ Ký Số (Release Keystore)

- **Tên hiển thị ứng dụng (App Name)**: `Vua Hệ Thống` (Tên trước đây: `V_Cloud`)
- **Package Name (Application ID)**: `com.mobile.vloud`
- **Target SDK**: `36` (Android SDK 36 — Chuẩn bắt buộc mới nhất của Google Play)
- **Phiên bản hiện tại trên Console**: `version: 2.9.3+105` (`versionCode: 105`, `versionName: 2.9.3`)
- **Vị trí file Keystore chính**: `/media/tanma/DATA/save/mobile_versions/vclients/android/upload-keystore.jks`
- **Vị trí file Backup an toàn**: `/media/tanma/DATA/thongbao_firebase/upload-keystore.jks`
- **Thời hạn hiệu lực**: Đến năm **2054** (10.000 ngày)
- **Key Alias**: `upload`
- **Mật khẩu Keystore & Key**: `123456`
- **Thông tin chủ sở hữu (Certificate Owner)**:
  - `CN`: 360corp
  - `OU`: Mobile
  - `O`: 360 CORP
  - `L`: HCM
  - `ST`: HCM
  - `C`: VN
- **Mã băm vân tay chứng chỉ (Fingerprints)**:
  - **SHA1**: `73:90:0B:6A:95:5A:62:C2:51:16:6B:70:3D:6D:5F:42:E6:CF:3C:A4`
  - **SHA256**: `B6:0E:40:6E:BF:56:F5:55:BE:23:09:97:85:1A:26:EC:8B:05:2E:F0:F5:D7:B4:F2:9D:CB:28:4E:4B:A5:B4:62`

---

## 2. Cấu Hình Ký Tự Động (`key.properties`)

File: `/media/tanma/DATA/save/mobile_versions/vclients/android/key.properties` (Đã được cấu hình và nằm trong `.gitignore`):
```properties
storePassword=123456
keyPassword=123456
keyAlias=upload
storeFile=../upload-keystore.jks
```

---

## 3. Tài Nguyên Đồ Họa & Ảnh Chụp Màn Hình (Store Assets)

Toàn bộ hình ảnh đã được chuẩn hóa đúng từng pixel theo tiêu chuẩn Google Play và lưu trong project:

1. **Biểu tượng ứng dụng (App Icon - 512x512 px PNG)**:
   `/media/tanma/DATA/save/mobile_versions/vclients/assets/branding/google_play_icon_512x512.png`
2. **Ảnh đầu trang (Feature Graphic - 1024x500 px PNG)**:
   `/media/tanma/DATA/save/mobile_versions/vclients/assets/branding/google_play_feature_graphic_1024x500.png`
3. **Bộ 5 ảnh chụp màn hình điện thoại (Galaxy S20 - 736x1600 px)**:
   - Thư mục lưu trong project: `/media/tanma/DATA/save/mobile_versions/vclients/assets/screenshots/android/`
   - Thư mục nguồn ngoài: `/media/tanma/DATA/save/anhchup_android/`
   - Gồm 5 file: `Samsung-Galaxy-S20-localhost (1).png` đến `(5).png`.

---

## 4. Nội Dung Khai Báo Bắt Buộc Trên Google Play (Store Listing & Policy)

### A. Thông tin cửa hàng (Store Listing):
- **Tên ứng dụng**: `Vua Hệ Thống`
- **Mô tả ngắn (≤ 80 ký tự)**:
  `Ứng dụng quản trị doanh nghiệp, chấm công, phiếu hỗ trợ và giao tiếp nội bộ.`
- **Mô tả đầy đủ**:
  ```text
  Vua Hệ Thống là ứng dụng di động quản trị doanh nghiệp toàn diện dành cho nhân viên và ban quản lý:
  - Chấm công thông minh qua định vị GPS.
  - Quản lý ca làm việc, bảng chấm công và yêu cầu nghỉ phép.
  - Theo dõi, xử lý và tạo phiếu hỗ trợ (Ticket).
  - Tin nhắn và trao đổi công việc nội bộ theo thời gian thực.
  - Bảng điều khiển hiệu suất công việc trực quan, hiện đại.
  ```
- **Danh mục (Category)**: Doanh nghiệp (Business) / Năng suất (Productivity).
- **Email hỗ trợ**: `support@360.org.vn` (hoặc `nhattanmanguyen@gmail.com`).
- **Website & Privacy Policy**: `https://vuahethong.net/` (hoặc `https://360.org.vn`).

### B. Khai báo quyền hình ảnh/video (Photo & Video Permissions):
- **Quyền**: `READ_MEDIA_IMAGES`
- **Mục đích khai báo**: Chức năng ứng dụng (App functionality) / Chia sẻ tệp & trò chuyện (File sharing / Chat).
- **Lý do giải trình**: Cho phép nhân viên tải ảnh đính kèm vào phiếu hỗ trợ (Ticket), gửi ảnh trong tin nhắn nội bộ và cập nhật ảnh đại diện hồ sơ.

---

## 5. Các Lỗi Thường Gặp & Cách Xử Lý Đã Thực Hiện

| Vấn đề gặp phải | Nguyên nhân | Cách khắc phục đã thực hiện |
|---|---|---|
| Lỗi tên gói: `com.mobile.vloud` | Project ban đầu để `com.vcloud.vcloud`, Console đăng ký `com.mobile.vloud` | Đồng bộ `namespace`, `applicationId`, `MainActivity.kt`, `google-services.json` sang `com.mobile.vloud` |
| Lỗi Target API: `cần API tối thiểu 36` | `targetSdk` ban đầu là 34 | Nâng `targetSdk = 36` trong `android/app/build.gradle.kts` |
| Lỗi: `Mã phiên bản 101 đã được sử dụng` | Bản 101 đã được tải lên thư viện Console trước đó | Tăng `versionCode: 102` (`2.9.2+102`) trong `pubspec.yaml` |
| Lỗi: `Dòng 1: văn bản nằm ngoài thẻ ngôn ngữ` | Viết dính dòng ngoài thẻ `<vi>` | Bọc chuẩn cú pháp `<vi>\nNội dung\n</vi>` |
| Lỗi kích thước ảnh Icon & Feature Graphic | Ảnh cũ `1024x1024` không đúng chuẩn Play Store | Dùng script Python PIL tạo chuẩn `512x512` và `1024x500` |
| Lỗi khai báo quyền truy cập ảnh/video | Thiếu form giải trình `READ_MEDIA_IMAGES` | Hoàn thành form khai báo: ảnh dùng cho Ticket, Chat, Avatar |
| Lỗi Google từ chối: Quyền truy cập ảnh/video | App không phải thư viện ảnh, Google yêu cầu dùng Photo Picker hệ thống | Gỡ bỏ hoàn toàn `READ_MEDIA_IMAGES`, `READ_MEDIA_VISUAL_USER_SELECTED`, `READ_EXTERNAL_STORAGE` khỏi `AndroidManifest.xml` (dùng `image_picker` native Photo Picker 0 quyền) |
| Lỗi Google từ chối: Chức năng bị hỏng (Crash startup) | Firebase Messaging stream listener bị lỗi khi chạy cold start kiểm thử tự động của Google bot | Bọc toàn bộ `onMessageStream`, `onMessageOpenedAppStream`, `getInitialMessage` và background handler trong try-catch phòng thủ, nullable subscription |

---

## 6. Quy Trình Build & Ra Bản Cập Nhật Mới (Tái Sử Dụng Sau Này)

### Bước 1: Tăng version trong `pubspec.yaml`
Mỗi lần release bản mới, **bắt buộc số nguyên sau dấu `+` phải tăng lên**:
```yaml
# vclients/pubspec.yaml
version: 2.9.2+103   # Tăng từ 102 lên 103 (hoặc cao hơn)
```

### Bước 2: Chạy lệnh build `.aab`
```bash
cd /media/tanma/DATA/save/mobile_versions/vclients
flutter build appbundle --release
```

- **File kết quả**:
  `/media/tanma/DATA/save/mobile_versions/vclients/build/app/outputs/bundle/release/app-release.aab`
- **Lệnh kiểm tra chữ ký xác thực**:
  ```bash
  keytool -printcert -jarfile /media/tanma/DATA/save/mobile_versions/vclients/build/app/outputs/bundle/release/app-release.aab
  ```

### Bước 3: Đưa lên Google Play Console
1. Truy cập [Google Play Console](https://play.google.com/console/u/0/developers/7885960774572573689/app/4972248452883076953/app-dashboard).
2. Chọn **Phát hành công khai (Production)** -> Bấm **Tạo bản phát hành mới (Create new release)**.
3. Bấm **Tải lên** file `app-release.aab` mới vừa build.
4. Điền ghi chú phát hành theo cú pháp `<vi>Nội dung</vi>`.
5. Bấm **Tiếp theo** -> **Lưu** -> **Gửi nội dung thay đổi để xem xét**.

---

## 7. Cấu Hình Thêm Email Nhận Thông Báo / Admin Console

Để email công ty nhận song song kết quả kiểm duyệt từ Google:
- **Nhận thông báo**: `Cài đặt` -> `Tùy chọn thông báo` -> `Thêm địa chỉ email liên hệ` (`support@360.org.vn`).
- **Phân quyền Admin**: `Người dùng và quyền` -> `Mời người dùng mới` -> Cấp quyền Quản trị viên/Phát hành.

---

## 8. 🚀 Quy Trình 1 Giai Đoạn Tự Động Hóa CI/CD Thẳng Lên Production (CH Play) & Auto Changelog (Task #16508)

Khi kích hoạt workflow GitHub Actions, toàn bộ quy trình phát hành lên Google Play được tinh gọn thành **1 Giai đoạn duy nhất (Direct to Production)** theo chỉ đạo của Sếp Tân:

### A. Cơ chế tự động nạp "Có gì mới" (What's new / Release Notes):
1. Fastlane tự động đọc file `docs/CHANGELOGS.md` tại mục phiên bản tương ứng trong `pubspec.yaml` (ví dụ `## [v2.9.6+128]`).
2. Làm sạch định dạng markdown và cắt gọn an toàn `<= 480 ký tự` (chuẩn giới hạn của Google Play API là 500 ký tự).
3. Tự động ghi vào các file metadata:
   - `fastlane/metadata/android/vi-VN/changelogs/<build_number>.txt` (Tiếng Việt)
   - `fastlane/metadata/android/en-US/changelogs/<build_number>.txt` (Tiếng Anh)
4. Fastlane `upload_to_play_store` với:
   - `track: 'production'` (Mặc định nạp thẳng vào Kênh Sản Xuất)
   - `skip_upload_metadata: true`, `skip_upload_images: true`, `skip_upload_screenshots: true` (không ghi đè giao diện Store)
   - `skip_upload_changelogs: false` (chỉ cập nhật nội dung "Có gì mới" của bản phát hành đó).

### B. Quy trình phát hành 1 Giai đoạn (Direct to Production Track):
1. **Đẩy thẳng Kênh Sản Xuất (Production Track - Mặc định)**:
   - File `.aab` và Changelog bay thẳng vào Kênh Sản Xuất (Production) của Google Play Console.
   - Không qua trạm trung gian Internal Testing.
2. **Google Review Thẩm Định**:
   - Google tự động chạy Pre-launch report (kiểm thử thiết bị ảo, phát hiện crash) và kiểm duyệt chính sách.
3. **Hai kịch bản kết quả**:
   - **Kịch bản 1: Phê duyệt (Pass)** ➔ Ứng dụng tự động phát hành công khai trên CH Play Store. Toàn bộ người dùng và nhân viên thấy bản cập nhật.
   - **Kịch bản 2: Bị từ chối (Reject)** ➔ Google gửi thông báo lý do từ chối (chính sách quyền, form giải trình hoặc crash). Sếp Tân xem lý do, fix mã nguồn, tăng `build_number` và kích hoạt lại GitHub Actions để nạp bản thay thế.
