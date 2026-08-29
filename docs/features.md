# VCloud Features Control

> Mục tiêu: một nơi duy nhất để Sếp kiểm soát tính năng app VCloud Mobile theo module, trạng thái và bằng chứng kiểm thử.

## Quy ước trạng thái

| Trạng thái | Ý nghĩa |
|---|---|
| `LIVE` | Đã có trong app/code hiện tại |
| `BACKEND` | Phụ thuộc backend Odoo `v_mobile` |
| `CI` | Có trong quy trình build/test/release |
| `WATCH` | Cần theo dõi khi đổi API, bundle, package hoặc policy store |

## Tổng quan nhanh

| Module | Tính năng chính | Trạng thái | Verify chính |
|---|---|---:|---|
| Auth | Đăng nhập Odoo Mobile API Gateway, lưu tenant session/JWT an toàn, logout cleanup | `LIVE` | `flutter test`, auth repository tests |
| Home | Dashboard công việc, ticket, timesheet, chấm công, badge chat, notification sheet | `LIVE` | `test/reference_ui_widgets_test.dart`, performance benchmarks |
| Chat | Chat nội bộ, nhóm, tin nhắn, ảnh/file, unread, tạo nhóm, tìm kiếm | `LIVE` | `test/features/chat/chat_repository_test.dart`, integration tests |
| Chat V2 | Realtime chat, lazy loading, reply, reaction, poll, location, file/media hub, presence | `LIVE` `BACKEND` | `test/features/chat_v2/*` |
| Voice/Call | Tin nhắn thoại, voice player, incoming/outgoing call UI, trạng thái cuộc gọi | `LIVE` `BACKEND` | `test/features/chat_v2/chat_v2_call_test.dart`, call widget tests |
| Push | FCM/APNs/Web push, auto register token, topic subscribe, token inspection | `LIVE` `BACKEND` `WATCH` | notification tests, Firebase/APNs live check |
| Attendance | Check-in/out, trạng thái hôm nay, lịch sử, ca làm việc động từ backend | `LIVE` `BACKEND` | `test/features/attendance/*` |
| Timesheet | Công việc hôm nay, project/task lookup, log giờ, update entry, checklist, quick edit | `LIVE` `BACKEND` | `test/task_repository_test.dart`, `test/timesheet_contract_test.dart` |
| Ticket | Danh sách/chi tiết/tạo ticket, bình luận, attachment, đội xử lý, liên hệ | `LIVE` `BACKEND` | ticket repository/widget tests |
| Profile | Hồ sơ, sửa thông tin, theme, About, FCM token, What's New | `LIVE` | profile/widget tests |
| File/Attachment | Download native/web, validate file, cache local, chặn file quá dung lượng | `LIVE` `BACKEND` | attachment/download tests |
| Release | GitHub Actions, GitLab CI, Fastlane, Codemagic, iOS TestFlight, Android AAB/APK | `CI` `WATCH` | CI logs, `flutter analyze`, `flutter test` |

## Chi tiết theo module

### 1. Auth & Session

- [x] Đăng nhập bằng `login/password` qua Odoo Mobile API Gateway.
- [x] Lưu tenant JWT và routing metadata trong secure storage.
- [x] Khôi phục phiên làm việc khi mở app.
- [x] Logout và dọn token/session cục bộ.
- [ ] `WATCH`: Không hard-code secret, host cá nhân, password, certificate hoặc private key.

### 2. Home / Dashboard

- [x] Tổng quan công việc hôm nay.
- [x] Tổng quan ticket.
- [x] Tổng quan timesheet.
- [x] Trạng thái chấm công hôm nay.
- [x] Badge chat chưa đọc.
- [x] Notification sheet từ chuông trang chủ.
- [x] Cache/SWR để giảm gọi API lặp và tăng tốc render.

### 3. Chat nội bộ

- [x] Danh sách kênh chat.
- [x] Chat 1-1 và chat nhóm.
- [x] Gửi/nhận tin nhắn.
- [x] Đính kèm ảnh/file/tài liệu.
- [x] Đánh dấu đã đọc và badge chưa đọc.
- [x] Tạo nhóm chat mới.
- [x] Tìm kiếm người dùng/kênh.
- [x] Xem thông tin phòng chat, thành viên, media, file và link.

### 4. Chat V2 realtime

- [x] Danh sách Chat V2 riêng.
- [x] Cache RAM cho kênh và tin nhắn.
- [x] Lazy loading tin nhắn.
- [x] Presence online/offline realtime.
- [x] Typing/read state.
- [x] Reply/quote tin nhắn.
- [x] Reaction tin nhắn.
- [x] Poll trong chat.
- [x] Location sharing card.
- [x] Voice message player inline.
- [x] In-app banner cho chat/cuộc gọi.
- [x] Màn hình xem ảnh riêng.
- [x] Bottom sheet tạo poll.
- [x] Sheet chi tiết reaction.
- [ ] `WATCH`: Khi backend đổi schema `discuss.channel`, `mail.message`, attachment hoặc presence thì phải update parser/test tương ứng.

### 5. Voice message & Call

- [x] Tin nhắn thoại.
- [x] Voice player inline.
- [x] Dialog cuộc gọi đến.
- [x] Màn hình cuộc gọi đi.
- [x] Trạng thái `ringing`, `connected`, `rejected`, `cancelled`, `ended`.
- [x] Nút mute/speaker/cancel/end.
- [x] Watcher theo dõi cuộc gọi hoạt động.
- [x] Push/in-app notification cho cuộc gọi.

### 6. Push Notification

- [x] Firebase Cloud Messaging.
- [x] APNs iOS cho bundle `com.w360s.wcloudapp`.
- [x] Android package `com.vcloud.vcloud`.
- [x] Web push qua `firebase-messaging-sw.js`.
- [x] Tự đăng ký FCM token sau login/khi vào Home.
- [x] Hủy đăng ký token khi logout.
- [x] Subscribe topic `all_ios` và `all_devices`.
- [x] Xem/copy FCM token 1 chạm trong Profile.
- [x] Backend retry/backoff và chống gửi trùng.
- [ ] `WATCH`: Bundle iOS, Android package, Firebase app id, APNs key và backend `fcm_project_id` phải luôn đồng bộ.

### 7. Attendance / Chấm công

- [x] Check-in.
- [x] Check-out.
- [x] Trạng thái chấm công hôm nay.
- [x] Lịch sử chấm công.
- [x] Cấu hình ca làm việc động từ backend.
- [x] Tính giờ làm ngày thường/thứ Hai/thứ Bảy.
- [x] Tính nghỉ trưa, early check-in, session chưa đóng.
- [x] Checkout dialog.

### 8. Timesheet & Task

- [x] Danh sách timesheet gần đây.
- [x] Công việc hôm nay.
- [x] Project/task lookup.
- [x] Ghi giờ vào task.
- [x] Cập nhật entry timesheet cũ.
- [x] Log thời gian bằng stopwatch duration.
- [x] Hoàn thành task kèm log giờ.
- [x] Checklist editor.
- [x] Quick edit popup cho task hôm nay.
- [x] Summary timesheet.
- [x] Bộ lọc ngày/preset range.

### 9. Ticket / Helpdesk

- [x] Danh sách ticket.
- [x] Chi tiết ticket.
- [x] Tạo ticket mới.
- [x] Bình luận ticket.
- [x] Đính kèm file/ảnh vào ticket.
- [x] Hiển thị đội xử lý.
- [x] Hiển thị thông tin liên hệ.
- [x] Mapping HTML title/description sang text sạch.
- [x] Activity/comment model.
- [x] Tải/xác minh attachment ticket.

### 10. Profile / Cá nhân

- [x] Xem thông tin người dùng.
- [x] Sửa hồ sơ.
- [x] Avatar/logo thương hiệu.
- [x] Đổi theme.
- [x] Màn hình About.
- [x] Xem/copy trạng thái FCM token.
- [x] What's New sheet theo phiên bản.

### 11. File, ảnh, tải xuống

- [x] Download file native mobile/web.
- [x] Lưu ảnh/tệp đúng nền tảng.
- [x] Validate magic bytes cơ bản.
- [x] Cache attachment cục bộ.
- [x] Hỗ trợ PDF, DOCX, XLSX, CSV, JSON, ZIP, Markdown, ảnh, audio và nhiều định dạng phổ biến.
- [x] File download web bằng Blob.
- [x] Chặn file quá dung lượng: ảnh 10 MB, tài liệu 25 MB.

### 12. UI/UX & Brand

- [x] Material 3.
- [x] Giao diện tiếng Việt.
- [x] Brand logo 360 CORP.
- [x] Splash screen.
- [x] App toast.
- [x] Empty/error/loading UI.
- [x] Copyable error dialog.
- [x] Brand orbit loader.
- [x] Celebration/fireworks widget.
- [x] Responsive widget coverage.

### 13. CI/CD & Release

- [x] GitHub Actions deploy.
- [x] GitLab CI.
- [x] Fastlane iOS/Android.
- [x] Codemagic config.
- [x] iOS TestFlight/App Store pipeline.
- [x] Android Play Store AAB/APK pipeline.
- [x] `flutter analyze` gate.
- [x] `flutter test` gate.
- [ ] `WATCH`: Release/build version phải đồng bộ `pubspec.yaml`, changelog, audit report và tag khi phát hành.

## Verify checklist trước khi release

- [ ] `flutter pub get`
- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] Kiểm tra iOS bundle: `com.w360s.wcloudapp`
- [ ] Kiểm tra Android package: `com.vcloud.vcloud`
- [ ] Kiểm tra Firebase/APNs push trên thiết bị thật khi có thay đổi notification.
- [ ] Cập nhật `docs/CHANGELOGS.md` nếu có thay đổi tính năng.
- [ ] Cập nhật `docs/AUDIT_REPORT.md` khi phát hành build mới.

## Nguồn kiểm soát

- `/Volumes/DATA/ENV/VCloud/sad-rubin-9aec2c/README.md`
- `/Volumes/DATA/ENV/VCloud/sad-rubin-9aec2c/docs/REQUIREMENTS.md`
- `/Volumes/DATA/ENV/VCloud/sad-rubin-9aec2c/docs/CHANGELOGS.md`
- `/Volumes/DATA/ENV/VCloud/sad-rubin-9aec2c/test/`
