# HƯỚNG DẪN TỰ ĐỘNG HÓA CI/CD SỬ DỤNG FASTLANE + GITHUB ACTIONS / GITLAB CI + WEBHOOK

**Dự án:** VCloud Mobile App (`vclients`)  
**Tổ chức:** W360S JOINT STOCK COMPANY  
**App ID:** `com.w360s.wcloudapp` (`1365622472`)  

---

## 1. TỔNG QUAN HỆ THỐNG CI/CD MỚI (THAY THẾ CODEMAGIC)

Hệ thống CI/CD mới được xây dựng bằng **Fastlane chính chủ (`https://fastlane.tools/`)**, kết hợp với **GitHub Actions** / **GitLab CI** và **Hệ thống Webhook tự động thông báo kết quả**.

### Ưu điểm vượt trội:
- **Không giới hạn phút build:** Hoàn toàn miễn phí trên GitHub Actions (2,000 phút/tháng) hoặc Runner tự host.
- **Bảo mật tuyệt đối:** Mọi chứng chỉ, App Store Connect API Key `.p8`, Mật khẩu ứng dụng và Webhook URL được bảo vệ trong **Repository Secrets / CI Variables**. Không bao giờ commit secret vào Git repository.
- **App Store Connect API Key (.p8):** Khuyến nghị chính thức từ Apple, không vướng xác thực 2 yếu tố (2FA) và không hết hạn.
- **Thông báo Webhook thời gian thực:** Tự động bắn thông báo sang **Telegram / Slack / Discord / Custom Server** ngay khi build hoàn tất kèm thông tin phiên bản (ví dụ `v2.4.0+40`), commit SHA và liên kết tải bản build.

---

## 2. DANH SÁCH BÍ MẬT CẦN CẤU HÌNH (REPOSITORY SECRETS)

Vào **Settings -> Secrets and variables -> Actions** trên GitHub (hoặc **Settings -> CI/CD -> Variables** trên GitLab) để thêm các biến sau:

| Tên Secret | Mô tả / Giá trị | Bắt buộc cho |
| :--- | :--- | :---: |
| `APP_STORE_CONNECT_KEY_ID` | Key ID tạo từ App Store Connect (Ví dụ: `3J68D9JX79`) | iOS (TestFlight) |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID của tổ chức W360S (`69a6de93-48bc-47e3-e053-5b8c7c11a4d1`) | iOS (TestFlight) |
| `APP_STORE_CONNECT_KEY_CONTENT` | Nội dung file khóa bảo mật `.p8` (Bắt đầu bằng `-----BEGIN PRIVATE KEY-----`) | iOS (TestFlight) |
| `APPLE_APP_PASS` *(Dự phòng)* | Mật khẩu ứng dụng 16 ký tự (`ijbn-xpar-vwyk-hdyz`) nếu không dùng Key `.p8` | iOS (TestFlight) |
| `APPLE_ID` | Email quản trị Apple App Manager (`tanmnn@360.org.vn`) | iOS (TestFlight) |
| `WEBHOOK_URL` | Đường dẫn Webhook (Slack, Discord, Telegram Bot HTTP Endpoint) | Webhook Alerts |
| `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` | JSON Service Account của Google Play Console (dành cho Android) | Android (Play Store) |

---

## 3. QUY TRÌNH KÍCH HOẠT BUILD TỰ ĐỘNG (WEBHOOK & GIT PUSH)

### Cách 1: Tự động qua Git Push (Phổ biến nhất)
Khi bạn push code lên các nhánh release:
```bash
# Push bản iOS TestFlight
git push origin release/ios-appstore

# Push bản Android Release
git push origin release/android-playstore
```
Pipeline sẽ tự động khởi chạy Fastlane ➔ Build ➔ Upload TestFlight / Play Store ➔ Bắn Webhook thông báo!

### Cách 2: Kích hoạt thủ công từ giao diện GitHub
1. Vào tab **Actions** trên GitHub Repository.
2. Chọn Workflow **Mobile CI/CD (Fastlane + Webhooks)**.
3. Nhấn **Run workflow** -> Chọn nhánh và Nền tảng muốn build (`all`, `ios`, hoặc `android`).

### Cách 3: Kích hoạt từ xa qua Webhook Trigger (HTTP POST)
Bạn có thể gọi HTTP POST request từ bất kỳ đâu (Website nội bộ, cURL script, crm, v.v.):
```bash
curl -X POST https://api.github.com/repos/360org_mobiles/vclients/dispatches \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token YOUR_GITHUB_PERSONAL_ACCESS_TOKEN" \
  -d '{"event_type": "trigger-build"}'
```

---

## 4. CHẠY FASTLANE TRỰC TIẾP TRÊN MÁY LOCAL (DÀNH CHO DEV)

Nếu bạn muốn chạy Fastlane thử nghiệm trên máy local:

### 1. Cài đặt Fastlane:
```bash
cd vclients
bundle install
```

### 2. Chạy lane iOS (TestFlight):
```bash
export APP_STORE_CONNECT_KEY_ID="3J68D9JX79"
export APP_STORE_CONNECT_ISSUER_ID="69a6de93-48bc-47e3-e053-5b8c7c11a4d1"
export APP_STORE_CONNECT_KEY_CONTENT="$(cat path/to/AuthKey_3J68D9JX79.p8)"
export WEBHOOK_URL="https://your-webhook-endpoint.com/api"

bundle exec fastlane ios beta
```

### 3. Chạy lane Android (Build APK & AAB):
```bash
export WEBHOOK_URL="https://your-webhook-endpoint.com/api"

bundle exec fastlane android beta
```

---

## 6. NHẬT KÝ LỖI THƯỜNG GẶP VÀ CÁCH KHẮC PHỤC (TROUBLESHOOTING KNOWLEDGEBASE)

### Lỗi 1: `No valid code signing certificates were found` khi build iOS trên CI
- **Nguyên nhân:** Máy Mac Runner của GitHub Actions không có sẵn chứng chỉ ký app cá nhân trong Keychain.
- **Giải pháp đã xử lý:** Sử dụng cờ `--no-codesign` trong lệnh biên dịch `flutter build ipa --release --no-codesign`. Tiến trình Fastlane `upload_to_testflight` sẽ tự động đóng gói IPA và ký app chuẩn App Store Connect.

### Lỗi 2: `invalid curve name (OpenSSL::PKey::ECError)` khi đọc API Key `.p8`
- **Nguyên nhân:** Trong ngôn ngữ Ruby, chuỗi rỗng `""` được tính là `true`. Khi không có secret `.p8`, Fastlane đọc chuỗi rỗng và cố gắng giải mã OpenSSL EC key.
- **Giải pháp đã xử lý:** Cập nhật Fastfile kiểm tra điều kiện thực tế `!key_content.strip.empty?`. Khi không có file `.p8`, Fastlane tự động chuyển sang tài khoản App Manager (`tanmnn@360.org.vn` + `ijbn-xpar-vwyk-hdyz`).

### Lỗi 3: `Could not find aab file` / `You passed invalid parameters to upload_to_play_store`
- **Nguyên nhân:** Chưa có tài khoản Google Play Console nhưng biến môi trường Google Credentials bị đọc nhầm hoặc sai đường dẫn tương đối.
- **Giải pháp đã xử lý:** Cập nhật Fastfile kiểm tra `!gcloud_creds.strip.empty?` và kiểm tra sự tồn tại của file AAB. Khi không có Google Play Console, Fastlane tự động bỏ qua bước đẩy CH Play và xuất bản file APK/AAB lên GitHub Artifacts an toàn 100%.

### Lỗi 4: `Could not find option 'app_specific_password'` trong `upload_to_testflight`
- **Nguyên nhân:** Fastlane không nhận trực tiếp tham số `app_specific_password: ...` trong hàm `upload_to_testflight`.
- **Giải pháp đã xử lý:** Chuyển sang đặt biến môi trường chuẩn của Fastlane `ENV["FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD"] = app_pass`. Fastlane sẽ tự động xác thực thành công với Apple TestFlight.

---
*Tài liệu này được tạo tự động để lưu trữ và bảo trì hệ thống CI/CD Fastlane cho W360S CORP.*
