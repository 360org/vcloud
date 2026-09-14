# 🚀 SƠ ĐỒ & QUY TRÌNH TỰ ĐỘNG HÓA CI/CD DEPLOYMENT (VCLOUD)
> **Tài liệu chuẩn hóa:** `docs/CICD_AUTO_DEPLOY_PIPELINE.md`  
> **Áp dụng cho:** Hệ sinh thái **VCloud Mobile (`vclients`)** — iOS (Apple TestFlight) & Android (Google Play Console)  
> **Tiêu chuẩn:** `360-vcloud` & AIaC 2026 — Phê duyệt bởi: **Sếp Tân**

---

## 1. 🏛️ TỔNG QUAN KIẾN TRÚC TỰ ĐỘNG HÓA (ZERO-TOUCH DEPLOY)

Hệ thống CI/CD của VCloud được thiết kế theo nguyên lý **Zero-Touch Automation**:
- Khi kích hoạt GitHub Actions (`workflow_dispatch` hoặc `release: [published]`), toàn bộ chuỗi tác vụ từ phân tích linter, chạy kiểm thử 336+ tests, ký số bảo mật, đóng gói bản dựng đến xuất bản trực tiếp lên **Apple App Store Connect (TestFlight)** và **Google Play Console** đều được thực thi tự động 100%.
- Không cần tải file về máy, không cần đăng nhập console để kéo-thả thủ công.

---

## 2. 📊 SƠ ĐỒ LUỒNG HOẠT ĐỘNG (END-TO-END WORKFLOW)

```text
                                 [ Sếp Tân / Developer ]
                                            │
                                            ▼
                           Kích hoạt Workflow trên GitHub
                    (Thủ công: workflow_dispatch HOẶC Release Tag)
                                            │
               ┌────────────────────────────┴────────────────────────────┐
               │                                                         │
               ▼                                                         ▼
    ┌──────────────────────┐                                  ┌──────────────────────┐
    │   JOB 1: iOS Build   │                                  │  JOB 2: Android Build│
    │   (macOS Runner)     │                                  │   (Ubuntu Runner)    │
    └──────────┬───────────┘                                  └──────────┬───────────┘
               │                                                         │
               ├─► [1] Checkout Code & Setup Flutter Engine              ├─► [1] Checkout Code & Setup Flutter & Java 17
               ├─► [2] Static Analysis (flutter analyze - 0 errors)      ├─► [2] Static Analysis (flutter analyze - 0 errors)
               ├─► [3] Automated Testing (336 tests PASS 100%)           ├─► [3] Automated Testing (336 tests PASS 100%)
               ├─► [4] Ký số iOS (Apple Distribution Certificate + .p12) ├─► [4] Ký số Android:
               │                                                         │    ├─ Giải mã `ANDROID_KEYSTORE_BASE64`
               │                                                         │    ├─ Tạo `upload-keystore.jks`
               │                                                         │    └─ Cấu hình `android/key.properties`
               ├─► [5] Trích xuất Version & Build Number từ              ├─► [5] Trích xuất Version & Build Number từ
               │       `pubspec.yaml` (SSOT: ví dụ 2.9.6+128)            │       `pubspec.yaml` (SSOT: ví dụ 2.9.6+128)
               ├─► [6] Tự động trích xuất Changelog từ                   ├─► [6] Tự động trích xuất Changelog từ
               │       `docs/CHANGELOGS.md` chuẩn hóa <=480 ký tự        │       `docs/CHANGELOGS.md` chuẩn hóa <=480 ký tự
               ├─► [7] Biên dịch IPA:                                    ├─► [7] Biên dịch AAB & APK:
               │       `flutter build ipa --release`                     │       ├─ `flutter build apk --release`
               │                                                         │       └─ `flutter build appbundle --release`
               │                                                         ├─► [8] Sinh file Metadata Changelog (vi-VN & en-US)
               │                                                         │       `fastlane/metadata/android/vi-VN/changelogs/<build>.txt`
               ▼                                                         ▼
    ┌──────────────────────┐                                  ┌──────────────────────┐
    │   Apple TestFlight   │                                  │ Google Play Console  │
    │      Deployment      │                                  │      Deployment      │
    └──────────┬───────────┘                                  └──────────┬───────────┘
               │                                                         │
               ├─► Xác thực App Store Connect API Key                    ├─► Xác thực Google Play Developer API
               │   (hoặc App-Specific Password fallback)                 │   qua `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS`
               ├─► Fastlane upload IPA lên App Store Connect             ├─► Fastlane (`upload_to_play_store`) đẩy file
               │   Bundle ID: `com.w360s.wcloudapp`                      │   `.aab` lên Package: `com.mobile.vloud`
               ├─► Gán Release Notes "What to Test" từ Changelog         ├─► Nạp mục "Có gì mới / What's new" từ Changelog
               │                                                         ├─► Đưa vào Track: `internal` (hoặc `production`)
               │                                                         │
               ▼                                                         ▼
    ┌──────────────────────┐                         ┌──────────────────────────────────────────────┐
    │ 🍏 Apple TestFlight  │                         │            🤖 Google Play Console            │
    │ Ứng dụng sẵn sàng    │                         └──────────────────────┬───────────────────────┘
    │ cho nội bộ test      │                                                │
    └──────────────────────┘                                 ┌──────────────┴──────────────┐
               │                                             ▼                             ▼
               │                              [ Kênh Thử Nghiệm Nội Bộ ]      [ Kênh Sản Xuất (Production) ]
               │                              (Track: internal - Tự động)     (Track: production - Công chúng)
               │                                             │                             │
               │                              ├─ Google xử lý trong vài phút  ├─ Google Review duyệt chính sách
               │                              └─ Máy Tester trong danh sách   │  (Từ vài giờ đến 1-2 ngày)
               │                                 tự động thấy nút Cập nhật    └─ Tự động phát hành đến toàn bộ
               │                                 trên CH Play                    người dùng trên Google Play Store
               │                                             │                             ▲
               │                                             └───── [ Quảng bá Release ] ──┘
               │                                                    (Promote Release 1-click)
               └────────────────────────────┬──────────────────────────────────────────────┘
                                            │
                                            ▼
                           Gửi thông báo hoàn tất qua Webhook
                                 (Thành công / Thất bại)
```

---

## 3. 🔐 CẤU HÌNH BẢO MẬT & QUẢN LÝ SECRETS (GITHUB SECRETS)

Toàn bộ quy trình được bảo mật qua các GitHub Repository Secrets tại `360org/vcloud`:

| Tên Secret | Mục Đích | Nền Tảng |
| :--- | :--- | :---: |
| `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` | Chứa toàn bộ nội dung file JSON của Service Account (`github-actions-play-store@...`) có quyền phát hành trên Google Play Console. | Android |
| `ANDROID_KEYSTORE_BASE64` | Chuỗi mã hóa Base64 của tệp ký số `upload-keystore.jks` (Key Alias: `upload`). | Android |
| `ANDROID_KEYSTORE_PASSWORD` | Mật khẩu mở Keystore (mặc định: `123456`). | Android |
| `ANDROID_KEY_PASSWORD` | Mật khẩu của Key Alias (mặc định: `123456`). | Android |
| `GOOGLE_PLAY_TRACK` *(Tùy chọn)* | Kênh phát hành Google Play: `internal` (mặc định), `alpha`, `beta`, `production`. | Android |
| `APP_STORE_CONNECT_KEY_ID` | Key ID xác thực App Store Connect API. | iOS |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID xác thực App Store Connect. | iOS |
| `APP_STORE_CONNECT_KEY_CONTENT` | Nội dung file khóa `.p8` phân phối ứng dụng iOS. | iOS |
| `BUILD_CERTIFICATE_BASE64` | Chứng chỉ phân phối iOS Distribution Certificate dạng Base64. | iOS |
| `BUILD_PROVISION_PROFILE_BASE64`| Hồ sơ phân phối Provisioning Profile dạng Base64. | iOS |
| `WEBHOOK_URL` | Webhook thông báo kết quả phát hành bản dựng về kênh liên lạc nội bộ. | Toàn hệ thống |

---

## 4. 📋 THÔNG TIN ĐỊNH DANH ỨNG DỤNG (APP METADATA)

### Phía Android (Google Play Console):
* **Tên ứng dụng:** Vua Hệ Thống (VCloud)
* **Package Name (Application ID):** `com.mobile.vloud`
* **Keystore Alias:** `upload`
* **Đường dẫn Keystore gốc:** `/media/tanma/DATA/save/mobile_versions/vclients/android/upload-keystore.jks`
* **Đường dẫn Backup:** `/media/tanma/TheNho/thongbao_firebase/` và `/media/tanma/DATA/thongbao_firebase/`
* **Service Account Google Cloud:** `github-actions-play-store@pivotal-pursuit-508402-r8.iam.gserviceaccount.com`

### Phía iOS (Apple App Store Connect):
* **Tên ứng dụng:** Vua Hệ Thống (VCloud)
* **Bundle Identifier:** `com.w360s.wcloudapp`
* **Team ID:** `ZC3H8887XS` (W360S JOINT STOCK COMPANY)

---

## 5. 🎯 QUY TẮC PHÁT HÀNH BẢN DỰNG (RELEASE RULES)

1. **Single Source of Truth cho Version & Build Number:**
   - Số phiên bản và số build **BẮT BUỘC** quản lý tại file `pubspec.yaml` (ví dụ: `version: 2.9.6+128`).
   - Pipeline tự động đọc số build `128` trực tiếp từ `pubspec.yaml`, tuyệt đối không dùng `github.run_number` để tránh làm lệch số build trên store.
2. **Kênh phát hành an toàn:**
   - Android mặc định được upload vào kênh **Internal Testing (Thử nghiệm nội bộ)**.
   - Khi cần phát hành chính thức cho toàn bộ người dùng, chỉ cần chuyển biến `GOOGLE_PLAY_TRACK` thành `production` hoặc bấm nút *Thúc đẩy bản phát hành* (Promote Release) trực tiếp trên Google Play Console.
