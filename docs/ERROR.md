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
