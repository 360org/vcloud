# Báo cáo Audit Kỹ thuật VCloud (Flutter Client)

| Hạng mục | Thông tin |
|---|---|
| Revision audit | `1c9b4a0` — `feat(auth-chat): batch upload media, clean category labels and permission updates (v2.9.9+132)` |
| Ngày rà soát | 2026-09-21 |
| Phiên bản | `2.9.9+132` |
| Phạm vi | Flutter client VCloud; backend Odoo `v_mobile` nằm ngoài repository và không được thay đổi trong đợt này. |
| Trạng thái nhánh | `main` là nhánh local duy nhất, đang hơn `origin/main` 6 commit trước khi push; cleanup tài liệu/cấu hình hiện còn chưa commit. |

## 0. Trạng thái kiểm chứng

Đã chạy trên Local Server từ archive sạch của revision `1c9b4a0`, không ghi đè working tree đang có thay đổi tại server:

| Kiểm chứng | Lệnh | Kết quả |
|---|---|---|
| Phân tích tĩnh | `flutter analyze` | ✅ `No issues found! (ran in 11.1s)` |
| Bộ test không cần live server | `flutter test --exclude-tags=live-server` | ✅ `00:51 +363: All tests passed!` |

**Chưa xác minh sau các thay đổi chưa commit của đợt cleanup này:** `flutter analyze`, full test suite và kiểm thử Android/iOS native. Các mục liên quan quyền Photo Picker, đăng xuất cache và ký Android phải được chạy lại trước khi phát hành.

**Phạm vi kiểm tra native còn thiếu:** Android API 33+ (một/nhiều ảnh, ảnh+video, huỷ picker, camera, không có gallery permission), Android 12 trở xuống, media quá giới hạn hoặc vượt 9 tệp, retry upload; iOS và Android với quyền notification/exact alarm được cấp hoặc từ chối.

**Ghi chú:** `flutter_local_notifications` có caller xin quyền riêng nhưng chưa có caller cho `AttendanceLocalReminderService.requestPermissions()`. Lời gọi Firebase Messaging không thay thế cho kiểm tra exact alarm.

## 1. Bảng tổng hợp phát hiện theo mức ưu tiên

| # | Mức | Nhóm | Vấn đề | Vị trí |
|---|---|---|---|---|
| 1.1 | 🔴 P1 | Bảo mật | Gửi password lên Master trong `lookupDb`, trái ngược chính doc comment ngay phía trên | `odoo_api_client.dart:395-440` |
| 1.2 | 🟠 P2 | Bảo mật | Phát tán song song credential tới 2 domain khác nhau khi đăng nhập | `odoo_api_client.dart:253-273` |
| 1.3 | ✅ Đã sửa, chờ test lại | Riêng tư | Cache attachment được xóa khi đăng xuất | `auth_controller.dart:127-135` |
| 1.4 | 🟡 P3 | Bảo mật | Log debug in header/body/stack trace của luồng auth & tải file | `odoo_api_client.dart:990-1012`, `:353,357,372,387` |
| 1.5 | 🟡 P3 | Bảo mật | Hardcode mapping khách hàng (`nds` / `ndsgroup.vn` / `project_id: 7790`) trong client | `odoo_api_client.dart:447-458, 503-515, 576-588` |
| 2.1 | 🔴 P1 | Độ tin cậy | Không kiểm tra quyền exact alarm trước khi dùng lịch chính xác | `attendance_local_reminder_service.dart:108-133`, `AndroidManifest.xml:10` |
| 2.2 | 🟠 P2 | Độ tin cậy | Timezone chỉ hoạt động nhờ đường exception fallback | `attendance_local_reminder_service.dart:42-52` |
| 2.3 | 🟠 P2 | Kiến trúc | Side-effect bất đồng bộ, không `unawaited`, đặt trong thân Riverpod provider | `attendance_controller.dart:342-358` |
| 2.4 | 🟠 P2 | Độ tin cậy | Mutex refresh token bằng `delay(500ms)` — có thể đá user ra login | `odoo_api_client.dart:1176-1182` |
| 2.5 | 🟡 P3 | Độ rõ ràng | Cộng `+5` phút trực tiếp vào constructor `TZDateTime` | `attendance_local_reminder_service.dart:164,174` |
| 3.1 | 🟡 P3 | Nợ kỹ thuật | God file: 4 file > 2.000 dòng, file lớn nhất 4.500 dòng | `timesheet_list_screen.dart` … |
| 3.2 | 🟡 P3 | Test | 0% coverage cho reminder service, session store, attachment cache | (xem §3.2) |
| 3.3 | 🟡 P3 | Nợ kỹ thuật | 2 package discontinued, 18 package bị chặn nâng cấp | `pubspec.yaml` |
| 3.4 | ⚪ P4 | Vệ sinh | 2 dòng trống thừa cuối file; dọn dẹp các nhánh remote cũ | (xem §4) |

---

## 2. 🛡️ Bảo mật & Quyền riêng tư

### 1.1 — 🔴 P1: `lookupDb` gửi password lên Master, trái với chính comment của nó

**Vị trí:** `lib/core/api/odoo_api_client.dart:395-440`

Doc comment ghi:
```dart
/// PAYLOAD CHỈ CHỨA: `{"login": "client_db1_user"}`
/// ⚠️ TUYỆT ĐỐI KHÔNG BẮT GỬI PASSWORD LÊN MASTER!
Future<List<Map<String, dynamic>>> lookupDb(String login, {String? password, ...})
```
Nhưng thân hàm ngay dưới (dòng 434-440) lại làm đúng điều bị cấm:
```dart
body: jsonEncode({
  'login': trimmedLogin,
  if (password != null && password.isNotEmpty) 'password': password,
  ...
}),
```

**Kịch bản lỗi:** Người dùng của tenant khách hàng (VD `ndsgroup.vn`) nhập mật khẩu → mật khẩu plaintext được POST lên `vuahethong.net` (một hệ thống khác tenant đích). Master ghi access log/body log hoặc bị compromise ⇒ lộ mật khẩu của người dùng thuộc mọi tenant. Đây cũng vi phạm quy tắc trong `CLAUDE.md` của dự án: *"never hard-code or log raw JWT/FCM/password values"* xét về tinh thần tối thiểu hóa lan truyền credential.

**Đề xuất tối thiểu:** Bỏ trường `password` khỏi payload `lookup-db` và khỏi chữ ký hàm; nếu backend hiện đang **yêu cầu** password để phân giải DB thì đây là lỗi thiết kế thuộc repo `v_mobile` và phải sửa bên đó, không vá bằng client.
**Cảnh báo quan trọng:** dòng 445 xử lý `400` như tín hiệu "backend live chưa deploy bản bỏ password" ⇒ trước khi gỡ, **phải xác nhận bản backend đang chạy production** đã chấp nhận payload không password, nếu không sẽ làm hỏng đăng nhập.

**Tiêu chí kiểm thử:** dựng `MockClient` assert body của `POST /api/v1/auth/lookup-db` không chứa key `password`; test đầy đủ trên tài khoản nội bộ, tài khoản khách hàng, demo/morpheus, tài khoản multi-tenant, và với Local Server.

### 1.2 — 🟠 P2: Đăng nhập phát tán credential song song tới hai domain

**Vị trí:** `lib/core/api/odoo_api_client.dart:253-273`
```dart
await Future.wait([
  _tryFullLoginAt(targetBaseUrl: primaryBaseUrl, login: trimmedLogin, password: password, ...),
  _tryFullLoginAt(targetBaseUrl: demoBaseUrl,    login: trimmedLogin, password: password, targetDb: 'demo', ...),
]);
```
Cùng một cặp login/password được gửi đồng thời tới `vuahethong.net` **và** `demo.vuahethong.com`.

**Kịch bản lỗi:** Người dùng chỉ có tài khoản ở tenant production, nhưng mật khẩu của họ vẫn được chuyển tới hệ thống demo (môi trường thường có mức bảo vệ/patch/log thấp hơn). Nếu người dùng dùng chung mật khẩu, một sự cố trên demo trở thành sự cố credential trên production. Ngoài ra tạo nhiễu cho hệ thống dò đăng nhập sai (2 lần fail/1 lần thử).

**Đề xuất tối thiểu:** Dùng kết quả `lookupDb` (không password) làm nguồn chân lý để chọn đúng **một** domain, chỉ khi đó mới gửi password. Trường hợp thật sự đa tenant thì để backend trả `409 multiple_tenants` (code đã hỗ trợ sẵn tại `_tryMultipleTenants`, dòng 1203).

### 1.3 — ✅ Đã sửa, chờ kiểm chứng native: Xóa cache tệp đính kèm khi đăng xuất

**Vị trí:** `lib/features/auth/application/auth_controller.dart:127-135`
```dart
Future<void> signOut() async {
  await _unregisterPushDevice();
  ChatV2ChannelLocalCache.clear();
  ChatV2MessageLocalCache.clear();
  TimesheetRepository.clearCache();
  await LocalAttachmentCache.clearAllCache();
  await _repo.signOut();
  state = const AsyncData(null);
}
```

`LocalAttachmentCache.clearAllCache()` đã xóa RAM cache, file `attachments/*.bin` trên mobile và cache web. Điều này chặn việc người dùng B đọc attachment của người dùng A trên thiết bị dùng chung.

**Còn thiếu trước khi đóng mục:** kiểm thử Android/iOS/Web: đăng nhập A → tải ảnh/tệp → đăng xuất → xác nhận thư mục cache hoặc `localStorage` rỗng → đăng nhập B → tải lại tệp mới thành công. Cần một unit test riêng cho luồng `signOut()` khi service path-provider được mock ổn định.

### 1.4 — 🟡 P3: Log debug quá chi tiết ở luồng auth và tải tệp

**Vị trí:** `lib/core/api/odoo_api_client.dart:990-1012` (khối `kDebugMode` in `All Headers`, `Body Preview (Text)`), và các dòng `353`, `357`, `372`, `387`, `859` in stack trace/thân phản hồi của luồng đăng nhập.

**Kịch bản lỗi:** Khối này chỉ chạy trong `kDebugMode` nên **không rò rỉ ở bản release**, mức độ vì vậy là P3. Tuy nhiên trong phiên debug trên máy lập trình viên/CI có log lưu trữ, header phản hồi và preview body có thể chứa cookie phiên Odoo, và các dòng auth có thể in nội dung phản hồi đăng nhập. Rủi ro thực tế: log CI bị chia sẻ hoặc lưu artifact.

**Đề xuất tối thiểu:** lọc allowlist header khi in (chỉ `content-type`, `content-length`), không in `All Headers`; với luồng auth in loại lỗi thay vì nguyên body.

### 1.5 — 🟡 P3: Hardcode danh bạ khách hàng trong client

**Vị trí:** `lib/core/api/odoo_api_client.dart:447-458`, `:503-515`, `:576-588`
```dart
if (lowerLogin == 'support@360.org.vn' || lowerLogin == 'portal@360.org.vn') {
  return [{ 'database_name': 'nds', 'database_url': 'https://ndsgroup.vn', 'project_id': 7790, ... }];
}
```
Cùng một khối fallback bị lặp lại **3 lần** trong một hàm.

**Kịch bản lỗi:** (a) Thông tin khách hàng (tên DB, domain, project id) nằm trong binary phát hành công khai — ai giải nén IPA/AAB đều đọc được bản đồ hạ tầng. (b) Khi NDS đổi domain hoặc DB, phải phát hành app mới thay vì sửa cấu hình server. (c) Ba bản sao dễ lệch nhau khi sửa chỉ một chỗ.

**Đề xuất tối thiểu:** Gom 3 khối thành một hằng số/`_fallbackDirectory` duy nhất trong ngắn hạn; dài hạn chuyển hẳn việc phân giải DB về Master directory (`v_mobile`) và bỏ fallback hardcode.

---

## 3. ⚡ Độ tin cậy, Hiệu năng & Kiến trúc

### 2.1 — 🔴 P1: Chưa kiểm tra quyền exact alarm trước khi lập lịch

**Vị trí:** `lib/core/notifications/attendance_local_reminder_service.dart:108-133, 226-233, 289-296`; `android/app/src/main/AndroidManifest.xml:10`

`PushNotificationService.registerCurrentDevice()` đã gọi `FirebaseMessaging.requestPermission()` khi đăng ký thiết bị, nên không còn kết luận rằng notification permission không có caller. Tuy vậy, app khai báo `SCHEDULE_EXACT_ALARM` và dùng `AndroidScheduleMode.exactAllowWhileIdle` nhưng không kiểm tra `canScheduleExactAlarms` hoặc fallback khi exact alarm bị tắt.

**Kịch bản lỗi:** Trên thiết bị Android hạn chế exact alarm, `zonedSchedule` có thể ném lỗi. Hai hàm schedule chỉ ghi `debugPrint` trong `catch`, vì vậy người dùng không nhận nhắc check-in/check-out mà không biết nguyên nhân.

**Đề xuất tối thiểu:** Trước khi dùng lịch chính xác, kiểm tra quyền exact alarm; nếu không được phép, chuyển sang lịch inexact hoặc thông báo cách bật quyền tại màn hình nhắc chấm công.

**Tiêu chí kiểm thử native:** Android API 33+ cấp/từ chối notification; Android exact alarm bật/tắt; Android 12 trở xuống; iOS cấp/từ chối; chưa check-in, đang mở ca, đã check-out, Chủ Nhật và khởi động lại thiết bị.
### 2.2 — 🟠 P2: Timezone chỉ đúng nhờ đường exception

**Vị trí:** `lib/core/notifications/attendance_local_reminder_service.dart:42-52`
```dart
final currentTimeZone = DateTime.now().timeZoneName;   // VD: "+07", "ICT", "GMT+7"
try {
  tz.setLocalLocation(tz.getLocation(currentTimeZone));
} catch (_) {
  tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
}
```
`DateTime.timeZoneName` trả về **tên viết tắt của hệ điều hành** (`+07`, `ICT`, `GMT+7`), gần như không bao giờ là ID IANA hợp lệ ⇒ trong thực tế nhánh `try` luôn ném và app luôn rơi vào fallback cứng `Asia/Ho_Chi_Minh`.

**Kịch bản lỗi:** (a) Nhân viên đi công tác/làm remote ở múi giờ khác: lịch nhắc vẫn tính theo giờ Việt Nam, thông báo hiện sai giờ so với ca làm địa phương. (b) Nếu một nền tảng nào đó tình cờ trả về một tên viết tắt **trùng** với một location hợp lệ trong DB tz, kết quả có thể là một múi giờ hoàn toàn khác — sai âm thầm, khó truy vết. (c) Khối bọc ngoài `catch (e)` (dòng 50) khiến cả hai thất bại đều chỉ còn một dòng `debugPrint`.

**Đề xuất tối thiểu:** Dùng đúng nguồn IANA thay vì `timeZoneName` — hoặc đọc timezone từ cấu hình ca/nhân sự phía backend, hoặc dùng một package phân giải IANA; giữ `Asia/Ho_Chi_Minh` làm mặc định **có chủ đích** (đánh dấu `ponytail:` nêu rõ giới hạn) thay vì mặc định-do-lỗi.

### 2.3 — 🟠 P2: Side-effect async nằm trong thân Riverpod provider, không `unawaited`

**Vị trí:** `lib/features/attendance/application/attendance_controller.dart:342-358`, tiêu thụ tại `lib/app.dart:167`
```dart
final attendanceReminderSyncProvider = Provider.autoDispose<void>((ref) {
  ...
  ref.read(attendanceReminderServiceProvider).syncAttendanceReminders(   // <- Future bị bỏ rơi
        openAttendance: open, todayAttendances: todayAttendances, shiftConfig: config,
      );
});
```

**Vấn đề:** (a) Thân `Provider` được thiết kế để **tính giá trị thuần**, ở đây lại thực hiện I/O. (b) `Future` trả về không `await`, không `unawaited()` — codebase ở chỗ khác đều dùng `unawaited(...)` đúng chuẩn (`auth_controller.dart:41,78,97`; `chat_v2_messages_controller.dart:190`), nên đây là điểm lệch chuẩn nội bộ. (c) Provider này được `ref.watch` ngay trong `build()` của `MaterialApp` (`app.dart:167`) ⇒ **mỗi lần dữ liệu chấm công đổi là re-run và bắn một lượt schedule/cancel notification**.

**Kịch bản lỗi:** Trong lúc polling chấm công cập nhật liên tục, provider bị invalidate nhiều lần trong thời gian ngắn ⇒ nhiều lệnh `zonedSchedule`/`cancel` chồng nhau, chạy đua nhau không thứ tự (vì không `await`); lỗi ném ra từ Future bị bỏ rơi trở thành unhandled async error ở root zone.

**Đề xuất tối thiểu:** Bọc `unawaited(...)` ngay lập tức (sửa 1 dòng, chặn unhandled error); đúng hơn là chuyển side-effect này ra khỏi thân provider — dùng `ref.listen` ở tầng widget/`Listener` và thêm chống dội (debounce) nếu tần suất cao.

### 2.4 — 🟠 P2: Mutex refresh token bằng `delay(500ms)`

**Vị trí:** `lib/core/api/odoo_api_client.dart:1176-1182`
```dart
if (_isRefreshing) {
  await Future<void>.delayed(const Duration(milliseconds: 500));
  return _session != null && !(_session?.isExpired ?? true);
}
```

**Kịch bản lỗi:** Màn hình Home mở nhiều request song song (chat, chấm công, ticket, timesheet). Access token hết hạn ⇒ nhiều request cùng nhận 401. Request đầu bắt đầu refresh; các request còn lại ngủ đúng 500ms. Nếu mạng 3G/roaming khiến refresh mất ~1s, các request kia thức dậy khi session **vẫn còn cũ**, trả `false` ⇒ đi thẳng vào nhánh `_sessionStore.clear(); onSessionExpired()` (dòng 1160-1162) ⇒ **người dùng bị đá ra màn hình đăng nhập dù refresh sau đó thành công**.

**Đề xuất tối thiểu:** Thay bằng `Completer<bool>` dùng chung: request đầu tạo completer, các request sau `await` chính completer đó — đây là sửa đúng gốc, ngắn hơn và bỏ được hằng số 500ms tùy tiện.
**Tiêu chí kiểm thử:** test với `MockClient` mô phỏng 3 request song song nhận 401, refresh chậm 1.2s ⇒ kỳ vọng cả 3 retry thành công và `onSessionExpired` **không** được gọi.

### 2.5 — 🟡 P3: Cộng `+5` phút trực tiếp vào constructor

**Vị trí:** `attendance_local_reminder_service.dart:164,174` — `targetMinute: cfg.shiftStartMinute + 5`.
`TZDateTime` chuẩn hóa phút > 59 nên **đây không phải crash đã xác minh**; ghi nhận ở mức độ rõ ràng: ca 08:58 cho ra 09:03 là đúng nhưng hoàn toàn ngầm định, và cấu hình ca lấy từ server (`shift_calculator.dart:58`) không thấy validate miền giá trị 0-59 tại chỗ.
**Đề xuất:** validate giờ/phút khi parse cấu hình ca (trust boundary), và viết `TZDateTime(...giờ ca...).add(const Duration(minutes: 5))`.

### 3.1 — 🟡 P3: God file ở tầng presentation

| File | Số dòng |
|---|---|
| `lib/features/timesheet/presentation/timesheet_list_screen.dart` | 4.500 |
| `lib/features/chat/presentation/conversation_list_screen.dart` | 2.524 |
| `lib/features/attendance/presentation/attendance_history_screen.dart` | 2.477 |
| `lib/features/chat/presentation/widgets/chat_bubbles.dart` | 2.056 |
| `lib/features/chat_v2/presentation/widgets/chat_v2_message_item.dart` | 2.011 |
| `lib/core/api/odoo_api_client.dart` | 1.331 |

**Lưu ý bàn giao:** đây là nợ kỹ thuật, **không phải lỗi** — không nên refactor hàng loạt chỉ vì số dòng. Nguyên tắc thực dụng: mỗi lần chạm vào một trong các file này để sửa bug, tách phần vừa chạm ra widget con. `odoo_api_client.dart` đáng ưu tiên hơn cả vì nó gộp 4 vai trò (HTTP transport, auth/routing đa tenant, quản lý session, danh bạ khách hàng) — chính sự chồng lấn này sinh ra các mục 1.1, 1.2 và 1.5.

### 3.2 — 🟡 P3: Vùng trắng test coverage ở đúng những chỗ rủi ro nhất

Các module sau **không có test nào bao phủ** (xác minh bằng grep trong `test/` + `integration_test/`):

| Module | Vì sao cần test |
|---|---|
| `lib/core/notifications/attendance_local_reminder_service.dart` | Tính năng mới nhất, chứa mục P1 §2.1 và logic thời gian §2.2/§2.5 |
| `lib/core/utils/local_attachment_cache.dart` | Logic `_cleanKey` (chống path traversal) và vòng đời cache — liên quan §1.3 |
| `lib/core/api/odoo_session_store.dart` | Mọi thao tác đều nuốt lỗi bằng `catch (_) {}` ⇒ hỏng secure storage là hỏng im lặng |
| `lib/core/utils/web_storage_web.dart` | Ghi dữ liệu người dùng vào `localStorage` không mã hóa |

Lưu ý: `lookupDb` **đã có** test khá tốt tại `test/directory_lookup_auth_test.dart` (9 case) — nên bổ sung ở đây một assertion "body không chứa password" khi sửa mục 1.1 là rẻ nhất.

**Đề xuất:** ưu tiên 2 test nhỏ — (1) `AttendanceLocalReminderService.test()` cho logic chọn nhánh trong `syncAttendanceReminders` (chưa check-in / đang mở ca / đã xong / Chủ Nhật); (2) `LocalAttachmentCache._cleanKey` cho tên file có `../`, ký tự unicode, URL đầy đủ, key số thuần.

### 3.3 — 🟡 P3: Dependency

Từ `flutter pub outdated` trên đúng revision này:
- **Discontinued:** `flutter_secure_storage_macos`, `js`.
- **Bị chặn nâng cấp major (18 gói)**, đáng chú ý: `flutter_riverpod` 2.6.1 → 3.4.3, `go_router` 14.8.1 → 18.0.1, `flutter_secure_storage` 9.2.4 → 11.1.1, `geolocator` 11.1.0 → 14.0.3, `file_picker` 10.3.10 → 13.0.0, `record` 5.2.1 → 7.1.1, `rxdart` 0.27.7 → 0.28.0, `intl` 0.19.0 → 0.20.3.
- Firebase (`firebase_core`/`messaging`/`crashlytics`) chỉ lệch minor — **nâng nhóm này trước**, rủi ro thấp nhất.

**Khuyến nghị:** không nâng đồng loạt. Thứ tự an toàn: (1) nhóm minor/patch Firebase + `image_picker` + `uuid`; (2) `flutter_secure_storage` (ảnh hưởng trực tiếp session store, cần test đăng nhập/đăng xuất kỹ); (3) `go_router` và `flutter_riverpod` — hai major này đổi API nhiều, nên tách hẳn thành công việc riêng có nhánh riêng. Mỗi bước chạy lại `flutter analyze` + `flutter test`.

### 3.4 — ⚪ P4: Vệ sinh mã, docs và trạng thái nhánh

- Đã bỏ trailing whitespace tại tài liệu/sơ đồ đã chạm, path Linux cũ trong cấu hình AIaC và hardcode credential release trong CI/tài liệu.
- `origin/fix/avatar-flicker-resilience` đã được fast-forward vào `main`; chỉ được xóa sau khi push `main` thành công.
- `origin/codex/fix-chat-runner-ios` chỉ xóa workflow iOS cũ, đã bị workflow `deploy.yml` hiện tại thay thế; có thể xóa sau push `main`.
- Giữ `origin/fix/chat-v2-image-display`: patch còn có logic pending attachment và xử lý dummy MIME chưa chứng minh là đã có trong `main`.
- Local chỉ giữ nhánh `main`. Remote cleanup không thay thế review/cherry-pick nhánh còn giá trị.

---

## 4. Thứ tự xử lý đề xuất cho nhóm phát triển

**Đợt 1 — làm ngay, diff nhỏ, giá trị cao:**
1. Hoàn tất test native và regression cho §1.3, Photo Picker và CI signing cleanup của đợt này.
2. §2.3 — bọc `unawaited(...)` cho lời gọi sync reminder; chuyển side-effect khỏi provider khi có thời gian.
3. §2.1 — gọi luồng xin quyền notification sau đăng nhập hoặc từ cài đặt nhắc chấm công; kiểm tra exact alarm và có fallback inexact.

**Đợt 2 — cần phối hợp với backend `v_mobile`:**
4. §1.1 — gỡ password khỏi `lookup-db` sau khi xác nhận contract backend production.
5. §1.2 — bỏ đăng nhập song song hai domain, chọn một tenant bằng directory lookup trước khi gửi password.
6. §2.4 — thay `delay(500ms)` bằng `Completer` dùng chung.

**Đợt 3 — nợ kỹ thuật theo lịch:**
7. §2.2 timezone, §1.5 loại fallback directory hardcode, §3.2 bổ sung test, §3.3 nâng dependency theo nhóm.

## 5. Lưu ý bàn giao

- Repo này là **Flutter client**. Mọi thay đổi schema/API thuộc về repo Odoo `v_mobile`, không vá bên này. Phát hành đi qua CI/CD (Fastlane → TestFlight/Play Store) bằng tag `v*`; **không deploy repo này lên server Linux/Kubernetes**.
- Giữ `flutter analyze` ở mức 0 issue và chạy `flutter test --exclude-tags=live-server` trước mỗi lần merge lớn — hiện tại cả hai đều xanh, đừng để tụt.
- Mọi mục liên quan notification/timezone/quyền **phải verify trên thiết bị thật** rồi mới được báo hoàn thành; phân tích tĩnh không đủ.
- Lỗi trong service nhắc chấm công hiện bị nuốt toàn bộ bằng `catch → debugPrint`. Trong lúc chưa refactor, khi điều tra sự cố "không nhận được thông báo", hãy đọc log với tiền tố `[AttendanceReminder]` trước tiên.
