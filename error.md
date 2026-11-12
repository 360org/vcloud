# 📘 SỔ CÁI LỖI CI/CD, PHÁT HÀNH & THIẾT BỊ DI ĐỘNG (error_mobile.md)
# Single Source of Truth: Danh mục lỗi đã ghi nhận, nguyên nhân gốc rễ và bài học phòng tránh
# Phiên bản: v3.1.0 | Áp dụng: VCloud Mobile Client (vclients) & Fastlane / GitHub Actions
# Symlinks: error . md -> error_mobile . md | vclients/error_mobile . md -> ../error_mobile . md

================================================================================
🏛️ I. NGUYÊN TẮC CỐT LÕI (PRE-FLIGHT ERROR AUDIT MANDATORY)
🚨 **LUẬT THÉP BẢO VỆ PIPELINE**:
1. Trước BẤT KỲ đợt tạo Release hay kích hoạt CI/CD nào (theo `release . md`), Agent **BẮT BUỘC ĐỌC FILE NÀY ĐẦU TIÊN** để rà soát toàn bộ mã nguồn, cấu hình và changelog, đảm bảo không tái phạm bất kỳ lỗi nào trong danh mục.
2. Mỗi khi GitHub Actions hoặc Fastlane bị **FAIL (ĐỎ)**:
   - Agent **BẮT BUỘC** trích xuất log lỗi qua `gh run view <run_id> --log-failed`.
   - Phân tích nguyên nhân gốc rễ (Root Cause), KHÔNG sửa mò.
   - **GHI NGAY LỖI MỚI VÀO SỔ CÁI NÀY** theo mã định danh tăng dần `[ERR-xxx]` kèm hiện tượng, nguyên nhân và giải pháp triệt để trước khi thử lại.

================================================================================
📊 II. MA TRẬN 10 LỖI KINH ĐIỂN ĐÃ GHI NHẬN (KNOWN ERRORS CATALOG)

| Mã Lỗi | Hạng Mục / Thành Phần | Tên Lỗi & Hiện Tượng | Trọng Yếu | Tình Trạng |
|---|---|---|:---:|:---:|
| **ERR-001** | Fastlane Android Metadata | Mã ngôn ngữ Tiếng Việt `vi-VN` / `default` bị từ chối | 🚨 CRITICAL | ✅ ĐÃ KHẮC PHỤC |
| **ERR-002** | Google Play API | Độ dài Changelog ("Có gì mới") vượt quá 500 ký tự | 🚨 CRITICAL | ✅ ĐÃ KHẮC PHỤC |
| **ERR-003** | Version & Build Number | Lệch số Build giữa `pubspec.yaml` và `github.run_number` | 🚨 CRITICAL | ✅ ĐÃ KHẮC PHỤC |
| **ERR-004** | Dart Linter / Static Analysis | Lỗi `unawaited_return_in_try_block` chặn CI/CD | 🚨 CRITICAL | ✅ ĐÃ KHẮC PHỤC |
| **ERR-005** | Apple App Store Connect | Lỗi 90186 Đóng Release Train (`Invalid Pre-Release Train`) | 🚨 CRITICAL | ✅ ĐÃ KHẮC PHỤC |
| **ERR-006** | GitHub Actions Workflow | Timeout ở bước phụ `Auto-Distribute to App Store` | ⚠️ MEDIUM | ✅ ĐÃ KHẮC PHỤC |
| **ERR-007** | Android Gradle Build | Thiếu Java 8 Core Library Desugaring khi build .aab | 🚨 CRITICAL | ✅ ĐÃ KHẮC PHỤC |
| **ERR-008** | Fastlane Supply | Không tìm thấy file `app-release.aab` do sai đường dẫn | 🚨 CRITICAL | ✅ ĐÃ KHẮC PHỤC |
| **ERR-009** | Git Tag & Release | Xung đột Tag cũ hoặc trùng lặp số build trên remote | ⚠️ HIGH | ✅ ĐÃ KHẮC PHỤC |
| **ERR-010** | Branch Protection | Push thẳng vào nhánh bảo vệ `main` bị từ chối | 🚨 CRITICAL | ✅ ĐÃ KHẮC PHỤC |
| **ERR-011** | Flutter Unit Tests / Auth & Notifs | Hardcoded 'db' trong master auth và thiếu eventType trong portal filter | 🚨 CRITICAL | ✅ ĐÃ KHẮC PHỤC |
| **ERR-012** | GitHub Actions / Flutter Version | Không ghim Flutter version & `flutter analyze` dính lỗi fatal infos deprecation | 🚨 CRITICAL | ✅ ĐÃ KHẮC PHỤC |

================================================================================
🔍 III. CHI TIẾT NGUYÊN NHÂN GỐC RỄ & CÁCH PHÒNG TRÁNH TỪNG LỖI

### 🔴 [ERR-001] MÃ NGÔN NGỮ TIẾNG VIỆT TRÊN FASTLANE / GOOGLE PLAY API
- **Hiện tượng**: Fastlane báo lỗi `[!] vi-VN - Invalid request` hoặc `[!] default - Invalid request`. Kênh `en-US` tải lên thành công nhưng toàn bộ release notes tiếng Việt bị Google từ chối.
- **Nguyên nhân gốc rễ**:
  * Google Play Developer API và Fastlane Supply (`supply/lib/supply/languages.rb`) chỉ chấp nhận mã 2 ký tự `"vi"` cho Tiếng Việt. Google không có mã `"vi-VN"` hay `"default"`.
- **Giải pháp phòng tránh**:
  * Trong `fastlane/Fastfile`: Luôn cấu hình:
    ```ruby
    locales = (ENV["PLAY_STORE_LOCALES"] || "vi,en-US").split(",").map(&:strip)
    ```
  * Thư mục metadata: `fastlane/metadata/android/vi/changelogs/<build_number>.txt` và `fastlane/metadata/android/en-US/changelogs/<build_number>.txt`.
  * Trước khi sinh changelog mới, luôn gọi `FileUtils.rm_rf(metadata_base)` để xóa sạch thư mục cũ.

---

### 🔴 [ERR-002] GIỚI HẠN ĐỘ DÀI CHANGELOG TRÊN GOOGLE PLAY API
- **Hiện tượng**: Upload `.aab` thành công nhưng API nạp release notes văng lỗi HTTP 400 Bad Request.
- **Nguyên nhân gốc rễ**:
  * Google Play API áp đặt giới hạn cứng tối đa 500 ký tự UTF-8 cho mỗi ngôn ngữ. Nếu file changelog dài hơn hoặc chứa ký tự đặc biệt, Google sẽ từ chối toàn bộ request.
- **Giải pháp phòng tránh**:
  * Hàm trích xuất changelog tự động từ `docs/CHANGELOGS . md` phải lọc bỏ định dạng markdown (`**`, ```, `>`) và khống chế cứng `<= 480 ký tự`:
    ```ruby
    clean_text = raw_text.gsub(/[*`>#]/, '').strip
    final_text = clean_text[0...480]
    ```

---

### 🔴 [ERR-003] LỆCH SỐ BUILD NUMBER GIỮA PUBSPEC.YAML VÀ GITHUB.RUN_NUMBER
- **Hiện tượng**: Sếp Tân đặt version `2.9.25+179` trong `pubspec.yaml`, nhưng TestFlight và CH Play lại nhận số `(124)` từ biến môi trường `github.run_number`.
- **Nguyên nhân gốc rễ**:
  * Fastfile cũ cấu hình `build_number = ENV["BUILD_NUMBER"] || version_parts[1]`. Khi workflow truyền `BUILD_NUMBER: ${{ github.run_number }}`, biến môi trường ghi đè lên số build thật trong code.
- **Giải pháp phòng tránh**:
  * **`pubspec.yaml` là Nguồn Chân Lý Duy Nhất (SSOT)**:
  * Trong `fastlane/Fastfile`: Luôn đọc trực tiếp từ `pubspec.yaml`:
    ```ruby
    pubspec = YAML.load_file(File.expand_path("../pubspec.yaml", __dir__))
    version_parts = pubspec["version"].to_s.split("+")
    build_number = version_parts[1] # BẮT BUỘC ưu tiên pubspec
    ```
  * CẤM dùng `github.run_number` để ghi đè số build của ứng dụng.

---

### 🔴 [ERR-004] LỖI DART LINTER `unawaited_return_in_try_block` CHẶN CI/CD
- **Hiện tượng**: Chạy local không thấy crash nhưng khi đẩy lên GitHub Actions, bước `flutter analyze` báo cảnh báo `unawaited_return_in_try_block` và làm fail toàn bộ workflow với exit code 1.
- **Nguyên nhân gốc rễ**:
  * Trong hàm `async`, dòng lệnh `return _send(...)` nằm trong khối `try { ... } catch (e) { ... }` nhưng quên từ khóa `await`. Khi Future ném lỗi, khối catch không bắt được mà văng ra ngoài, làm vô hiệu hóa cơ chế xử lý lỗi.
- **Giải pháp phòng tránh**:
  * Luôn viết `return await _send(...);` khi trả về một `Future` bên trong khối `try/catch`.
  * Trước khi release, bắt buộc chạy `flutter analyze` ở local và bảo đảm đạt 0 issues.

---

### 🔴 [ERR-005] LỖI ĐÓNG RELEASE TRAIN TRÊN APPLE APP STORE CONNECT (ERROR 90186)
- **Hiện tượng**: Fastlane tải IPA lên TestFlight bị Apple từ chối với mã lỗi: `Error 90186: Invalid Pre-Release Train. The train version has been closed for new build submissions.`
- **Nguyên nhân gốc rễ**:
  * Marketing Version hiện tại (ví dụ `2.9.22`) đã được Sếp Tân gửi Apple xét duyệt (Submit for Review) hoặc đã được phê duyệt phát hành. Khi một train đã đóng, Apple không cho phép nộp thêm bất kỳ build number nào mới vào train đó nữa.
- **Giải pháp phòng tránh**:
  * Khi Apple đóng train cũ, việc chỉ tăng build number `+170` là vô hiệu.
  * **BẮT BUỘC BUMP MARKETING VERSION**: Tăng version trong `pubspec.yaml` (ví dụ từ `2.9.25` lên `2.9.26`) để mở một Release Train mới trên App Store Connect.

---

### 🔴 [ERR-006] TIMEOUT OAN Ở BƯỚC PHỤ `Auto-Distribute to App Store`
- **Hiện tượng**: File IPA đã lên TestFlight thành công, nhưng bước tự động tạo version và gửi duyệt App Store bị Apple delay xử lý (`PROCESSING` 10-15 phút) dẫn đến timeout và làm đỏ toàn bộ workflow GitHub Actions.
- **Nguyên nhân gốc rễ**:
  * Apple mất thời gian quét virus/mã độc của IPA trước khi cho phép gắn vào phiên bản App Store. Script đợi quá lâu bị GitHub Runner hủy task.
- **Giải pháp phòng tránh**:
  * Trong `.github/workflows/deploy.yml`: Luôn giữ `continue-on-error: true` cho bước `Auto-Distribute to App Store`:
    ```yaml
    - name: Auto-Distribute to App Store & Submit for Review
      continue-on-error: true
      run: bundle exec fastlane ios distribute_appstore
    ```
  * Đảm bảo luồng TestFlight và Google Play được bảo vệ hoàn tất xanh 100%.

---

### 🔴 [ERR-007] THIẾU CORE LIBRARY DESUGARING TRÊN ANDROID GRADLE
- **Hiện tượng**: `flutter build appbundle` thất bại do các thư viện hiện đại (`flutter_local_notifications`) sử dụng các API Java 8+ (`java.time.LocalDateTime`).
- **Nguyên nhân gốc rễ**:
  * Trình biên dịch Android D8 yêu cầu kích hoạt desugaring để tương thích ngược với các thiết bị Android cũ.
- **Giải pháp phòng tránh**:
  * Trong `android/app/build.gradle.kts`: Luôn có:
    ```kotlin
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    dependencies {
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    }
    ```

---

### 🔴 [ERR-008] FASTLANE KHÔNG TÌM THẤY TỆP `app-release.aab`
- **Hiện tượng**: Fastlane báo lỗi `[!] Could not find aab file at path '../build/app/outputs/bundle/release/app-release.aab'`.
- **Nguyên nhân gốc rễ**:
  * Thư mục thực thi của runner GitHub Actions có thể thay đổi giữa root workspace và thư mục `fastlane/`, khiến đường dẫn tương đối bị trỏ sai.
- **Giải pháp phòng tránh**:
  * Dùng mảng ứng viên với `File.expand_path` trong `Fastfile`:
    ```ruby
    candidates = [
      File.expand_path("../build/app/outputs/bundle/release/app-release.aab", __dir__),
      File.expand_path("build/app/outputs/bundle/release/app-release.aab", Dir.pwd),
      File.expand_path("../build/app/outputs/bundle/release/app-release.aab", Dir.pwd)
    ]
    aab_path = candidates.find { |p| File.exist?(p) }
    ```

---

### 🔴 [ERR-009] XUNG ĐỘT GIT TAG & RELEASE TRÙNG LẶP SỐ BUILD
- **Hiện tượng**: Đẩy tag lên GitHub báo lỗi `! [rejected] v2.9.25+179 -> v2.9.25+179 (already exists)`.
- **Nguyên nhân gốc rễ**:
  * Dev/AI quên tăng số Build Number trong `pubspec.yaml` trước khi chạy script release, dẫn đến việc tạo lại tag đã có trên GitHub.
- **Giải pháp phòng tránh**:
  * Luôn kiểm tra danh sách tag remote trước khi tạo: `git tag -l "v*"` hoặc `git ls-remote --tags github`.
  * Mỗi lần release BẮT BUỘC tăng số build `+1` (ví dụ: `179` ➔ `180`).

---

### 🔴 [ERR-010] PUSH TRỰC TIẾP VÀO NHÁNH BẢO VỆ (`main`, `17.0`, `19.0`)
- **Hiện tượng**: `git push github main` bị từ chối với thông báo `protected branch hook declined`.
- **Nguyên nhân gốc rễ**:
  * Quy tắc bảo vệ nhánh (Branch Protection Rule) trên GitHub/GitLab cấm push trực tiếp.
- **Giải pháp phòng tránh**:
  * Tuân thủ [git.md](git.md): Luôn đẩy lên nhánh task `feat/app-build<N>-...` ➔ Tạo PR ➔ Merge vào `main` ➔ Khi merge xong thì gắn Tag `v*` để kích hoạt workflow.

---

### 🔴 [ERR-011] LỖI MASTER AUTH INJECT 'db' VÀ THIẾU EVENT TYPE PORTAL TRÊN FLUTTER TEST
- **Hiện tượng**: Bước CI/CD `Run Flutter Static Analysis & Unit Tests` thất bại (exit code 1) với 4 unit tests đỏ trên GitHub Actions runner.
  * `odoo_api_client_auth_test.dart`: Gửi thừa map key `'db': 'vcloud_test_v19'` vào request body tới master resolver `/api/v1/mobile/auth/login` và `/api/v1/auth/login`.
  * `reference_ui_widgets_test.dart`: `MobileNotificationSheet` không tìm thấy `Team VCloud` và `Máy in lỗi` do `_portalAllowedEvents` chỉ chứa `ticket`, `ticket_message`, `livechat`, `system`, lọc mất thông báo có `eventType: 'message'` và `'ticket_assigned'`.
- **Nguyên nhân gốc rễ**:
  * Trong `OdooApiClient._tryFullLoginAt`, `dbName` tự động fallback về `Env.odooDb` (`vcloud_test_v19`) cho mọi target URL thay vì chỉ áp dụng khi kết nối máy chủ test cục bộ (`Env.odooApiBaseUrl` / `192.168.1.100` / `localhost`). Trong `_loginMasterAdmin`, `'db': Env.odooDb` bị hardcode vào payload đăng nhập master admin.
  * Trong `MobileNotificationSheet`, danh sách `_portalAllowedEvents` thiếu `message` (chat) và `ticket_assigned`.
- **Giải pháp phòng tránh**:
  * Trong `_tryFullLoginAt`: Chỉ fallback về `Env.odooDb` khi `targetBaseUrl` là server local/test (`targetBaseUrl == Env.odooApiBaseUrl || targetBaseUrl.contains('192.168.1.100') || targetBaseUrl.contains('localhost') || targetBaseUrl.contains('127.0.0.1')`), các URL master/tenant khác không tự ý inject `'db'`. Trong `_loginMasterAdmin`: chỉ gửi `db` nếu được truyền tường minh.
  * Bổ sung `'message'` và `'ticket_assigned'` vào `_portalAllowedEvents` trong `MobileNotificationSheet` và `HomeScreen`.

---

### 🔴 [ERR-012] KHÔNG GHIM FLUTTER VERSION TRÊN CI/CD & `flutter analyze` THOÁT EXIT CODE 1 DO DEPRECATION
- **Hiện tượng**: Bước CI/CD `Run Flutter Static Analysis & Unit Tests` (Run 43146557074) thất bại với exit code 1 trên cả 2 job iOS và Android, xuất hiện 151 dòng cảnh báo `info • 'package:flutter/material.dart' is deprecated and shouldn't be used. Use package:material_ui/material_ui.dart instead. This feature was deprecated after v3.47.0-0.0.pre...`.
- **Nguyên nhân gốc rễ**:
  * Trong `.github/workflows/deploy.yml`, bước cài đặt Flutter dùng `subosito/flutter-action@v2` với cấu hình unpinned `channel: "stable"`. Khi Google cập nhật nhánh stable lên Flutter 3.50.0 (mới hơn phiên bản Flutter 3.44.7 chuẩn của dự án), trình biên dịch Dart phát sinh hàng loạt deprecation notice cho `material.dart`.
  * Lệnh chạy linter `flutter analyze` không có cờ `--no-fatal-infos`, khiến runner GitHub Actions coi các thông báo info deprecation là lỗi nghiêm trọng và thoát với exit code 1, làm dừng toàn bộ pipeline trước khi kịp chạy `flutter test`.
- **Giải pháp phòng tránh**:
  * Trong `.github/workflows/deploy.yml`: Ghim cứng `flutter-version: "3.44.7"` (đồng bộ 100% với môi trường chuẩn trong `CLAUDE.md` và máy phát triển cục bộ) cho cả 2 job `build-ios-testflight` và `build-android-release`.
  * Bổ sung cờ `--no-fatal-infos` vào lệnh kiểm tra tĩnh: `flutter analyze --no-fatal-infos && flutter test --exclude-tags=live-server`.
  * Cấu hình an toàn trong `analysis_options.yaml`: Bổ sung `deprecated_member_use: info` dưới mục `analyzer.errors`.

================================================================================
🛠️ IV. QUY TRÌNH GHI NHẬN LỖI MỚI KHI GITHUB ACTIONS BỊ FAIL (SELF-HEALING)
Khi Agent theo dõi GitHub Actions (`gh run watch`) và phát hiện workflow bị **ĐỎ (FAILED)**:
1. **Lấy Run ID**: `RUN_ID=$(gh run list --workflow=deploy.yml --limit=1 --json databaseId -q '.[0].databaseId')`
2. **Xem log lỗi thất bại**: `gh run view "$RUN_ID" --log-failed`
3. **Phân tích Root Cause**:
   - Xác định rõ lỗi thuộc tầng nào: Linter Dart, Flutter Test, Fastlane Android, Fastlane iOS, hay Apple/Google API credentials.
4. **Cập nhật ngay vào file này (`error_mobile.md`)**:
   - Thêm mục mới `### 🔴 [ERR-xxx] <TÊN LỖI>` với đầy đủ:
     * Hiện tượng & trích dẫn log lỗi.
     * Nguyên nhân gốc rễ.
     * Giải pháp phòng tránh / sửa code.
5. **Khắc phục mã nguồn & Tái nạp**:
   - Sửa lỗi trong code / config.
   - Tăng tiếp Build Number (+1).
   - Commit & Push re-release theo [release.md](release.md).
