# Nhật Ký Lỗi & Khắc Phục CI/CD (ERROR.md)

Tài liệu này ghi lại toàn bộ các sự cố kỹ thuật, lỗi CI/CD và giải pháp khắc phục trong quá trình build & deploy hệ sinh thái **VCloud Mobile (Flutter) & Odoo Backend**.

---

## 📌 [ERR-CI-021] — 2026-11-22: 7 Unit Tests Thất Bại Trên GitHub Actions Do Hardcode Env.odooDb

### 1. Triệu chứng (Symptom):
* **Workflow Run**: GitHub Actions run `45038341185` (Release `v2.9.38+201`).
* Cả 2 job `Build & Package Android (APK + AAB)` và `Build & Deploy iOS (TestFlight)` đều bị dừng đỏ ở bước `Run Flutter Static Analysis & Unit Tests` với thông báo:
  ```text
  1312 tests passed, 7 failed.
  Process completed with exit code 1.
  ```

### 2. Danh sách 7 bài test bị Fail:
1. `test/features/chat_v2/chat_v2_channel_and_theme_test.dart`:
   * `TC-10: Env.odooDb mặc định là chuỗi rỗng để kích hoạt Master Router dynamic lookup trên Release` (Expected: `''`, Actual: `'vcloud_test_v19'`).
2. `test/smart_db_resolver_test.dart` (6 cases):
   * `Case 1: Phân giải đúng DB vuahethong khi kết nối https://vuahethong.net`
   * `Case 2: Phân giải đúng DB vuahethong khi kết nối https://www.vuahethong.net`
   * `Case 3: Phân giải đúng DB vuahethong khi kết nối đường dẫn phụ https://vuahethong.net/web/login`
   * `Case 4: Phân giải đúng DB demo khi kết nối https://demo.vuahethong.com`
   * `Case 9: Trả về rỗng (để Odoo server tự resolve), tuyệt đối KHÔNG ép vcloud_test_v19 khi kết nối ndsgroup.vn`
   * `Case 10: Trả về rỗng (để Odoo server tự resolve), tuyệt đối KHÔNG ép vcloud_test_v19 khi kết nối salemoptical.vn`

### 3. Nguyên nhân gốc rễ (Root Cause):
* Trong commit `545c41b` trước đó, khi phát triển tính năng dynamic channel categories trên local, file `lib/core/config/env.dart` đã vô tình bị thay đổi:
  ```dart
  // CŨ (Bị lỗi hardcode):
  static const String odooDb = String.fromEnvironment(
    'VCLOUD_ODOO_DB',
    defaultValue: 'vcloud_test_v19', // <-- Lỗi ép cứng DB test
  );
  ```
* Giá trị mặc định `'vcloud_test_v19'` đã vô hiệu hóa Master Router dynamic lookup, khiến cơ chế Smart DB Resolver luôn trả về `'vcloud_test_v19'` cho mọi domain khách hàng, vi phạm triết lý multi-tenant dynamic lookup.

### 4. Giải pháp khắc phục (Fix Strategy):
* Phục hồi `defaultValue` của `Env.odooDb` về chuỗi rỗng `''` theo đúng quy chuẩn kiến trúc:
  ```dart
  // MỚI (Đã sửa chuẩn):
  static const String odooDb = String.fromEnvironment(
    'VCLOUD_ODOO_DB',
    defaultValue: '',
  );
  ```

### 5. Kết quả kiểm chứng (Verification):
* `flutter analyze --no-fatal-infos`: 0 errors / 0 warnings.
* `flutter test --exclude-tags=live-server`: **1319 / 1319 tests PASSED (100% PASS)**.

---

## 📌 [ERR-CI-022] — 2026-11-22: iOS Fastlane / altool Thất Bại Với Lỗi Cannot determine the Apple ID from Bundle ID 'com.w360s.wcloudapp'

### 1. Triệu chứng (Symptom):
* **Workflow Run**: GitHub Actions run `45039556287` (Release `v2.9.38+201`).
* Job `Build & Package Android (APK + AAB)` thành công 100% và upload lên Google Play Console Production track thành công.
* Job `Build & Deploy iOS (TestFlight)` bị lỗi ở bước `Execute Fastlane iOS TestFlight Pipeline`:
  ```text
  ERROR: [altool.AC4C45000] Cannot determine the Apple ID from Bundle ID 'com.w360s.wcloudapp' and platform 'IOS'. (19)
  ERROR: [altool.10120EDC0] ExitFailure (31)
  The call to the altool completed with a non-zero exit status: 1. This indicates a failure.
  Could not download/upload from App Store Connect!
  ```

### 2. Nguyên nhân gốc rễ (Root Cause Analysis):
1. **Tên file IPA chứa ký tự tiếng Việt có dấu và khoảng trắng**: File IPA do Flutter build ra là `Vua Hệ Thống.ipa`. Khi `altool` và các parser bên dưới xử lý đường dẫn chứa ký tự unicode tổ hợp/khoảng trắng, luồng đọc package metadata của `altool` bị lỗi hoặc parse sai identifier.
2. **Thiếu tham số định danh App Store Connect cho `altool`**:
   * Khi `upload_to_testflight` gọi `altool` ngầm, hoặc khi Fastfile gọi fallback `xcrun altool --upload-app`, lệnh không truyền tường minh `--apple-id 1365622472` và `--bundle-id com.w360s.wcloudapp`.
   * Lệnh fallback cũ truyền `--asc-provider ZC3H8887XS` (Team ID thay vì Provider Short Name), khiến Apple altool không ánh xạ được Bundle ID sang đúng tài khoản ứng dụng trong môi trường đa tài khoản/nhà cung cấp.
3. **Thư mục tìm kiếm khóa API Key `.p8`**: `altool` chỉ quét khóa tại `~/.appstoreconnect/private_keys`, `~/.private_keys` hoặc biến môi trường `API_PRIVATE_KEYS_DIR`. Việc chỉ ghi file vào `Dir.tmpdir` khiến `altool` không tìm thấy khóa khi gọi độc lập.

### 3. Giải pháp khắc phục (Fix Strategy):
1. **Chuẩn hóa đường dẫn file IPA sang chuẩn ASCII**: Tự động sao chép IPA sang `vcloud-release.ipa` (không dấu, không khoảng trắng) trước khi gọi bất kỳ công cụ upload nào.
2. **Khai báo khóa `.p8` chuẩn hóa**: Tự động ghi `AuthKey_<KEY_ID>.p8` vào `~/.appstoreconnect/private_keys`, `~/.private_keys` và thiết lập `API_PRIVATE_KEYS_DIR`.
3. **Bổ sung tham số tương thích `DELIVER_ALTOOL_ADDITIONAL_UPLOAD_PARAMETERS`**: Thiết lập `--use-old-altool --apple-id 1365622472` cho Fastlane deliver/pilot.
4. **Chuẩn hóa 4 tầng Fallback trong Fastfile**:
   * *Tầng A*: `xcrun altool --upload-package` hiện đại với đầy đủ `--apple-id 1365622472 --bundle-id com.w360s.wcloudapp --bundle-version 201 --bundle-short-version-string 2.9.38`.
   * *Tầng B*: `xcrun altool --upload-app` có gắn kèm tường minh `--apple-id 1365622472` (bỏ cờ `--asc-provider` gây lệch team).
   * *Tầng C*: `xcrun altool --use-old-altool` chế độ tương thích cũ.
   * *Tầng D*: Fastlane `upload_to_testflight` với `username` và `app_identifier`.
5. **Củng cố script `appstore_distribute_and_submit.py`**: Chuẩn hóa regex giải mã Base64 và xử lý ký tự xuống dòng `\n` trong private key, tự động tra cứu thêm tại `~/.private_keys` và `~/.appstoreconnect/private_keys`.

### 4. Kết quả kiểm chứng (Verification):
* `fastlane/Fastfile` và `scripts/appstore_distribute_and_submit.py` đã được cập nhật chuẩn hóa.
* Commit và push lên GitHub `main`, kích hoạt lại workflow và theo dõi cho tới khi App Store Connect đạt trạng thái `Waiting for Review` và Google Play Console upload thành công.
