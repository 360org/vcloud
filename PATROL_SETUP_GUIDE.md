# 🚀 HƯỚNG DẪN CẤU HÌNH PATROL CLI & E2E TEST (PATROL SETUP GUIDE)

Tài liệu này hướng dẫn chi tiết quy trình thiết lập môi trường kiểm thử tự động Native UI & End-to-End (E2E) bằng **Patrol** cho dự án **VCloud Mobile (`vclients`)**. Áp dụng đồng bộ cho cả môi trường máy của anh Tân và các phiên làm việc của AI Agent (Antigravity / Claude Code / Codex).

---

## I. CÀI ĐẶT PATROL CLI (GLOBAL SETUP)

### 1. Kích hoạt Patrol CLI toàn cục
Mở Terminal và thực thi lệnh kích hoạt thông qua Dart SDK:
```bash
dart pub global activate patrol_cli
```

### 2. Cấu hình biến môi trường PATH
Để Terminal nhận diện được lệnh `patrol` trực tiếp, cần đảm bảo thư mục `.pub-cache/bin` đã được thêm vào biến môi trường `PATH`.

#### 🔹 Trên macOS / Linux (Zsh / Bash):
Mở file cấu hình shell (`~/.zshrc` hoặc `~/.bashrc`) và thêm dòng sau:
```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
```
Sau đó nạp lại cấu hình:
```bash
source ~/.zshrc  # Hoặc source ~/.bashrc
```

#### 🔹 Trên Windows (PowerShell / System Environment):
1. Nhấn `Win + R`, gõ `sysdm.cpl` và nhấn Enter.
2. Chọn tab **Advanced** ➔ Bấm nút **Environment Variables**.
3. Tại mục **User variables**, tìm biến `Path` ➔ Bấm **Edit** ➔ **New** và thêm đường dẫn:
   ```text
   %LOCALAPPDATA%\Pub\Cache\bin
   ```
4. Lưu lại và khởi động lại Terminal / VS Code.

#### 🔍 Kiểm tra cài đặt thành công:
```bash
patrol --version
patrol doctor
```

---

## II. CẤU HÌNH TÍCH HỢP VÀO DỰ ÁN FLUTTER (`vclients`)

### 1. Khai báo dependencies trong `pubspec.yaml`
Thêm package `patrol` vào mục `dev_dependencies`:
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  patrol: ^3.7.0 # Sử dụng phiên bản ổn định mới nhất
```
Sau đó chạy lệnh:
```bash
flutter pub get
```

### 2. Thiết lập file cấu hình `patrol.toml`
Tạo file `patrol.toml` đặt tại thư mục gốc của Flutter (`vclients/patrol.toml`):
```toml
[patrol]
app_name = "VCloud"
android.package_name = "com.w360s.wcloudapp"
ios.bundle_id = "com.w360s.wcloudapp"

[test]
# Tự động cấp quyền hệ thống (Camera, Microphone, Location, Notifications)
permissions.enabled = true
```

---

## III. THIẾT LẬP ĐẶC THÙ CHO TỪNG NỀN TẢNG (PLATFORM SETUP)

### 1. Cấu hình Android (`android/app/build.gradle.kts`)
Dự án `vclients` sử dụng Kotlin DSL (`build.gradle.kts`). Cấu hình như sau:

1. Thêm cấu hình Test Instrumentation Runner vào khối `defaultConfig`:
   ```kotlin
   android {
       ...
       defaultConfig {
           applicationId = "com.w360s.wcloudapp"
           minSdk = flutter.minSdkVersion
           targetSdk = 34
           versionCode = flutter.versionCode
           versionName = flutter.versionName
           multiDexEnabled = true
           
           // Khai báo Patrol JUnit Test Runner
           testInstrumentationRunner = "patrol.PatrolJUnitRunner"
           testInstrumentationRunnerArguments["clearPackageData"] = "true"
       }
   }
   ```

2. Thêm các dependencies kiểm thử cần thiết vào cuối file:
   ```kotlin
   dependencies {
       androidTestImplementation("androidx.test:runner:1.5.2")
       androidTestImplementation("androidx.test:rules:1.5.0")
       androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
       androidTestImplementation("androidx.test.uiautomator:uiautomator:2.2.0")
   }
   ```

*(Lưu ý: Nếu sử dụng file `build.gradle` dạng Groovy truyền thống, cú pháp tương ứng là `testInstrumentationRunner "patrol.PatrolJUnitRunner"`).*

---

### 2. Cấu hình iOS (XCTest UI Runner)
1. Di chuyển vào thư mục gốc `vclients` và chạy lệnh khởi tạo tự động của Patrol:
   ```bash
   patrol bootstrap
   ```
   *Lệnh này sẽ tự động sinh file `RunnerUITests.m` / `RunnerUITests.swift` trong thư mục `ios/RunnerUITests`.*

2. **Cấu hình trên Xcode (Thực hiện 1 lần duy nhất)**:
   * Mở workspace iOS: `open ios/Runner.xcworkspace`.
   * Chọn `Runner` ở cây thư mục bên trái ➔ Tab **Build Settings** ➔ Tìm kiếm `Product Bundle Identifier`.
   * Đảm bảo target `RunnerUITests` có Bundle Identifier là: `com.w360s.wcloudapp.RunnerUITests`.
   * Chọn scheme `Runner` ➔ **Edit Scheme...** ➔ Mục **Test** ➔ Đảm bảo `RunnerUITests` đã được tích chọn.

---

## IV. KỊCH BẢN KIỂM THỬ MẪU & LỆNH THỰC THI (SMOKE TEST)

### 1. Viết kịch bản Test mẫu (`integration_test/example_test.dart`)
Tạo file `integration_test/example_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:vcloud/main.dart' as app;

void main() {
  patrolTest(
    'Smoke Test: Khởi động app và kiểm tra màn hình đăng nhập / chat',
    ($) async {
      // Khởi chạy ứng dụng
      app.main();
      await $.pumpAndSettle();

      // Kiểm tra sự tồn tại của Widget chính
      expect($('VCloud'), findsWidgets);

      // Tự động cấp quyền native nếu popup xuất hiện
      if (await $.native.isPermissionDialogVisible()) {
        await $.native.grantPermissionWhenInUse();
      }
    },
  );
}
```

### 2. Lệnh chạy kiểm thử thực tế trên Máy ảo / Thiết bị thật
* **Chạy kiểm thử trên thiết bị đang kết nối:**
  ```bash
  patrol test -t integration_test/example_test.dart
  ```
* **Chạy toàn bộ bộ test:**
  ```bash
  patrol test
  ```

---

## V. KHUNG ĐẶC TẢ /spec BẮT BUỘC CHO MỖI TÍNH NĂNG (SPEC TEST CONTRACT)

> [!IMPORTANT]
> **QUY TẮC KỶ LUẬT CHO AGENT (STRICT TEST CONTRACT)**:
> Mọi file `SPEC.md` khi thiết kế tính năng mới hoặc sửa lỗi (Bug fix) **BẮT BUỘC** phải có mục **VI. KIỂM THỬ VÀ XÁC MINH THỰC TẾ** theo đúng chuẩn dưới đây. CẤM báo cáo PASS nếu chưa chạy lệnh Terminal thực tế.

```markdown
## VI. KIỂM THỬ VÀ XÁC MINH THỰC TẾ (STRICT TEST CONTRACT)

Để hoàn thành Cổng 6 (/test), Agent bắt buộc phải viết các bài test đáp ứng 100% rào chắn kỹ thuật dưới đây. Tuyệt đối không được phép báo cáo PASS khi chưa chạy lệnh Terminal thực tế.

### 1. Ranh giới Giả lập (Mocking Boundaries)
- **Được phép Mock:** Các kết nối HTTP thực tế sang Google Firebase Messaging hoặc Odoo API (để tránh bão request mạng và chạy test offline mượt mà).
- **CẤM Mock:** Logic xử lý trạng thái của Riverpod Notifiers, logic chuyển đổi JSON sang Model dữ liệu. Các thành phần này bắt buộc phải test bằng dữ liệu thực tế (Real-State Testing).

### 2. Kịch bản Test bắt buộc (Mandatory Test Cases)
- **TC-01 (Mở màn hình):** Khởi chạy màn hình tính năng ➔ Trạng thái mặc định phải hiển thị đúng giao diện ban đầu (ví dụ: Button "Nhận cuộc gọi" phải ở trạng thái disable nếu chưa có cuộc gọi).
- **TC-02 (Luồng thành công - Happy Path):** Nhận sự kiện FCM giả lập ➔ Giao diện phải tự động chuyển sang màn hình cuộc gọi đến ➔ Click "Đồng ý" ➔ Trạng thái Riverpod chuyển sang 'connected'.
- **TC-03 (Luồng lỗi - Edge Case):** Server Odoo trả về lỗi `403 Forbidden` ➔ Flutter phải bắt được lỗi và hiển thị Dialog cảnh báo "Không có quyền truy cập".

### 3. Lệnh thực thi Test thực tế (CLI Verification Commands)
*Agent bắt buộc phải chạy các lệnh này dưới Terminal máy và chụp lại log kết quả dán vào báo cáo chat:*
- Chạy phân tích cú pháp (Không được có bất kỳ Warning/Error nào):
  ```bash
  flutter analyze
  ```
- Chạy bộ kiểm thử tự động của tính năng:
  ```bash
  flutter test test/features/<feature>/<feature>_test.dart
  ```

### 4. Kết quả mong đợi trong Console Log (Expected Test Output)
✓ Khởi chạy màn hình tính năng thành công
✓ Nhận sự kiện FCM giả lập và hiển thị cuộc gọi đến
✓ Hiển thị cảnh báo khi Odoo trả về lỗi 403
All 3 tests passed!
```
