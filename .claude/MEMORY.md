# Project Memory (FLUTTER)

> Bộ nhớ cục bộ theo repo (Local-First Memory). AIaC tự động nạp ưu tiên trước Claude Persistent Memory.

## 1. Project Context
- Loại dự án: flutter
- Dấu hiệu: pubspec.yaml
- Backend Production: `https://vuahethong.net` (Odoo 17)

## 2. Core Decisions & Constraints
- Không commit secret, token, private key vào repo.
- Ưu tiên áp dụng Ponytail: YAGNI -> stdlib -> native -> existing dependency -> minimal diff.

## 3. Server & Firebase Push Notification State (PERMANENT KNOWLEDGE - BẮT BUỘC GHI NHỚ)
- **Odoo Backend Production (`https://vuahethong.net`)**:
  - `push_enabled`: **ĐÃ BẬT (True)**
  - `fcm_project_id`: **`vcloud-mobile`** (ĐÃ CẤU HÌNH)
  - `fcm_service_account_json`: **ĐÃ NẠP TOÀN BỘ JSON HOÀN TẤT TRÊN VUA HỆ THỐNG**
  - `push_default_android_channel_id`: **`default`**
  - ⚠️ **LƯU Ý**: Không bao giờ hỏi hoặc yêu cầu anh Tân nạp lại các thông số Firebase/Service Account này nữa.
- **Apple Developer & APNs Key**:
  - Team ID: `ZC3H8887XS` (W360S JOINT STOCK COMPANY)
  - APNs Key ID: `XSKV9X4NK4` (File `AuthKey_XSKV9X4NK4.p8`)
  - Đã nạp và active trên Firebase Console.

## 4. Session Learnings
- Odoo 17 Discuss channels dùng bus websocket, `mail.thread._notify_thread` cần nạp trực tiếp danh sách thành viên kênh `discuss.channel.member` để gửi push realtime.
