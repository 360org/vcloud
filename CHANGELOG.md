# CHANGELOG

## [2.9.16 - Build 154] - 2026-10-09

### 🚀 Nâng Cấp Phiên Bản App Store & Google Play Release
- **Khắc Phục Tải Tệp Tin Đính Kèm Chat V2 & Multi-Tier Fallback**:
  * Tối ưu thứ tự fallback trong `MobileAttachmentRepository.fetchBytes()`: ưu tiên `/web/content/$attachmentId` trước `/web/image/$attachmentId`, ngăn chặn việc server Odoo trả placeholder image 6KB thay vì nội dung tài liệu.
  * Truyền đầy đủ `accessToken` vào `ChatV2AttachmentViewer.open()` cho tài liệu đính kèm chat, đảm bảo tải thành công cả trên môi trường có phân quyền bảo mật attachment token.
- **Đồng Bộ Phiên Bản Tiếp Theo Chuẩn Apple App Store**:
  * Nâng Marketing Version lên `2.9.16` và Build Number lên `154` (`v2.9.16+154`).
  * Tương thích với bản phát hành mới trên App Store Connect thay thế bản nháp 2.9.15.
- **Kế Thừa & Đóng Gói Toàn Diện Các Tính Năng Mới**:
  * Tab `Home` mặc định cho Portal User và khóa giao diện chấm công (`LucideIcons.lock`, SnackBar cảnh báo khi tenant chưa kích hoạt `hr_attendance`).
  * Sửa triệt để lỗi mở lệch ảnh trong Chat V2 (`BUG-CHATV2-IMG-MISMATCH`) bằng Strict Identity Matching (`id`, `url`, `bytes`, `messageId`).
  * Hero Tag deterministic không chứa `hashCode` và kẹp safe index tại `ChatV2ImageViewerScreen`.
  * Xóa bỏ hoàn toàn ô nhiễm RAM cache generic name `imageCache[a.name]`.
- **Kiểm Thử & Đảm Bảo Chất Lượng**:
  * Pass 100% 74/74 router & auth tests, 15/15 image viewer gallery tests, 345/345 chat v2 tests.
  * `flutter analyze`: Đạt **0 issues found** (0 errors, 0 warnings).

## [2.9.15 - Build 153] - 2026-10-08

### 🚀 Mở Tab Trang Chủ Portal, Khóa Chấm Công Động & Sửa Lỗi Lệch Ảnh Chat V2
- **Cập Nhật TabBar Động Cho Portal User (`AppScaffold`)**:
  * Bổ sung Tab `Home` (`/home`) vào danh sách 3 Tabs mặc định của Portal User: `Home`, `Chat`, `Tôi` (kèm `Ticket` nếu tenant cài module `helpdesk`).
  * Fallback nút Quay lại (`onBack`) điều hướng an toàn về `/home`.
- **Mở Khóa Truy Cập & Bảo Vệ Điều Hướng (`GoRouter` Guard)**:
  * Cho phép Portal User truy cập `/home`. Chặn và điều hướng an toàn về `/home` đối với `/timesheet` và các phân hệ chưa cài đặt (`/attendance` khi `hasAttendance == false`, `/tickets` khi `hasHelpdesk == false`).
- **Trạng Thái Khóa Giao Diện Chấm Công 🔒 (`HomeScreen`)**:
  * Khi tenant chưa cài module `hr_attendance` (`hasAttendance == false`): Nút trạng thái chấm công hiển thị `LucideIcons.lock` và nhãn `Khóa 🔒` với giao diện muted; Thẻ ca làm việc hiển thị `Chấm công (Đã khóa 🔒)` và cảnh báo SnackBar khi chạm.
  * Khi tenant đã cài đặt `hr_attendance`: Vận hành đầy đủ chức năng check-in/out, GPS và thanh tiến độ.
- **Khắc Phục Dứt Điểm Lỗi Lệch Hình Ảnh Trong Chat V2 (`BUG-CHATV2-IMG-MISMATCH`)**:
  * Áp dụng Strict Identity Matching ưu tiên theo ID, URL, Bytes, `messageId`, loại bỏ hoàn toàn so khớp lỏng lẻo theo tên file generic (`image.png`, `photo.jpg`).
  * Bảo toàn `initialIndex`, `allImages`, `message.id` trong callback `onImageTap`.
  * Khởi tạo Hero tag xác định tuyệt đối không chứa `hashCode` và kẹp an toàn trang đầu tại `ChatV2ImageViewerScreen`.
  * Dọn dẹp cache RAM theo tên file chung `imageCache[a.name]`.
- **Kiểm Thử & Đảm Bảo Chất Lượng**:
  * Pass 100% 74/74 router & auth tests, 15/15 image viewer gallery tests, 345/345 chat v2 tests.
  * `flutter analyze`: Đạt **0 issues found** (0 errors, 0 warnings).

## [2.9.15 - Build 152] - 2026-10-07

### 🚀 Đồng Bộ Biệt Danh Hai Chiều Web & Mobile & Chuẩn Hóa Thông Báo Đẩy
- **Đồng Bộ Biệt Danh Hai Chiều Web & Mobile Thời Gian Thực (Bidirectional Nickname Sync)**:
  * **Mobile sang Web**: Cập nhật biệt danh gọi API `/api/v1/mobile/chat/channels/<id>/nickname` hỗ trợ cả `nickname` và `custom_channel_name` (Odoo Discuss native), cam kết giao dịch DB tức thì và phát bus notification `discuss.channel.member/nickname_updated`.
  * **Web sang Mobile**: Lắng nghe bus sự kiện Odoo Discuss từ Web Client, cập nhật tức thì vào `ChatV2ChannelLocalCache`, danh sách thành viên kênh và hiển thị tên tác giả tin nhắn (`authorName`) trong bong bóng chat.
  * Cung cấp dialog đổi biệt danh từng thành viên trong Info Sheet và hỗ trợ xóa biệt danh trở về tên gốc.
- **Chuẩn Hóa Tiêu Đề & Nội Dung Thông Báo Đẩy (Push Notification Contract Clean Preview)**:
  * Chat 1-1 trực tiếp: Tiêu đề là tên người gửi (`author_name`), nội dung là tin nhắn sạch sẽ, loại bỏ trùng lặp tên.
  * Chat nhóm/kênh: Tiêu đề là tên nhóm (`channel_name`), nội dung là `Tên người gửi: Nội dung tin nhắn`.
  * Lọc sạch tên file hash kỹ thuật rác (VD `db83754e...mp4`), tự động hiển thị nhãn thân thiện: `🎙️ Tin nhắn thoại`, `🎬 Video`, `🖼️ Hình ảnh`, `📎 Tài liệu PDF`, `📎 Bảng tính Excel`,...
- **Kiểm Thử & Đảm Bảo Chất Lượng**:
  * Pass 100% 20/20 unit tests đồng bộ biệt danh và 11/11 contract tests định dạng push notification.
  * `flutter analyze` đạt 0 errors, 0 warnings.

## [2.9.15 - Build 151] - 2026-10-07

### 🚀 Nâng Cấp Giao Diện & Tiện Ích Media Viewer
- **Lướt Ảnh Trực Tiếp Từ Tin Nhắn Chat (In-Chat Feed Gallery Binding)**:
  * `ChatV2DetailScreen`: Kết nối `onImageTap` tự động gom toàn bộ ảnh của phòng chat theo trình tự thời gian; dù tin nhắn chỉ có 1 ảnh đơn lẻ vẫn vuốt chuyển ảnh qua lại mượt mà chuẩn Zalo/Telegram.
  * **Bảo Vệ Bộ Nhớ Đệm (Memory Pruning)**: Tự động xả ảnh bitmap ngoài tầm nhìn (`_pruneOffscreenBytes`), duy trì tối đa 5 ảnh giải mã trong RAM, chống tràn bộ nhớ (OOM) và giật lag trên thiết bị cấu hình yếu.
- **Tiện Ích Media Viewer (Xoay 90° & Chia Sẻ Ảnh Native)**:
  * Nút Xoay ảnh 90° (`LucideIcons.rotateCw`) theo chu kỳ 4 nấc: `0° ➔ 90° ➔ 180° ➔ 270° ➔ 0°`.
  * Tự động đưa ma trận zoom về Identity khi xoay ảnh và tự động reset góc xoay về 0° khi vuốt chuyển trang.
  * Nút Chia sẻ ảnh native (`share_plus`) mở System Share Sheet (iOS UIActivityViewController / Android Intent ACTION_SEND) với popover origin cho iPad / Tablet.
- **Tương Thích Đồ Họa Android & Waydroid**:
  * Tắt Impeller Vulkan (`EnableImpeller = false`), chuyển về engine đồ họa Skia OpenGL tương thích 100% trên Android, sửa triệt để lỗi kẹt màn hình Splash trên giả lập/Waydroid.
- **Nghiệm Thu L5 Waydroid Real-Device**: Pass 100% 8/8 test points cử chỉ xoay, reset, lướt và chia sẻ ảnh trên Waydroid Android 13 thật (`integration_test/chat_v2_media_viewer_utilities_e2e_test.dart`).

## [2.9.15 - Build 150] - 2026-10-07

### 🚀 Nâng Cấp Giao Diện & Trải Nghiệm Khách Hàng
- **Trình Xem & Lướt Ảnh Đa Điểm Chat V2 (Swipeable Image Gallery)**:
  * Nâng cấp `ChatV2ImageViewerScreen` hỗ trợ `PageView.builder` vuốt chuyển ảnh trái/phải mượt mà chuẩn Zalo/Telegram.
  * Mở đúng vị trí ảnh được chọn (`initialIndex`) từ danh sách đính kèm của tin nhắn hoặc Info Sheet Media.
  * **Liên Kết Trực Tiếp Từ Tin Nhắn Chat (Chat Feed Gallery Binding)**: `ChatV2DetailScreen` kết nối `onImageTap` tự động gom toàn bộ ảnh của phòng chat theo trình tự thời gian; dù tin nhắn chỉ có 1 ảnh đơn lẻ vẫn vuốt xem được ảnh trước và sau của toàn bộ cuộc trò chuyện.
  * Tích hợp Bộ đếm chỉ số ảnh động `[Trang hiện tại / Tổng số ảnh]` (VD: `3 / 5`), tự động ẩn khi xem ảnh đơn lẻ.
  * Xử lý xung đột cử chỉ (Gesture Disambiguation): Tự động chuyển PageView sang `NeverScrollableScrollPhysics` khi ảnh phóng to (`scale > 1.05`), cho phép pan/zoom tự do trong `InteractiveViewer`; chuyển lại `BouncingScrollPhysics` khi unzoomed.
  * Độc lập quản lý `TransformationController` theo từng trang (`Map<int, TransformationController>`), tự động đưa ảnh ngoài tầm nhìn về kích thước chuẩn.
  * **Bảo Vệ Bộ Nhớ Đệm (Memory Pruning)**: Tự động xả ảnh bitmap ngoài tầm nhìn (`_pruneOffscreenBytes`), duy trì tối đa 5 ảnh trong RAM, chống giật lag và chống tràn bộ nhớ (OOM) tuyệt đối.
  * Hỗ trợ thao tác Zoom 2 ngón (Pinch-to-zoom / Double-tap), nút Xoay ảnh 90° (`RotatedBox`), nút Chia sẻ ảnh (`share_plus`) và nút Lưu ảnh active vào Thư viện hệ thống (`GallerySaver.saveImage`).
- **Nghiệm Thu L5 Waydroid**: Đã test pass 100% toàn bộ kịch bản trên thiết bị thật Waydroid Android 13 (API 33): lướt ảnh PageView, zoom, xoay ảnh 90° chu kỳ 4 nấc, reset xoay khi swipe, reset zoom khi xoay và kích hoạt System Share Sheet (`integration_test/chat_v2_media_viewer_utilities_e2e_test.dart`).

## [2.9.14 - Build 149] - 2026-10-04

### 🚀 Dynamic Model Discovery, Phân Luồng Portal 2-3-5 Tabs & Nâng Cấp Train Version App Store
- **Nâng Cấp Train Version App Store Connect (TestFlight Submission)**:
  - Nâng `CFBundleShortVersionString` từ `2.9.13` lên `2.9.14` (Build 149) theo yêu cầu bắt buộc của Apple (giải quyết lỗi `90186 - Invalid Pre-Release Train` và `90062 - CFBundleShortVersionString must contain a higher version than previously approved version`).
- **Phân Luồng & Điều Hướng Động Portal User (Dynamic Model Discovery)**:
  - `auth_user.dart`: Phân tích `installed_modules` từ metadata người dùng (`hasHelpdesk`, `hasTimesheet`, `hasAttendance`, `hasProject`).
  - `odoo_api_client.dart`: Thêm phương thức tra cứu động `getDiscovery()` từ endpoint `/api/v1/mobile/user/discovery`.
  - `app_scaffold.dart`: Thanh Floating Tab Bar co giãn đều bằng `Row` & `Expanded`. Tự động co về 2 tab (`Chat`, `Tôi`) hoặc 3 tab (`Ticket`, `Chat`, `Tôi`) cho Portal User, và 5 tab (`Home`, `Chat`, `Timesheet`, `Ticket`, `Tôi`) cho Nhân viên nội bộ.
  - `app_router.dart`: Guard điều hướng thông minh — Portal User khi đăng nhập vào hệ thống không có Helpdesk sẽ được chuyển hướng thẳng tới màn hình Chat (`/chat`), tự động chặn chuyển hướng vào `/tickets` khi không có quyền.
- **Kiểm Thử & Đảm Bảo Chất Lượng**:
  - Pass 12/12 unit tests trong `test/features/auth/dynamic_discovery_portal_test.dart`.
  - Kiểm chứng thực tế L5 trên Waydroid Android 13: Portal User đăng nhập co về 2 tab, Nhân viên nội bộ hiển thị đủ 5 tab.
  - `flutter analyze`: Đạt 0 issues found (0 errors, 0 warnings).

## [2.9.13 - Build 148] - 2026-10-04

### 🛡️ Tuân Thủ Chính Sách Quyền Ảnh & Video Google Play, Sửa BUG-024 & Chat V2 Mute Picker
- **Tuân Thủ Chính Sách Photo & Video Permissions Google Play (Tháng 10/2026)**:
  - `AndroidManifest.xml`: Cấu hình `tools:node="remove"` loại bỏ triệt để các quyền media broad access (`READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`, `READ_EXTERNAL_STORAGE`) do thư viện bên ngoài inject.
  - Chuyển đổi 100% sang Android Photo Picker (SAF) chuẩn hệ thống không cần cấp quyền diện rộng.
  - Đóng gói bản ký số `app-release.aab` (85MB), versionCode 148 đạt chuẩn phê duyệt Google Play Console.
- **Khắc Phục Lỗi Đảo Dòng Thời Gian & Quote Reply (BUG-024)**:
  - `chat_v2_messages_controller.dart`: Chuẩn hóa hàm `_mergeMessages` duy trì quy tắc sắp xếp giảm dần `createdAt desc` (tie-break `id desc`) trên `ListView.builder(reverse: true)`, ghim tin nhắn tạm `temp_*` lên đỉnh. Khắc phục triệt để lỗi nhảy tin nhắn cũ xuống đáy khi polling.
  - Backend Odoo Discuss: Bọc `Markup(clean_body)` trong controllers, ngăn core Odoo auto-escape làm lộ mã HTML thô trên Web khi người dùng reply.
  - Chuẩn hóa nhãn Reply: Hiển thị nhãn người dùng thân thiện `[Hình ảnh]`, `[Video]`, `[Tin nhắn thoại]` thay vì tên tệp kỹ thuật thô (`image_picker_...jpg`).
  - Pass 10/10 tests trong `test/features/chat_v2/chat_v2_messages_controller_test.dart`.
- **Giao Diện Chọn Thời Gian Tắt Thông Báo Kênh (Chat V2 Mute Picker)**:
  - Bổ sung Modal BottomSheet `ChatV2MuteDurationSheet` trực quan với 4 mức thời gian: 1 giờ, 8 giờ, 24 giờ, Vô thời hạn.
  - Hiển thị icon chuông tắt tiếng `LucideIcons.bellOff` trên AppBar phòng chat khi kênh bị tắt thông báo.
  - Đồng bộ realtime bus với Odoo 19 qua sự kiện `_notify_mute()` tự động kích hoạt cron unmute đúng hạn.
  - Pass 14/14 tests trong `test/features/chat_v2/chat_v2_mute_test.dart`.

## [2.9.13 - Build 147] - 2026-10-03

### 🎬 Gửi & Phát Video In-App và Lưu Native Gallery
- **Gửi & Xem Video Trực Tiếp Trong Chat V2**:
  - Hỗ trợ chọn/quay video từ thiết bị, xem trước trên thanh nhập liệu kèm nút hủy.
  - Hiển thị bong bóng video `ChatV2VideoBubble` tinh tế với biểu tượng Play hình tròn và huy hiệu hiển thị dung lượng (MB/KB) chuẩn Refined Tech Luxury.
  - Sửa lỗi bubble video bị ẩn khi tin nhắn không kèm text (`isEmptyMessage` trong `ChatV2MessageItem`).
  - Trình phát video toàn màn hình `ChatV2VideoPlayerScreen` chuyên nghiệp: thanh seekbar, hiển thị thời lượng, phím Play/Pause/Replay, bật/tắt tiếng (Mute/Unmute).
- **Lưu Video Thẳng Vào Thư Viện Ảnh Gốc (Photos Album / MediaStore)**:
  - Tích hợp package `gal: ^2.3.3` trong `GallerySaver.saveVideo()`, hỗ trợ lưu trực tiếp vào Photos Album (iOS) và MediaStore (Android).
  - Tự động xin quyền thư viện ảnh (`Gal.requestAccess()`), lưu cache file tạm an toàn và tự động dọn dẹp sau khi ghi vào album.
  - Multi-tier Fallback: Bọc an toàn `GalException`, tự động chuyển tầng lưu qua `saveBytesToFile` khi chạy trên giả lập thiếu MediaStore (Waydroid).
  - Thêm nút Lưu video trên AppBar của `ChatV2VideoPlayerScreen` với thông báo Toast/SnackBar tiếng Việt trực quan.
- **Backend Odoo 17 & 19 (`v_mobile_17` & `v_mobile_19`)**:
  - Tự động nhận diện MIME types video (`.mp4`, `.mov`, `.mkv`, `.avi`, `.3gp`, `.webm`).
  - Bổ sung định dạng xem trước `[Video]` cho danh sách kênh chat (`list_channels`).
- **Kiểm Thử Độc Lập**:
  - Pass 16/16 test cases trong `test/features/chat_v2/chat_v2_video_messaging_test.dart`.
  - Khóa cổng kiểm soát `flutter analyze` đạt 0 errors, 0 warnings.

## [2.9.12 - Build 146] - 2026-10-01

### 🎨 Tối Ưu Theme & Độ Tương Phản Màn Hình "Hồ Sơ Cá Nhân" (Edit Profile Screen)
- **Làm Nổi Bật Tiêu Đề Trường Thông Tin**: Thêm thanh chỉ báo màu xanh thương hiệu (`AppColors.primary`) và nâng cấp màu chữ tiêu đề ("Họ và tên", "Chức vụ", "Công ty", "Email") lên màu trắng sáng `Color(0xFFF1F5F9)` kèm font weight `FontWeight.w700` trong Dark Mode, chống hiện tượng tiêu đề bị chìm vào nền card tối.
- **Sửa Lỗi Nền Khung Giá Trị Bị Biến Thành Màu Trắng**: Sửa container hiển thị giá trị trường thông tin từ màu trắng cố định (`AppColors.bg`) sang màu nền tối `Color(0xFF0F172A)` với đường viền tinh tế `Color(0xFF334155)` khi ở Dark Mode. Chữ giá trị chuyển sang màu trắng sắc nét.
- **Chuẩn Hóa Giao Diện Đổi Avatar & AppBar**:
  - `_showAvatarPickerSheet`: BottomSheet hiển thị nền tối `Color(0xFF1E293B)` và chữ màu sáng `Color(0xFFF1F5F9)` trong Dark Mode.
  - `AppScaffold`: AppBar tự động nhận biết Dark Mode, sử dụng nền phẳng tối `Color(0xFF1E293B)` với đường viền tóc 1px thay vì dải gradient xanh neon chói mắt.
- **Kiểm Thử Toàn Diện**: Mở rộng `test/features/profile/profile_edit_test.dart` lên 11 test cases độc lập (tất cả pass 100%).

## [2.9.12 - Build 145] - 2026-10-01

### 🐛 Sửa Lỗi Tiêu Đề Kênh Nhóm "Internal" Bị Biến Thành "Chau, Le Ba (Internal)" Trên iPhone (TestFlight)
- **Root Cause**: Khi người dùng nhận Push Notification Odoo định dạng `{author_name} ({channel.name})`, tiêu đề `"Chau, Le Ba (Internal)"` bị router nạp vào query param `name`, `ChatV2DetailScreen` ghi đè thành kênh chat 1-1 giả lập vào `_pinnedDirectChannels` của `FlutterSecureStorage`. Khi API trả về đúng `"Internal"`, hàm `ChatV2ChannelLocalCache.set()` ưu tiên lấy tên trong pinned direct cache đè lên tên từ API.
- **Bản Vá & Bảo Vệ**:
  - Nâng cấp `ChatV2Channel.cleanChannelName()` & `getCleanName()`: Thêm Master Regex phát hiện và bóc tách chuẩn xác định dạng `{author_name} ({channel.name})` về `"Internal"` cho kênh nhóm.
  - Sửa `ChatV2ChannelLocalCache.set()`: Với kênh nhóm, tên từ API Odoo luôn là SSOT tuyệt đối 100%, đồng thời tự động phát hiện và xóa kênh nhóm khỏi `_pinnedDirectChannels` trong bộ nhớ và disk storage.
  - Sửa `ChatV2ChannelLocalCache.init()`: Tự động thanh lọc các bản ghi rác trong `pinned_direct_channels_v2` và làm sạch tên kênh lưu trong `cached_channels_v3`.
  - Cập nhật `pinDirectChannel()` & `ChatV2DetailScreen`: Tuyệt đối không lưu Group Channel hoặc kênh `Internal` vào `_pinnedDirectChannels`.
  - Bổ sung 7 test case đặc trị trong `test/features/chat_v2/chat_v2_channel_sanitize_test.dart` (pass 20/20 test).

## [2.9.12 - Build 144] - 2026-10-01

### 🚀 Bổ Sung & Nâng Cấp Hệ Thống
- **Danh Mục Tính Năng Toàn Diện**: Đã tổng hợp đầy đủ 78 tính năng hệ thống VCloud Mobile App & Odoo Backend tại `docs/FEATURES_CATALOG.md`.
- **API Backend Fixes**: Cập nhật các bản vá API Chat V2, WebRTC Signaling, Lazy UUID generation chống 404 và tối ưu query DB cho Odoo 17 & 19.

⚠️ **LƯU Ý QUAN TRỌNG KHI RE-AUDIT / DEPLOY**:
1. Đối với Odoo Backend (`v_mobile_17` & `v_mobile_19`): Bắt buộc chạy lệnh nâng cấp module **`vmobile`** trên Odoo Server (`odoo-bin -u vmobile`).
2. Tham chiếu chi tiết 78 tính năng tại: `docs/FEATURES_CATALOG.md`.
