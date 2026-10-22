# CẨM NANG TOÀN DIỆN CI/CD VẬN HÀNH TỰ ĐỘNG HÓA VCLOUD MOBILE (ANDROID & IOS)
### (Google Play Production Track & Apple App Store Distribution + Auto-Submit Review)

> 📌 **Mục đích tài liệu (SSOT)**: Tài liệu này lưu trữ đầy đủ 100% quy trình, kiến trúc file, cấu hình bảo mật, mã lệnh và cơ chế tự động hóa phân phối ứng dụng Vcloud lên hai cửa hàng **Google Play Store** và **Apple App Store**. Bất kỳ AI Agent nào chỉ cần đọc file này là có thể tái hiện và vận hành toàn bộ luồng phát hành từ A tới Z mà không cần xây dựng lại từ đầu.

---

## 1. BẢN ĐỒ CÁC FILE LIÊN QUAN TRONG DỰ ÁN (FILE COORDINATES)

| Thành phần | Đường dẫn File | Vai trò |
|---|---|---|
| **CI/CD Pipeline Workflow** | `.github/workflows/deploy.yml` | Workflow GitHub Actions điều phối runner Ubuntu (Android) & macOS (iOS). |
| **Fastlane Lane Controller** | `fastlane/Fastfile` | Chứa lane `android beta` (AAB + Play Store) và `ios beta` (IPA + TestFlight). |
| **Fastlane App Info** | `fastlane/Appfile` | Cấu hình App ID, Team ID, Bundle Identifier cho Apple & Android. |
| **App Store Distribution & Auto-Submit** | `scripts/appstore_distribute_and_submit.py` | Tool Python độc lập tương tác App Store Connect REST API: Tạo version, gắn build, sync What's New và submit duyệt. |
| **Version SSOT** | `pubspec.yaml` | Nguồn chân lý duy nhất quy định `version: X.Y.Z+BUILD` (VD: `2.9.22+167`). |
| **Changelogs / Release Notes** | `docs/CHANGELOGS.md` | Nguồn trích xuất tự động mô tả tính năng mới cho Google Play và App Store. |
| **Android Keystore Sign Config** | `android/key.properties` (sinh động) & `android/app/build.gradle` | Cấu hình ký số bản phát hành Android. |
| **iOS Export Options** | `ios/export_options.plist` (sinh động) & `ios/Runner.xcodeproj` | Cấu hình signing identity manual và profile phân phối App Store. |
| **Tệp khóa bảo mật Local** | `/media/tanma/DATA/save/file_ios_p8/AuthKey_3J68D9JX79.p8` | Khóa Apple Team Key dùng cho thao tác local và backup khẩn cấp. |

---

## 2. QUY TRÌNH CI/CD ANDROID (GOOGLE PLAY CONSOLE) TỰ ĐỘNG

### 2.1. Danh Sách GitHub Secrets Bắt Buộc Cho Android
| Tên Secret | Ý nghĩa / Giá trị |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Nội dung file keystore `upload-keystore.jks` được mã hóa Base64. |
| `ANDROID_KEYSTORE_PASSWORD` | Mật khẩu truy cập keystore. |
| `ANDROID_KEY_ALIAS` | Alias của khóa ký số trong keystore (VD: `vcloud-key` hoặc alias chỉ định). |
| `ANDROID_KEY_PASSWORD` | Mật khẩu của khóa ký số. |
| `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` | Toàn bộ chuỗi JSON của Google Cloud Service Account có quyền phát hành trên Google Play Console. |
| `GOOGLE_PLAY_TRACK` | Track phân phối trên Google Play (`production`, `beta`, hoặc `internal`). Mặc định: `production`. |

### 2.2. Luồng Thực Thi Tự Động Của Android (Job: `build-android-release`)
1. **Khởi tạo Môi trường**: Runner `ubuntu-latest`, setup Java 17, Flutter stable, Ruby 3.3.
2. **Kiểm tra chất lượng mã nguồn**: `flutter analyze` và `flutter test --exclude-tags=live-server`.
3. **Giải mã Keystore & Tạo key.properties**:
   ```bash
   echo "$ANDROID_KEYSTORE_BASE64" | base64 --decode > android/upload-keystore.jks
   cat <<EOF > android/key.properties
   storePassword=$ANDROID_KEYSTORE_PASSWORD
   keyPassword=$ANDROID_KEY_PASSWORD
   keyAlias=$ANDROID_KEY_ALIAS
   storeFile=../upload-keystore.jks
   EOF
   ```
4. **Đóng gói Binary**:
   - Universal APK: `flutter build apk --release --build-name=X.Y.Z --build-number=BUILD`
   - Android App Bundle (AAB): `flutter build appbundle --release --build-name=X.Y.Z --build-number=BUILD`
5. **Trích xuất Changelogs Đa Ngôn Ngữ**:
   - Fastlane đọc mục phiên bản mới nhất từ `docs/CHANGELOGS.md`.
   - Tạo các file `fastlane/metadata/android/<locale>/changelogs/<build_number>.txt` cho các ngôn ngữ (`vi`, `en-US`).
6. **Upload & Phân Phối Lên Google Play**:
   - Sử dụng action `upload_to_play_store` với Service Account JSON.
   - Nạp AAB thẳng vào track `production` kèm theo changelog.
   - Trạng thái phát hành: `completed` (người dùng sẽ nhận bản cập nhật ngay sau khi Google duyệt).
7. **Lưu trữ Artifact**: Tải `*.apk` và `*.aab` lên GitHub Artifacts (`vcloud-android-builds`).

---

## 3. QUY TRÌNH CI/CD IOS (TESTFLIGHT + APP STORE DISTRIBUTION + REVIEW) TỰ ĐỘNG

### 3.1. Danh Sách GitHub Secrets Bắt Buộc Cho iOS
| Tên Secret | Ý nghĩa / Giá trị |
|---|---|
| `BUILD_CERTIFICATE_BASE64` | Tệp chứng chỉ phân phối iOS Distribution Certificate (`.p12`) dạng Base64. |
| `P12_PASSWORD` | Mật khẩu giải mã chứng chỉ `.p12`. |
| `BUILD_PROVISION_PROFILE_BASE64` | Tệp hồ sơ cấp phép `embedded.mobileprovision` (Profile App Store) dạng Base64. |
| `KEYCHAIN_PASSWORD` | Mật khẩu tạo keychain tạm thời trên runner macOS. |
| `APP_STORE_CONNECT_KEY_ID` | `3J68D9JX79` (Team API Key). |
| `APP_STORE_CONNECT_ISSUER_ID` | `69a6de93-488c-47e3-e053-5b8c7c11a4d1`. |
| `APP_STORE_CONNECT_KEY_CONTENT` | Chuỗi Base64 của file private key `AuthKey_3J68D9JX79.p8`. |
| `APP_STORE_CONNECT_KEY_BASE64` | `true`. |
| `APPLE_ID` | Email tài khoản Apple App Manager (`support@360.org.vn`). |
| `APPLE_APP_PASS` | App-Specific Password của tài khoản Apple dùng fallback cho `altool`. |

### 3.2. Luồng Thực Thi Tự Động Của iOS (Job: `build-ios-testflight`)

#### Giai đoạn A: Build & Nạp TestFlight (Fastlane)
1. **Runner macOS**: Runner `macos-latest`, cache CocoaPods/SPM, Flutter stable, Ruby 3.3.
2. **Cài đặt Certificate & Provisioning Profile**:
   - Giải mã `.p12` và `.mobileprovision`.
   - Tạo Keychain tạm thời `app-signing.keychain-db`, import chứng chỉ và cấu hình `set-key-partition-list`.
   - Đặt profile vào `~/Library/MobileDevice/Provisioning Profiles/`.
3. **Đóng gói IPA**:
   - Tạo file `ios/export_options.plist` với `method: app-store`, `teamID: ZC3H8887XS`.
   - Chạy `flutter build ipa --release --export-options-plist=ios/export_options.plist`.
4. **Nạp Lên Apple TestFlight**:
   - Fastlane gọi `upload_to_testflight` hoặc fallback qua Apple native `xcrun altool --upload-app`.
   - IPA được tiếp nhận lên máy chủ Apple để xử lý mã hóa.

#### Giai đoạn B: Tự Động Đưa Lên Distribution & Gửi Apple Duyệt (`appstore_distribute_and_submit.py`)
Ngay sau khi Fastlane kết thúc, step `Auto-Distribute to App Store & Submit for Review` tự động kích hoạt:
1. **Xác thực JWT ES256**: Giải mã `APP_STORE_CONNECT_KEY_CONTENT` từ GitHub Secrets, ký token JWT 20 phút.
2. **Quản lý Phiên Bản (`appStoreVersions`)**:
   - Tra cứu phiên bản đích `target_version` (VD: `2.9.22`).
   - Nếu chưa có: Tạo mới phiên bản iOS với số hiệu tương ứng (Trạng thái: `PREPARE_FOR_SUBMISSION`).
   - Nếu có bản nháp cũ: Cập nhật `versionString` sang bản mới.
   - Nếu bản dựng đã ở trạng thái `WAITING_FOR_REVIEW` hoặc `IN_REVIEW`: Ghi nhận đã nạp và bỏ qua.
3. **Polling Chờ Apple Xử Lý Build (Tối đa 10 phút)**:
   - Truy vấn `GET /v1/builds` theo số build `target_build` (VD: `167`).
   - Nếu build đang ở trạng thái `PROCESSING`: Tự động đợi và lặp lại mỗi 20 giây đến khi chuyển sang `VALID`.
4. **Gắn Build Vào Phiên Bản**:
   - Gửi yêu cầu `PATCH /v1/appStoreVersions/{versionId}/relationships/build` để gắn Build ID vào trang Distribution.
5. **Cập Nhật What's New Đa Ngôn Ngữ**:
   - Tự động trích xuất nội dung từ `docs/CHANGELOGS.md`.
   - Gửi `PATCH /v1/appStoreVersionLocalizations` cho cả hai ngôn ngữ `vi` và `en-US`.
6. **Tự Động Gửi Duyệt (`reviewSubmissions` API)**:
   - Tạo đợt duyệt mới: `POST /v1/reviewSubmissions` (platform `IOS`).
   - Thêm version vào đợt duyệt: `POST /v1/reviewSubmissionItems`.
   - Kích hoạt gửi duyệt: `PATCH /v1/reviewSubmissions/{id}` với `submitted: true`.
   - **Kết quả**: Phiên bản lập tức chuyển sang trạng thái **`🟡 Waiting for Review`** trên App Store Connect!

---

## 4. HƯỚNG DẪN CẤU HÌNH GITHUB SECRETS & SETTING GITHUB ACTIONS (SETUP TỪ ĐẦU)

> 💡 **Dành cho Agent khi setup repo mới**: Khi clone repo sang tổ chức mới hoặc dựng lại từ đầu, bắt buộc cấu hình đầy đủ 2 phần dưới đây:

### 4.1. Cài Đặt Quyền Hạn GitHub Actions (Bắt Buộc Trên Giao Diện Web)
Vào **GitHub Repo ➔ Settings ➔ Actions ➔ General**:
1. **Actions permissions**:
   - Chọn `Allow all actions and reusable workflows`.
2. **Workflow permissions**:
   - BẮT BUỘC chọn: **`Read and write permissions`** (Để CI/CD có thể tạo release artifacts, tag và đẩy commit nếu cần).
   - Đánh dấu tick chọn: **`Allow GitHub Actions to create and approve pull requests`**.
3. **Runner & Quota Thanh Toán (Billing)**:
   - **Android runner (`ubuntu-latest`)**: Miễn phí, nằm trong quota thông thường.
   - **iOS runner (`macos-latest`)**: Với private repo, tài khoản GitHub Organization **bắt buộc phải kích hoạt thẻ thanh toán / GitHub Actions Billing** (hoặc còn quota phút macOS), nếu không job iOS sẽ bị báo lỗi `Billing required`.

---

### 4.2. Bảng 14 GitHub Secrets Bắt Buộc & Lệnh Trích Xuất

| Tên Secret | Nguồn Dữ Liệu / Cách Lấy | Lệnh Terminal Trích Xuất & Thiết Lập Tự Động |
|---|---|---|
| **1. `ANDROID_KEYSTORE_BASE64`** | File `upload-keystore.jks` Android | `base64 -w 0 /đường/dẫn/upload-keystore.jks \| gh secret set ANDROID_KEYSTORE_BASE64` |
| **2. `ANDROID_KEYSTORE_PASSWORD`** | Mật khẩu truy cập file keystore | `echo -n "mat_khau_keystore" \| gh secret set ANDROID_KEYSTORE_PASSWORD` |
| **3. `ANDROID_KEY_ALIAS`** | Alias của key ký số Android | `echo -n "vcloud-key" \| gh secret set ANDROID_KEY_ALIAS` |
| **4. `ANDROID_KEY_PASSWORD`** | Mật khẩu của key alias | `echo -n "mat_khau_alias" \| gh secret set ANDROID_KEY_PASSWORD` |
| **5. `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS`** | File JSON Service Account tải từ Google Cloud Console (có quyền Google Play) | `cat /đường/dẫn/service_account.json \| gh secret set GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` |
| **6. `BUILD_CERTIFICATE_BASE64`** | Chứng chỉ iOS Distribution Certificate (`.p12`) | `base64 -w 0 /đường/dẫn/Certificates.p12 \| gh secret set BUILD_CERTIFICATE_BASE64` |
| **7. `P12_PASSWORD`** | Mật khẩu xuất file `.p12` từ Keychain Mac | `echo -n "mat_khau_p12" \| gh secret set P12_PASSWORD` |
| **8. `BUILD_PROVISION_PROFILE_BASE64`** | File Profile App Store (`embedded.mobileprovision`) | `base64 -w 0 /đường/dẫn/V_cloud.mobileprovision \| gh secret set BUILD_PROVISION_PROFILE_BASE64` |
| **9. `APP_STORE_CONNECT_KEY_ID`** | ID của App Store Connect API Key | `echo -n "3J68D9JX79" \| gh secret set APP_STORE_CONNECT_KEY_ID` |
| **10. `APP_STORE_CONNECT_ISSUER_ID`** | Issuer ID từ App Store Connect Users & Access | `echo -n "69a6de93-488c-47e3-e053-5b8c7c11a4d1" \| gh secret set APP_STORE_CONNECT_ISSUER_ID` |
| **11. `APP_STORE_CONNECT_KEY_CONTENT`** | File `AuthKey_3J68D9JX79.p8` dạng Base64 | `base64 -w 0 /media/tanma/DATA/save/file_ios_p8/AuthKey_3J68D9JX79.p8 \| gh secret set APP_STORE_CONNECT_KEY_CONTENT` |
| **12. `APP_STORE_CONNECT_KEY_BASE64`** | Cờ thông báo nội dung key là Base64 | `echo -n "true" \| gh secret set APP_STORE_CONNECT_KEY_BASE64` |
| **13. `APPLE_ID`** | Tài khoản Apple ID của App Manager | `echo -n "support@360.org.vn" \| gh secret set APPLE_ID` |
| **14. `APPLE_APP_PASS`** | App-Specific Password tạo từ appleid.apple.com | `echo -n "xxxx-xxxx-xxxx-xxxx" \| gh secret set APPLE_APP_PASS` |

*(Tùy chọn: `KEYCHAIN_PASSWORD` = bất kỳ chuỗi bảo mật ngẫu nhiên; `WEBHOOK_URL` = link webhook nhận thông báo).*

---

### 4.3. Script 1 Bước Nạp Hàng Loạt GitHub Secrets (Dành Cho Máy Local Sếp Tân)
Nếu cần reset hoặc nạp lại toàn bộ secret cho một repo mới, chạy script bash sau:
```bash
REPO="360org/vcloud"
P8_KEY="/media/tanma/DATA/save/file_ios_p8/AuthKey_3J68D9JX79.p8"

# Apple Secrets
gh secret set APP_STORE_CONNECT_KEY_ID --repo "$REPO" --body "3J68D9JX79"
gh secret set APP_STORE_CONNECT_ISSUER_ID --repo "$REPO" --body "69a6de93-488c-47e3-e053-5b8c7c11a4d1"
base64 -w 0 "$P8_KEY" | gh secret set APP_STORE_CONNECT_KEY_CONTENT --repo "$REPO"
gh secret set APP_STORE_CONNECT_KEY_BASE64 --repo "$REPO" --body "true"
gh secret set APPLE_ID --repo "$REPO" --body "support@360.org.vn"

echo "✅ Đã nạp thành công bộ cấu hình Apple Secrets vào GitHub Actions!"
```

---

## 5. CÁCH KÍCH HOẠT PHÁT HÀNH (TRIGGER RUNBOOK)

### Cách 1: Phát Hành Toàn Diện Qua Git Release Tag (Khuyên dùng)
Khi hoàn tất code, tăng version trong `pubspec.yaml` (VD: `2.9.22+167`), cập nhật `docs/CHANGELOGS.md`, sau đó chạy:
```bash
# Tạo release tag đẩy lên GitHub (Tự động kích hoạt toàn bộ luồng Android + iOS)
gh release create v2.9.22+167 \
  --repo 360org/vcloud \
  --title "v2.9.22+167 - VCloud Mobile Release" \
  --notes "Cập nhật tính năng mới và tối ưu hiệu năng."
```
*GitHub Actions sẽ tự động nhận diện sự kiện `release: published`, chạy song song cả 2 job Android và iOS, nạp AAB lên Google Play và đưa bản iOS lên hàng đợi duyệt của Apple.*

### Cách 2: Kích Hoạt Thủ Công Qua GitHub Actions Workflow Dispatch
```bash
# Chạy toàn bộ cả 2 nền tảng
gh workflow run deploy.yml --repo 360org/vcloud -f target=all -f submit_for_review=true

# Hoặc chỉ chạy riêng iOS
gh workflow run deploy.yml --repo 360org/vcloud -f target=ios -f submit_for_review=true

# Hoặc chỉ chạy riêng Android
gh workflow run deploy.yml --repo 360org/vcloud -f target=android
```

### Cách 3: Chạy Script Distribution & Submit Tại Local (Cứu Hộ / Chạy Bù)
Nếu muốn đưa một bản build đã có trên TestFlight lên Distribution và submit duyệt ngay trên máy local:
```bash
cd /media/tanma/DATA/save/mobile_versions/vclients

# Tự động đọc pubspec.yaml và CHANGELOGS.md
python3 scripts/appstore_distribute_and_submit.py

# Hoặc chỉ định rõ version và build
python3 scripts/appstore_distribute_and_submit.py --version 2.9.22 --build 167

# Chỉ đưa lên trang Distribution làm nháp, CHƯA gửi duyệt
python3 scripts/appstore_distribute_and_submit.py --no-submit
```

---

## 6. MA TRẬN XỬ LÝ LỖI PHỔ BIẾN (TROUBLESHOOTING MATRIX)

| Mã Lỗi / Hiện Tượng | Nguyên Nhân Gốc Rễ | Giải Pháp Triệt Để |
|---|---|---|
| `ERROR: The bundle version must be higher than the previously uploaded version: '166'` | Apple từ chối binary vì trùng Build Number `166` đã từng nạp lên trước đó. | Tăng số build trong `pubspec.yaml` lên `+1` (VD: `2.9.22+167`), tạo tag mới để build lại. |
| `Missing required information to submit for external testing` | Fastlane `upload_to_testflight` cố phân phối cho external testers nhưng thiếu khai báo mã hóa. | Step Python `appstore_distribute_and_submit.py` chạy độc lập ngay sau đó sẽ tự động gán build và submit duyệt mà không phụ thuộc vào Fastlane. |
| `Build not found in VALID state after 600s` | Apple mất quá nhiều thời gian để xử lý IPA hoặc binary bị lỗi cấu hình (thiếu icon/NSCameraUsageDescription). | Kiểm tra email từ App Store Connect xem Apple có gửi cảnh báo reject binary không. Nếu do mạng chậm, chỉ cần chạy lại `python3 scripts/appstore_distribute_and_submit.py`. |
| `HTTP 401 Unauthorized (JWT)` | Khóa API Key `.p8` bị sai Key ID hoặc Issuer ID. | Kiểm tra lại Secret `APP_STORE_CONNECT_KEY_ID=3J68D9JX79` và `APP_STORE_CONNECT_ISSUER_ID=69a6de93-488c-47e3-e053-5b8c7c11a4d1`. |
| `Google Play Track Upload Failed (AAB)` | Service account Google Cloud bị thu hồi quyền hoặc file JSON bị sai format. | Kiểm tra `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` trong GitHub Secrets. |
| `App Store State already WAITING_FOR_REVIEW` | Bản dựng đã được submit thành công trước đó. | Script tự động phát hiện trạng thái này và báo thành công, không gửi đè. |

---

*Tài liệu được khởi tạo và kiểm chứng thực tế cùng đợt phát hành `v2.9.22+167` thành công.*  
*Trailer: Authored-By: 360org <support@360.org.vn>*
