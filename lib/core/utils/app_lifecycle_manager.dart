import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider theo dõi trạng thái Foreground/Background của ứng dụng.
///
/// - `true`: App đang mở ở Foreground (người dùng đang tương tác).
/// - `false`: App đang ở Background / Paused / Inactive / Khóa màn hình.
///
/// Tất cả các Controller Polling (Chat, Attendance, Notifications) phải kiểm tra
/// giá trị này để tạm dừng 100% Timer chu kỳ khi app vào Background, triệt tiêu
/// hoàn toàn tình trạng "bão request" khi hàng chục thiết bị để trong túi quần.
final isAppForegroundProvider = StateProvider<bool>((ref) => true);
