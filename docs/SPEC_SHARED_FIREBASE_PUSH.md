# SPEC: TÍCH HỢP FIREBASE PUSH NOTIFICATION (SHARED FIREBASE) VÀO VCLOUD APP

**Ngày tạo:** 2026-08-31  
**Trạng thái:** Đang triển khai  
**Phạm vi:** Flutter App + Odoo 17 (vuahethong.net) + Odoo 19 (demo.vuahethong.com)

---

## 1. Bài toán

| Yêu cầu | Chi tiết |
|---|---|
| Push Notification | Chat, Ticket, Attendance events → đẩy thông báo xuống điện thoại |
| Shared Firebase | 1 Firebase Project `vcloud-mobile` dùng chung cho cả Odoo 17 và Odoo 19 |
| Smart Router | App tự định tuyến API về đúng domain theo tài khoản đăng nhập |
| Bỏ OneSignal | Không dùng song song, không dùng thay thế — 100% Firebase FCM |

**Lý do chọn Firebase thay vì OneSignal:**
- Backend Odoo đã có sẵn engine gửi push chuẩn production (Background Thread + Exponential Backoff + Crash Recovery) trong `notification.py`
- OneSignal chỉ là wrapper gọi lại FCM/APNs → thêm 1 hop network → chậm hơn
- Không phải trả phí (FCM miễn phí không giới hạn)
- Không phình dung lượng app & không hao pin (1 service ngầm thay vì 2)

## 2. Kiến trúc

```text
┌──────────────────┐
│   Flutter App    │
│ (VCloudFirebase  │
│  Options.dart)   │
│                  │
│ Firebase Project:│
│ vcloud-mobile    │
│ Sender ID:       │
│ 339448653254     │
└────────┬─────────┘
         │ FCM Token (1 token duy nhất cho device)
         │
    ┌────▼────────────────────────────────────────┐
    │           Smart Router (Login)               │
    │  tanmnn@360.org.vn → vuahethong.net (O17)   │
    │  demo/demo        → demo.vuahethong.com (O19)│
    └────┬──────────────────────┬──────────────────┘
         │                      │
   ┌─────▼──────┐        ┌─────▼──────┐
   │  Odoo 17   │        │  Odoo 19   │
   │ DB: mobile │        │ DB: mobile │
   │ .api.device│        │ .api.device│
   │            │        │            │
   │ Service    │        │ Service    │
   │ Account:   │        │ Account:   │
   │ CHUNG 1    │        │ CHUNG 1    │
   │ file JSON  │        │ file JSON  │
   └─────┬──────┘        └─────┬──────┘
         │                      │
         └──────────┬───────────┘
                    ▼
        ┌───────────────────────┐
        │ Google FCM API v1     │
        │ Project: vcloud-mobile│
        └───────────┬───────────┘
                    ▼
              📱 Device
```

**Luồng hoạt động:**
1. User mở app → Login → Smart Router trỏ về đúng Odoo instance
2. App xin quyền Notification → Firebase sinh FCM Token
3. App gọi `POST /api/v1/mobile/notifications/register` gửi token lên Odoo hiện tại
4. Khi có sự kiện (tin nhắn mới, ticket mới...) → Odoo gọi FCM API v1 với Service Account JSON → FCM push xuống device
5. App nhận push → Foreground: hiện banner / Background: system notification

## 3. Cấu hình Firebase (Đã có sẵn)

### 3.1 Firebase Project Info
| Key | Value |
|---|---|
| Project ID | `vcloud-mobile` |
| Project Number / Sender ID | `339448653254` |
| Android Package | `com.w360s.wcloudapp` |
| iOS Bundle ID | `com.w360s.wcloudapp` |
| Service Account Email | `firebase-adminsdk-fbsvc@vcloud-mobile.iam.gserviceaccount.com` |

### 3.2 File cấu hình (Nguồn: `/media/tanma/DATA/thongbao_firebase/`)
| File | Đích | Trạng thái |
|---|---|---|
| `google-services.json` | `vclients/android/app/` | ✅ Đã copy |
| `GoogleService-Info.plist` | `vclients/ios/Runner/` | ✅ Đã copy |
| `Service Account.json` | Dán nội dung vào Odoo System Parameters | ⏳ Sếp cần nhập |
| `AuthKey_XSKV9X4NK4.p8` | Upload lên Firebase Console (APNs) | ⏳ Sếp cần upload |

## 4. Trạng thái Code (Audit hiện tại)

### 4.1 Flutter — ĐÃ CÓ SẴN (>95% done)
| Component | File | Trạng thái |
|---|---|---|
| Firebase Options (hardcode) | `lib/core/notifications/firebase_push_options.dart` | ✅ Đầy đủ Android/iOS/Web |
| Push Service (init, register, unregister) | `lib/core/notifications/push_notification_service.dart` | ✅ Hoàn chỉnh |
| Push Repository (gọi API Odoo) | `lib/core/notifications/push_notification_repository.dart` | ✅ Hoàn chỉnh |
| Background Handler | `push_notification_service.dart` (top-level function) | ✅ Có |
| Token Refresh Listener | `push_notification_service.dart` | ✅ Có |
| APNs Token Wait (iOS) | `push_notification_service.dart` | ✅ Retry 15 lần |
| `Env.firebasePushConfigured` | `lib/core/config/env.dart` | ✅ Đã sửa → luôn `true` |

### 4.2 Android Build — VỪA SỬA
| Thay đổi | File | Trạng thái |
|---|---|---|
| Thêm `com.google.gms.google-services` plugin | `android/settings.gradle.kts` | ✅ Đã thêm |
| Apply plugin trong app | `android/app/build.gradle.kts` | ✅ Đã thêm |

### 4.3 iOS Build — ĐÃ CÓ SẴN
| Config | Trạng thái |
|---|---|
| `Info.plist` → `remote-notification` Background Mode | ✅ Có (line 84) |
| `GoogleService-Info.plist` trong `ios/Runner/` | ✅ Đã copy |

### 4.4 Odoo 17 Backend — ĐÃ CÓ SẴN
| Component | File | Trạng thái |
|---|---|---|
| Model `mobile.api.device` (lưu FCM token) | `models/device.py` | ✅ |
| Model `mobile.api.notification` (gửi push) | `models/notification.py` | ✅ Production-grade |
| API Register Device | `controllers/notifications.py` | ✅ |
| API Unregister Device | `controllers/notifications.py` | ✅ |
| Cron Retry Failed Push | `notification.py` | ✅ |
| Config keys (System Parameters) | `vmobile.fcm_project_id`, `vmobile.fcm_service_account_json`, `vmobile.push_enabled` | ✅ Đã setup |

### 4.5 Odoo 19 Backend — CẦN LÀM
| Việc cần làm | Cách thực hiện |
|---|---|
| Nhập 3 System Parameters giống Odoo 17 | Sếp vào **Settings → Technical → System Parameters** trên `demo.vuahethong.com` |

## 5. Việc Sếp cần làm thủ công (2 việc)

### Việc 1: Nhập Firebase Config vào Odoo 19
Vào `demo.vuahethong.com` → **Settings → Technical → System Parameters**, tạo 3 key:

| Key | Value |
|---|---|
| `vmobile.fcm_project_id` | `vcloud-mobile` |
| `vmobile.push_enabled` | `True` |
| `vmobile.fcm_service_account_json` | *(Dán toàn bộ nội dung file `Service Account.json`)* |

### Việc 2: Upload APNs Key lên Firebase Console (cho iOS)
1. Mở https://console.firebase.google.com → Project `vcloud-mobile`
2. **Project Settings → Cloud Messaging → Apple app configuration**
3. Click **Upload** ở mục **APNs Authentication Key**
4. Chọn file `AuthKey_XSKV9X4NK4.p8`
5. Nhập Key ID: `XSKV9X4NK4`
6. Nhập Team ID: *(Team ID của tài khoản Apple Developer 360org)*

> ⚠️ Nếu không upload APNs Key: Push Android hoạt động bình thường, nhưng iOS sẽ KHÔNG nhận được thông báo.

## 6. Rủi ro & Giải pháp

| Rủi ro | Xác suất | Giải pháp |
|---|---|---|
| iOS không nhận push | Cao (nếu thiếu APNs Key) | Upload APNs Key lên Firebase Console (Việc 2) |
| Odoo 19 chưa có module `v_mobile` | Thấp | Kiểm tra `v_mobile` đã cài trên Odoo 19 chưa |
| Token bị deactivate sau 3 lần gửi lỗi | Thiết kế | User mở lại app → tự động re-register token mới |
| 2 Odoo gửi push trùng lặp cho cùng 1 event | Không xảy ra | Mỗi user chỉ login 1 domain tại 1 thời điểm, token chỉ đăng ký trên domain đó |

## 7. Tổng kết

| Hạng mục | Trạng thái |
|---|---|
| Flutter Code | ✅ Hoàn tất (chỉ sửa 2 file build Android + 1 dòng Env) |
| Odoo 17 Backend | ✅ Đã setup đầy đủ |
| Odoo 19 Backend | ⏳ Sếp nhập 3 key System Parameters |
| APNs (iOS push) | ⏳ Sếp upload key lên Firebase Console |
| OneSignal | ❌ Bỏ hoàn toàn — không tích hợp |
