# 🍎 HƯỚNG DẪN ĐÓNG GÓI & QUẢN TRỊ XUẤT BẢN APPLE APP STORE CONNECT
## (APP STORE CONNECT RELEASE GUIDE & TROUBLESHOOTING KNOWLEDGE BASE)

> **Dự án:** VCloud Mobile App (Flutter Client)  
> **Tổ chức / Doanh nghiệp:** W360S JOINT STOCK COMPANY  
> **Bundle Identifier:** `com.w360s.wcloudapp`  
> **Team ID:** `ZC3H8887XS`  
> **Apple ID App Record:** `1365622472`  
> **Tiêu chuẩn quản trị:** AIaC 3.0 / Ponytail Minimal Diff

---

## 📑 MỤC LỤC
1. [Cấu Hình Đóng Gói Chuẩn Cho App Store Connect & TestFlight](#1-cấu-hình-đóng-gói-chuẩn-cho-app-store-connect--testflight)
2. [Kho Tri Thức & Lịch Sử Sửa Lỗi Apple (Troubleshooting KB)](#2-kho-tri-thức--lịch-sử-sửa-lỗi-apple-troubleshooting-kb)
   - [Lỗi 1: Build bị ẩn / Radio button bị mờ trên App Store Connect](#lỗi-1-build-bị-ẩn--radio-button-bị-mờ-trên-app-store-connect)
   - [Lỗi 2: Thiếu tính năng Xóa tài khoản (Apple Guideline 5.1.1(v))](#lỗi-2-thiếu-tính-năng-xóa-tài-khoản-apple-guideline-511v)
   - [Lỗi 3: Thiếu liên kết Chính sách Quyền riêng tư (Apple Guideline 5.1.1(i))](#lỗi-3-thiếu-liên-kết-chính-sách-quyền-riêng-tư-apple-guideline-511i)
   - [Lỗi 4: Chuỗi mô tả quyền (Permission Usage Descriptions) không chuẩn](#lỗi-4-chuỗi-mô-tả-quyền-permission-usage-descriptions-không-chuẩn)
   - [Lỗi 5: Bị chặn hỏi câu hỏi Mã hóa (Missing Export Compliance)](#lỗi-5-bị-chặn-hỏi-câu-hỏi-mã-hóa-missing-export-compliance)
   - [Lỗi 6: Lỗi xác thực 401 khi Upload TestFlight via API Key](#lỗi-6-lỗi-xác-thực-401-khi-upload-testflight-via-api-key)
3. [Quy Trình Kiểm Tra & Xuất Bản Bản Dựng Mới Từng Bước (Checklist)](#3-quy-trình-kiểm-tra--xuất-bản-bản-dựng-mới-từng-bước-checklist)

---

## 1. CẤU HÌNH ĐÓNG GÓI CHUẨN CHO APP STORE CONNECT & TESTFLIGHT

Khi đóng gói ứng dụng iOS qua Fastlane hoặc GitHub Actions, tệp `export_options.plist` và cấu hình trong `Fastfile` bắt buộc phải có các thông số sau:

### 1.1. Cấu hình `ios/export_options.plist`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store</string>
	<key>teamID</key>
	<string>ZC3H8887XS</string>
	<key>uploadSymbols</key>
	<true/>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
	<key>testFlightInternalTestingOnly</key>
	<false/>
	<key>signingStyle</key>
	<string>manual</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>com.w360s.wcloudapp</key>
		<string>V_cloud</string>
	</dict>
</dict>
</plist>
```

### 1.2. Điểm Then Chốt Trong `fastlane/Fastfile`
Tại hàm `lane :beta`:
```ruby
export_options_hash = {
  "method" => "app-store",
  "teamID" => "ZC3H8887XS",
  "uploadSymbols" => true,
  "manageAppVersionAndBuildNumber" => false,
  "testFlightInternalTestingOnly" => false,  # BẮT BUỘC ĐỂ FALSE ĐỂ SUBMIT ĐƯỢC APP STORE REVIEW
  "signingStyle" => "manual",
  "provisioningProfiles" => {
    "com.w360s.wcloudapp" => profile_name
  }
}
```

---

## 2. KHO TRI THỨC & LỊCH SỬ SỬA LỖI APPLE (TROUBLESHOOTING KB)

### LỖI 1: Build bị ẩn / Radio button bị mờ trên App Store Connect
* **Triệu chứng**: Trong trang quản lý bản phát hành trên App Store Connect (mục `Add Build`), bản build xuất hiện với icon vàng, vòng tròn radio button bị disabled / không click chọn được.
* **Nguyên nhân gốc rễ (Root Cause)**: Khi đóng gói xuất file `.ipa`, cờ `testFlightInternalTestingOnly` bị đặt là `true`. Apple đánh dấu bản build này chỉ dùng cho nội bộ TestFlight, không cho phép đưa vào hàng đợi gửi xét duyệt chính thức.
* **Giải pháp khắc phục**:
  1. Đổi `testFlightInternalTestingOnly` thành `false` trong cả `fastlane/Fastfile`, `ios/export_options.plist`, và `codemagic.yaml`.
  2. Tăng số `BUILD_NUMBER` (+1) trong `pubspec.yaml` (ví dụ: từ `96` lên `97`).
  3. Kích hoạt build lại để đẩy bản `.ipa` mới lên. Bản build mới sẽ có radio button chọn được ngay sau khi Apple xử lý xong.

---

### LỖI 2: Thiếu tính năng Xóa tài khoản (Apple Guideline 5.1.1(v))
* **Quy định Apple**: Bất kỳ ứng dụng nào hỗ trợ tạo tài khoản / đăng nhập đều bắt buộc phải cung cấp cơ chế cho phép người dùng khởi tạo yêu cầu xóa tài khoản và dữ liệu cá nhân trực tiếp từ trong ứng dụng.
* **Triệu chứng Rejection**: Apple gửi thông báo từ chối xét duyệt với nội dung: *"Guideline 5.1.1(v) - Legal - Privacy - Data Collection and Storage: Apps that support account creation must also offer account deletion."*
* **Giải pháp khắc phục (Đã triển khai trong `profile_screen.dart`)**:
  - Bổ sung nút **"Yêu cầu xóa tài khoản"** trong mục Cài đặt tài khoản.
  - Hiển thị hộp thoại cảnh báo rõ ràng về việc xóa dữ liệu.
  - Khi xác nhận, ứng dụng mở ứng dụng Email với tiêu đề và nội dung soạn sẵn gửi về `support@360.org.vn` kèm thông tin tài khoản của người dùng.
  - **Ưu điểm**: Đáp ứng 100% yêu cầu kiểm duyệt của Apple mà không cần viết thêm API backend phức tạp.

---

### LỖI 3: Thiếu liên kết Chính sách Quyền riêng tư (Apple Guideline 5.1.1(i))
* **Quy định Apple**: Phải có đường dẫn rõ ràng dẫn tới Chính sách Quyền riêng tư (Privacy Policy) ở cả trang thông tin App Store Connect và bên trong giao diện ứng dụng.
* **Giải pháp khắc phục (Đã triển khai trong `about_screen.dart`)**:
  - Thêm mục **"Chính sách quyền riêng tư"** trong màn hình Thông tin (About).
  - Khi nhấn, mở trình duyệt tới liên kết chính thức: `https://360.org.vn/privacy`.

---

### LỖI 4: Chuỗi mô tả quyền (Permission Usage Descriptions) không chuẩn
* **Triệu chứng Rejection**: Apple từ chối app nếu chuỗi mô tả trong `Info.plist` không nêu rõ mục đích sử dụng tính năng cụ thể trong app (ví dụ: chỉ ghi "Dùng microphone").
* **Chuẩn hóa chuỗi quyền chuẩn (`ios/Runner/Info.plist`)**:
  ```xml
  <!-- Location -->
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>VCloud uses your location to record check-in and check-out times</string>
  <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
  <string>VCloud uses your location to record check-in and check-out times</string>

  <!-- Camera -->
  <key>NSCameraUsageDescription</key>
  <string>VCloud uses the camera so you can capture and send photos in chat and support tickets.</string>

  <!-- Photo Library -->
  <key>NSPhotoLibraryUsageDescription</key>
  <string>VCloud uses your photo library so you can choose photos for chat and support tickets.</string>
  <key>NSPhotoLibraryAddUsageDescription</key>
  <string>VCloud uses your photo library so you can save photos from chat and support tickets.</string>

  <!-- Microphone -->
  <key>NSMicrophoneUsageDescription</key>
  <string>VCloud uses your microphone to record voice messages and make voice calls.</string>
  ```

---

### LỖI 5: Bị chặn hỏi câu hỏi Mã hóa (Missing Export Compliance)
* **Triệu chứng**: Mỗi khi upload bản build lên TestFlight hoặc App Store, Apple yêu cầu trả lời bảng câu hỏi mã hóa xuất khẩu (Export Compliance Questions).
* **Giải pháp khắc phục**: Khai báo cờ sau trong `ios/Runner/Info.plist`:
  ```xml
  <key>ITSAppUsesNonExemptEncryption</key>
  <false/>
  ```

---

### LỖI 6: Lỗi xác thực 401 khi Upload TestFlight via API Key
* **Triệu chứng**: Upload bằng Fastlane sử dụng App Store Connect API Key (`.p8`) bị trả về `401 Unauthorized` hoặc `Key revoked`.
* **Giải pháp khắc phục**:
  - Cơ chế dự phòng (Fallback) tự động trong `Fastfile` sử dụng Apple App Manager (`xcrun altool`) kết hợp với Apple ID và App-Specific Password:
    ```ruby
    sh("xcrun altool --upload-app --type ios -f \"#{ipa_path}\" -u \"#{apple_id_email}\" -p \"#{app_pass}\" --asc-provider ZC3H8887XS")
    ```
  - Bí mật cần có trong GitHub Secrets: `APPLE_ID` và `APPLE_APP_PASS`.

---

### LỖI 7: Từ chối theo Guideline 2.1.0 - Performance: App Completeness
* **Triệu chứng Rejection**: Apple gửi thông báo: *"Guideline 2.1.0 - Performance - App Completeness: We were unable to review your app because we could not sign in or access full features."*
* **Nguyên nhân**: Apple Reviewers cần một tài khoản kiểm thử hoạt động đầy đủ (Demo / Staging Account) để đăng nhập và kiểm tra toàn diện các module (Chat, Điểm danh, Timesheet, Ticket).
* **Giải pháp khắc phục**:
  1. Trong mục **App Review Information** trên App Store Connect:
     - Tích chọn **"Sign-in required"**.
     - Điền tài khoản demo (Username / Password).
     - Trong mục **Notes**: Cung cấp hướng dẫn ngắn gọn cho Reviewer (ví dụ: *"Use domain demo.vuahethong.com with provided demo credentials. The app connects to Odoo 17 & 19 backend"*).
  2. Đảm bảo server backend và các endpoint Odoo luôn trực tuyến trong suốt thời gian Apple tiến hành duyệt app.

---

## 3. BẰNG CHỨNG KIỂM CHỨNG THÀNH CÔNG (PASSED & SUBMISSION READY)

### Trạng thái thực tế xác thực ngày 29/08/2026:
* **Phiên bản & Bản build**: `iOS App 2.9.0 (97)`
* **Màn hình Draft Submission**: Hiển thị thẻ *"Item Ready to Submit: iOS App 2.9.0 - 2.9.0 (97)"*.
* **Nút hành động**: Nút xanh **"Submit for Review"** đã sáng và sẵn sàng kích hoạt để gửi bản build vào hàng đợi kiểm duyệt của Apple App Store Review Team.
* **Kết luận**: Khắc phục 100% lỗi build bị ẩn/mờ của các bản build 93-96.

---

## 4. QUY TRÌNH KIỂM TRA & XUẤT BẢN BẢN DỰNG MỚI TỪNG BƯỚC (CHECKLIST)

Trước khi gửi bản build mới cho Apple Review, hãy thực hiện theo đúng thứ tự:

| Bước | Nội dung kiểm tra | Tiêu chuẩn đạt |
| :---: | :--- | :--- |
| **1** | Kiểm tra `pubspec.yaml` | `version: X.Y.Z+BUILD` (Số BUILD phải tăng so với bản trước đó) |
| **2** | Kiểm tra `testFlightInternalTestingOnly` | Bắt buộc là `false` trong `Fastfile` & `export_options.plist` |
| **3** | Chạy Static Analysis | `flutter analyze` ➔ 0 errors, 0 warnings |
| **4** | Chạy Unit/Widget Tests | `flutter test` ➔ 100% tests PASS (260/260) |
| **5** | Commit & Push Branch/Main | Tuân thủ Git Trailer `Authored-By: 360org <support@360.org.vn>` |
| **6** | Merge vào `main` | Kích hoạt GitHub Actions (`deploy.yml`) chạy đóng gói và upload |
| **7** | Kiểm tra App Store Connect | Vào `App Store` ➔ Chọn bản build ➔ Kiểm tra App Review Information ➔ Bấm **Submit for Review** |

---

*Tài liệu được cập nhật tự động và lưu trữ tập trung tại `docs/APP_STORE_CONNECT_RELEASE_GUIDE.md`.*
