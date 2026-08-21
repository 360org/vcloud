# 📦 Hướng Dẫn Đóng Gói Android App Bundle (.aab) & Nộp Duyệt Google Play Store

Tài liệu này hướng dẫn chi tiết các bước tạo Keystore chữ ký phát hành, đóng gói file **Android App Bundle (.aab)** release và quy trình nộp duyệt ứng dụng trên **Google Play Console**.

---

## 🔑 Bước 1: Khởi Tạo Upload Keystore Chữ Ký Release

Google Play yêu cầu ứng dụng phải được ký bằng một **Upload Key** trước khi tải file `.aab` lên Console.

### Lệnh tạo Keystore (Chạy trên Terminal/Git Bash):

```bash
cd <VCLOUD_ROOT>/android

keytool -genkey -v -keystore upload-keystore.jks \
  -storetype JKS \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -alias upload
```

> [!CAUTION]
> **Lưu trữ Keystore an toàn:**
> - File `upload-keystore.jks` và mật khẩu tạo ra **phải được sao lưu an toàn tuyệt đối**.
> - Không commit file `.jks` hoặc `key.properties` lên Git public (Cả 2 đã được gitignore sẵn).

### Tạo file cấu hình `key.properties`:

Sau khi tạo xong file `upload-keystore.jks`, tạo file `vclients/android/key.properties`:

```properties
storePassword=MAT_KHAU_STORE_CUA_BAN
keyPassword=MAT_KHAU_KEY_CUA_BAN
keyAlias=upload
storeFile=upload-keystore.jks
```

---

## 🚀 Bước 2: Đóng Gói Android App Bundle (.aab)

### Cách 1: Build bằng Flutter CLI (Trên máy dev)

Mở terminal tại thư mục `vclients`:

```bash
cd <VCLOUD_ROOT>

# 1. Cập nhật các dependency và kiểm tra mã nguồn
flutter pub get
flutter analyze

# 2. Build AAB với Odoo API Production Base URL
flutter build appbundle --release \
  --dart-define=VCLOUD_ODOO_API_BASE_URL=https://master-odoo.vuahethong.com
```

Kết quả tạo ra tại:
`build/app/outputs/bundle/release/app-release.aab`

### Cách 2: Build bằng Docker Container

Nếu môi trường dev chưa cấu hình Flutter hoặc muốn build trên môi trường sạch:

```bash
cd <VCLOUD_ROOT>
mkdir -p dist

docker run --rm -v "$PWD":/src -w /src \
  ghcr.io/cirruslabs/flutter:stable bash -c '
    set -e
    flutter pub get
    flutter build appbundle --release \
      --dart-define=VCLOUD_ODOO_API_BASE_URL=https://master-odoo.vuahethong.com
    cp build/app/outputs/bundle/release/app-release.aab dist/vcloud-release.aab
  '
```

---

## 🔍 Bước 3: Kiểm Tra File AAB Trước Khi Đẩy Lên Play Console

1. Kiểm tra kích thước và tổng kiểm SHA-256:
   ```bash
   ls -lh build/app/outputs/bundle/release/app-release.aab
   sha256sum build/app/outputs/bundle/release/app-release.aab
   ```

2. Kiểm tra thông tin Package Name và Version trong AAB (nếu có `bundletool`):
   ```bash
   bundletool dump manifest --bundle=build/app/outputs/bundle/release/app-release.aab
   ```

---

## 🌐 Bước 4: Quy Trình Đăng Ký & Nộp Duyệt Trên Google Play Console

### 1. Khởi tạo Ứng dụng trên Google Play Console
1. Truy cập [Google Play Console](https://play.google.com/console) với tài khoản Nhà phát triển V360S.
2. Nhấp **Tạo ứng dụng (Create app)**.
3. Điền thông tin:
   - **Tên ứng dụng**: `VCloud Mobile`
   - **Ngôn ngữ mặc định**: Tiếng Việt (vi)
   - **Loại ứng dụng**: App
   - **Miễn phí / Trả phí**: Miễn phí (Free)
4. Đồng ý với các điều khoản của Google và nhấp **Tạo ứng dụng**.

### 2. Cài đặt Trang cửa hàng chính (Main Store Listing)
1. Vào menu **Sự hiện diện trên cửa hàng (Store presence)** > **Trang cửa hàng chính (Main store listing)**.
2. Sao chép thông tin từ tài liệu [`GOOGLE_PLAY_STORE_LISTING.md`](GOOGLE_PLAY_STORE_LISTING.md):
   - Tên ứng dụng: `VCloud Mobile`
   - Mô tả ngắn & Mô tả đầy đủ.
   - Tải lên App Icon `vcloud_playstore_icon_512x512.png`.
   - Tải lên Feature Graphic `vcloud_playstore_feature_graphic_1024x500.png`.
   - Tải lên 5 ảnh Phone Screenshots trong thư mục `image/`.

### 3. Khai báo An toàn dữ liệu & Quyền riêng tư (App Content)
1. Vào menu **Nội dung ứng dụng (App content)**:
   - **Chính sách bảo mật (Privacy Policy)**: Dán URL `https://vuahethong.com`.
   - **Quyền truy cập ứng dụng (App access)**: Chọn "Tất cả tính năng đều khả dụng mà không cần hạn chế" (hoặc cung cấp tài khoản demo Odoo nếu cần).
   - **An toàn dữ liệu (Data Safety)**: Khai báo GPS, Email, Name, Photos theo bảng hướng dẫn trong `GOOGLE_PLAY_STORE_LISTING.md`.
   - **Xếp hạng nội dung (Content Rating)**: Hoàn thành bảng hỏi IARC để nhận chứng nhận độ tuổi.

### 4. Tải lên Bản phát hành (.aab)
1. Vào menu **Thử nghiệm nội bộ (Internal testing)** hoặc **Thử nghiệm kín (Closed testing)**.
2. Nhấp **Tạo bản phát hành mới (Create new release)**.
3. Đồng ý kích hoạt **Play App Signing** (Google sẽ tự động quản lý App signing key gốc).
4. Tải file `app-release.aab` lên.
5. Đặt tên bản phát hành (Release name): `1.1.0 (2)`.
6. Nhập Ghi chú bản phát hành (Release notes):
   ```text
   Bản phát hành đầu tiên ứng dụng VCloud Mobile cho doanh nghiệp:
   - Chấm công & Điểm danh GPS thời gian thực.
   - Quản lý nhật ký công việc (Timesheet).
   - Quản lý Yêu cầu & Ticket hỗ trợ.
   - Trò chuyện nội bộ & Thông báo tức thì.
   ```
7. Nhấp **Lưu (Save)** > **Kiểm tra bản phát hành (Review release)** > **Bắt đầu triển khai (Start rollout)**.

---

## 🛠️ Xử Lý Lỗi Thường Gặp Khi Upload AAB

| Triệu chứng | Nguyên nhân | Cách xử lý |
|---|---|---|
| `Unsigned AAB` | Build AAB chưa nạp keystore | Kiểm tra file `android/key.properties` đã đầy đủ thông số chưa |
| `Version code already used` | Code `versionCode` trong `pubspec.yaml` chưa tăng | Tăng phần `+X` trong `pubspec.yaml` (ví dụ `1.1.0+3`) rồi build lại |
| `Duplicate Package Name` | Application ID đã tồn tại trên Play Store | Xác nhận lại `com.vcloud.vcloud` trên Play Console thuộc tài khoản V360S |
