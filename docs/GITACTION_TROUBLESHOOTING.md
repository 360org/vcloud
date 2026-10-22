# 🛠️ GITHUB ACTIONS CI/CD TROUBLESHOOTING & POST-MORTEM

Tài liệu ghi lại sự cố pipeline GitHub Actions, phân tích nguyên nhân gốc rễ và cơ chế phòng ngừa lỗi hồi quy trong quá trình Build & Release tự động cho **VCloud (vclients)**.

---

## 1. Thông Tin Sự Cố

- **Workflow Run ID**: `39748658033`
- **Tên Workflow**: `Build & Release (Android APK, AAB, iOS TestFlight)`
- **Thời gian phát sinh**: `2026-10-22`
- **Nhánh**: `main`
- **Tag kích hoạt**: `v2.9.22+166`
- **Trạng thái**: ❌ **FAILED** tại step `Run Flutter Static Analysis & Unit Tests` (cả job Android và iOS runner).

---

## 2. Nhật Ký Lỗi & Phân Tích Hiện Tượng

### Log từ GitHub Actions Runner:
```text
Analyzing vcloud...

warning • Returning a 'Future' without 'await' inside a try block. Try adding an 'await' • lib/features/auth/data/auth_repository.dart:118:9 • unawaited_return_in_try_block

1 issue found. (ran in 18.3s)
##[error]Process completed with exit code 1.
```

### Hiện tượng:
Pipeline CI/CD bị ngắt do `flutter analyze` phát hiện 1 warning và trả về exit code 1 theo chính sách nghiêm ngặt (Zero Warnings/Errors).

---

## 3. Phân Tích Kỹ Thuật & Root Cause

### 3.1. Lỗi Linter: `unawaited_return_in_try_block` (Dart SDK 3.12+)
- **Vị trí**: `lib/features/auth/data/auth_repository.dart:118:9`
- **Nguyên nhân**: Trong phương thức `currentUser()`, đoạn code bên trong khối `try` thực thi:
  ```dart
  if (profile == null) {
    return _toUser(session); // _toUser là hàm async trả về Future<AuthUser>
  }
  ```
  Khi trả về một `Future` từ trong khối `try` mà không có từ khóa `await`, nếu Future đó bị reject trong microtask queue, ngoại lệ sẽ không bị bắt bởi khối `catch` của hàm hiện tại, mà thoát ra ngoài phạm vi gọi. Dart SDK xem đây là rủi ro rò rỉ ngoại lệ tiềm ẩn (`unawaited_return_in_try_block`).

### 3.2. Lỗi Ngầm Định Riverpod 2.x: Lifecycle Violation (`!_didChangeDependency`)
- **Vị trí**: `lib/features/chat_v2/application/chat_v2_channels_controller.dart:94-106`
- **Nguyên nhân**:
  - `ChatV2ChannelsController.build()` là một phương thức `async`.
  - Trong hàm `build()`, các lệnh đọc provider (`ref.read(...)`) được đặt sau các điểm await (`await ChatV2ChannelLocalCache.init(...)`).
  - Khi một dependency được watch (chẳng hạn `authControllerProvider`) phát sinh thay đổi trạng thái trong lúc provider đang await, Riverpod đánh dấu `_didChangeDependency = true`.
  - Việc gọi tiếp `ref.read(...)` hoặc `ref.watch(...)` sau điểm await vi phạm assertion:
    `Cannot use ref functions after the dependency of a provider changed but before the provider rebuilt`.

---

## 4. Chi Tiết Khắc Phục (Code Fixes)

### 4.1. Sửa `lib/features/auth/data/auth_repository.dart` (Line 118)
Bổ sung `await` để Future được giải quyết bên trong khối `try`:
```dart
// lib/features/auth/data/auth_repository.dart:118
if (profile == null) {
  // Body 200 không hợp lệ: giữ nguyên session thay vì vội vã logout
  return await _toUser(session);
}
```

### 4.2. Sửa `lib/features/chat_v2/application/chat_v2_channels_controller.dart`
Di chuyển toàn bộ các lệnh đọc provider lên đầu hàm `build()` đồng bộ trước tất cả các điểm `await`:
```dart
// lib/features/chat_v2/application/chat_v2_channels_controller.dart
@override
Future<List<ChatV2Channel>> build() async {
  // 1. Đọc đồng bộ tất cả dependencies trước await
  final authState = ref.watch(authControllerProvider);
  final repo = ref.read(chatV2RepositoryProvider);
  final realtime = ref.read(chatV2RealtimeServiceProvider);
  final busService = ref.read(odooBusServiceProvider);
  final syncStatusNotifier = ref.read(chatV2SyncStatusProvider.notifier);
  final presenceNotifier = ref.read(chatV2PresenceProvider.notifier);
  final inAppNotifier = ref.read(inAppNotificationProvider.notifier);
  final readStateNotifier = ref.read(chatV2ReadStateProvider.notifier);
  final lastSentTracker = ref.read(chatV2LastSentTrackerProvider.notifier);

  // 2. Trích xuất metadata và khởi tạo cache
  ...
  await ChatV2ChannelLocalCache.init(db: currentDb, userId: currentUid);
  await ChatV2MessageLocalCache.init(db: currentDb, userId: currentUid);
  ...
}
```

### 4.3. Chuẩn Hóa Test Mock `test/chat_v2_sync_status_test.dart`
Loại bỏ việc gán `state = AsyncData(_user)` thừa trong `build()` của `_FakeAuthController` để tránh phát sinh double notification gây race condition:
```dart
class _FakeAuthController extends AuthController {
  _FakeAuthController([this._user = const AuthUser(
    id: '7',
    email: 'mark.brown23@example.com',
    userMetadata: {'display_name': 'Marc Demo', 'has_v_mobile': true},
  )]);

  final AuthUser? _user;

  @override
  Future<AuthUser?> build() async => _user;
}
```

---

## 5. Kết Quả Kiểm Chứng (Verification Evidence)

1. **Phân tích tĩnh (Flutter Analyze)**:
   ```bash
   flutter analyze
   # Kết quả: No issues found! (ran in 13.8s) -> 0 errors, 0 warnings
   ```
2. **Kiểm thử đơn vị (Flutter Test)**:
   ```bash
   flutter test test/chat_v2_sync_status_test.dart
   # Kết quả: 00:02 +6: All tests passed!
   ```
3. **Toàn bộ Test Suite hồi quy**:
   ```bash
   flutter test --exclude-tags=live-server
   # Kết quả: 03:34 +972: All tests passed! (972/972 test cases pass 100%)
   ```

---

## 6. Checklist Phòng Ngừa (Pre-Deploy Guard)

Trước khi thực hiện `git push` hoặc tạo release tag kích hoạt CI/CD:

- [ ] **1. Chạy `flutter analyze`**: Bắt buộc đạt `No issues found!` (0 errors, 0 warnings).
- [ ] **2. Kiểm tra `unawaited_return_in_try_block`**: Mọi hàm async trả về giá trị trong khối `try` phải có `return await ...`.
- [ ] **3. Quy tắc Riverpod `build()`**: Mọi `ref.watch` và `ref.read` trong `AsyncNotifier.build()` phải đặt ở đầu hàm, trước bất kỳ lời gọi `await` nào.
- [ ] **4. Chạy bộ test suite hồi quy**: `flutter test --exclude-tags=live-server` phải pass 100%.
- [ ] **5. Git Commit Trailer**: Bắt buộc có `Authored-By: 360org <support@360.org.vn>`.
