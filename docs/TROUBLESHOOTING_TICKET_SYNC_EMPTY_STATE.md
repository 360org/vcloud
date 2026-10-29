# 🛠️ POST-MORTEM & QUY TẮC PHÒNG NGỪA: LỖI ĐỒNG BỘ TICKET RỖNG (EMPTY TICKET LIST BUG)

Tài liệu ghi lại toàn bộ sự cố lỗi màn hình Ticket hiển thị 0 vé, phân tích 3 mắt xích nguyên nhân gốc rễ liên hoàn và thiết lập **Bộ Quy Tắc Phòng Ngừa Tuyệt Đối (Anti-Regression Rules)** cho Flutter client VCloud (`vclients`).

---

## 1. Thông Tin Sự Cố

- **Mã sự vụ**: `BUG-020` (trong `docs/TEST_AND_BUG_TRACKER.md`)
- **Môi trường phát hiện**: Máy ảo Redroid Android 11 (`192.168.1.100:5555`), Odoo 19 Backend (`vcloud_test_v19` - port 1900)
- **Tài khoản**: `admin` / `admin`
- **Hiện tượng quan sát**: 
  - Tại tab Ticket: App thông báo *"Không có ticket đang xử lý"*, badge đếm hiển thị: `Đang xử lý · 0`, `Hoàn thành · 0`.
  - Trong khi đó trên cơ sở dữ liệu Odoo 19 backend có sẵn 19-20 ticket thật (4 vé đang xử lý, 16 vé hoàn thành).

---

## 2. Phân Tích Kỹ Thuật & 3 Mắt Xích Gốc Rễ (Root Cause)

### Mắt xích 1: Race Condition Chu kỳ Auth & Dọn Dẹp Trạng Thái (Auth Lifecycle Race)
- **Vị trí**: `lib/features/auth/application/auth_controller.dart` & `lib/core/services/global_state_reset_service.dart`
- **Cơ chế lỗi**:
  - Khi người dùng đăng nhập tài khoản mới hoặc chuyển database, hàm `activateVerifiedSession()` gọi `GlobalStateResetService.clearAllUserDataOnLogout(ref: ref)`.
  - Lệnh này kích hoạt `ref.invalidate(ticketsProvider)`.
  - Do `ticketsProvider` là một `StreamProvider` kết nối tới `TicketRepository.watchAssigned()`, Riverpod ngay lập tức khởi tạo lại stream listener ngầm.
  - Tuy nhiên, tại thời điểm này, phiên làm việc (`_client.session`) của `OdooApiClient` chưa kịp nạp xong token mới, hoặc đang trong quá trình chuyển đổi giữa local storage và RAM.
  - Hậu quả: `fetchTickets()` bị gọi sớm và ném ngoại lệ `Failure('Not signed in. Please log in first.')`.

### Mắt xích 2: Nuốt Ngoại Lệ Thành Mảng Rỗng Giả Lập (Error Swallowing)
- **Vị trí**: `lib/features/ticket/data/ticket_repository.dart` trong hàm `watchAssigned()`
- **Cơ chế lỗi**:
  ```dart
  // CODE CŨ GÂY LỖI:
  try {
    final list = await fetchTickets(...);
    ctl.add(list);
  } catch (e) {
    debugPrint('TicketRepository watchAssigned error: $e');
    ctl.add(const <Ticket>[]); // ❌ LỖI NGHIÊM TRỌNG: Nuốt sạch lỗi biến thành list rỗng!
  }
  ```
  - Khi ngoại lệ `Failure('Not signed in')` văng ra, khối `catch` đã bắt lấy và đẩy `const <Ticket>[]` vào stream.
  - Riverpod nhận sự kiện từ stream và cập nhật trạng thái của `ticketsProvider` thành `AsyncData([])` (dữ liệu rỗng hợp lệ) thay vì `AsyncError`.
  - Vì `ticketsProvider` là `StreamProvider` toàn cục (không có `.autoDispose`), trạng thái `AsyncData([])` này bị **đóng băng vĩnh viễn trong RAM** suốt phiên sử dụng của người dùng. Kể cả sau khi đăng nhập thành công có token hợp lệ, provider cũng không tự động gọi lại API!

### Mắt xích 3: Thiếu Invalidation & Pre-warm khi Đăng Nhập Hoàn Tất
- **Vị trí**: `lib/features/auth/presentation/login_screen.dart` và `lib/features/ticket/presentation/ticket_list_screen.dart`
- **Cơ chế lỗi**:
  - Tại `login_screen.dart:420`, sau khi đăng nhập thành công, app chỉ kích hoạt pre-warm cho Chat V2 (`chatV2ChannelsProvider.notifier.refresh()`) mà hoàn toàn bỏ quên `ticketsProvider`.
  - Tại `ticket_list_screen.dart`, màn hình chỉ lắng nghe thụ động `effectiveTicketsProvider`. Nếu provider đang giữ trạng thái `AsyncData([])`, màn hình cứ thế hiển thị "Không có ticket nào" mà không hề có cơ chế kiểm tra và tự kích hoạt tải lại (auto-fetch).

---

## 3. Bộ Quy Tắc Phòng Ngừa Tuyệt Đối (Anti-Regression Rules)

Để ngăn chặn 100% lỗi này tái phát ở module Ticket cũng như các module dữ liệu khác (Chat, Timesheet, Attendance), tất cả kỹ sư dev và AI Agent **BẮT BUỘC** tuân thủ 5 quy tắc sau:

### 🛑 QUY TẮC 1: TUYỆT ĐỐI KHÔNG NUỐT LỖI MẠNG / AUTH THÀNH MẢNG RỖNG TRONG REPOSITORY
- **Sai**:
  ```dart
  catch (e) {
    ctl.add(const <T>[]); // ❌ CẤM
  }
  ```
- **Đúng**:
  ```dart
  catch (e) {
    if (!ctl.isClosed) {
      if (_cachedItems.isNotEmpty) {
        ctl.add(_cachedItems); // Giữ cache cũ nếu có
      } else if (e is Failure && e.message.contains('Not signed in')) {
        ctl.add(const <T>[]); // Chỉ fallback rỗng khi chưa đăng nhập
      } else {
        ctl.addError(e); // ✅ BẮT BUỘC phát lỗi để Riverpod biết là AsyncError
      }
    }
  }
  ```

### 🛑 QUY TẮC 2: KIỂM TRA SẴN SÀNG CỦA SESSION TRƯỚC KHI GỌI MẠNG
Trong mọi Stream listener (như `watchAssigned`, `watchChannels`), phải kiểm tra session:
```dart
if (_client.session == null) {
  if (!ctl.isClosed) ctl.add(const <Ticket>[]);
  return;
}
```

### 🛑 QUY TẮC 3: RESET VÀ PRE-WARM DỮ LIỆU TẠI LOGIN SCREEN
Tại `_completeLoginWithSession` trong `login_screen.dart`, luôn luôn reset override, đặt lại phân trang và kích hoạt pre-warm đồng thời:
```dart
ref.read(ticketOverrideProvider.notifier).set(null);
ref.read(ticketHasMoreProvider.notifier).state = true;
ref.invalidate(ticketsProvider);
await Future.wait([
  ref.read(chatV2ChannelsProvider.notifier).refresh(),
  ref.read(ticketsProvider.future), // ✅ Pre-warm ticket
]).timeout(const Duration(milliseconds: 3500));
```

### 🛑 QUY TẮC 4: AUTO-FETCH FALLBACK TRONG PRESENTATION
Trong `initState()` của màn hình danh sách (`TicketListScreen`), luôn cài đặt post frame callback kiểm tra nếu danh sách đang rỗng thì tự động kích hoạt nạp lại:
```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted && !_initialFetchDone) {
    _initialFetchDone = true;
    final current = ref.read(effectiveTicketsProvider);
    if (current.isEmpty) {
      ref.read(ticketOverrideProvider.notifier).set(null);
      ref.read(ticketHasMoreProvider.notifier).state = true;
      ref.invalidate(ticketsProvider);
    }
  }
});
```

### 🛑 QUY TẮC 5: ĐỒNG BỘ INVALIDATE KHI PULL-TO-REFRESH
Mọi cử chỉ kéo làm mới (`RefreshIndicator`) tại `HomeScreen` và `TicketListScreen` phải thực thi:
```dart
onRefresh: () async {
  ref.read(ticketOverrideProvider.notifier).set(null);
  ref.read(ticketHasMoreProvider.notifier).state = true;
  ref.invalidate(ticketsProvider);
  try {
    await ref.read(ticketsProvider.future);
  } catch (_) {}
}
```

---

## 4. Bằng Chứng Nghiệm Thu Sau Khắc Phục

1. **Unit & Widget Tests**: 
   - `test/features/ticket/`: 39/39 tests passed 100%.
   - `test/features/auth/`: 90/90 tests passed 100%.
   - `flutter analyze`: 0 errors, 0 warnings.
2. **Kiểm chứng thực tế trên Redroid Local Server (`192.168.1.100:5555`)**:
   - Tab Đang xử lý: Hiển thị chính xác **Đang xử lý · 4**.
   - Tab Hoàn thành: Hiển thị chính xác **Hoàn thành · 16**.
   - Ảnh chụp màn hình nghiệm thu:
     - [`screenshot_tickets.png`](/media/tanma/DATA/save/mobile_versions/vclients/docs/screenshots/screenshot_tickets.png)
     - [`screenshot_tickets_done.png`](/media/tanma/DATA/save/mobile_versions/vclients/docs/screenshots/screenshot_tickets_done.png)
