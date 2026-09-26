import '../../../core/api/odoo_session.dart';
import '../data/db_info.dart';

/// [Protocol V2.1 - Phương án 1]: Bộ nhớ tạm RAM cô lập cho luồng Pre-Authentication Đa Database.
///
/// Tuân thủ nguyên tắc Zero-Leakage & Tenant Isolation:
/// - Khi user xác thực credentials thành công trên N databases, các phiên tạm được giữ trong RAM ngắn hạn.
/// - Ngay sau khi người dùng lựa chọn DB mục tiêu:
///   1. Lưu duy nhất Token của DB mục tiêu vào FlutterSecureStorage.
///   2. Gọi ngay lập tức [clearTemporaryMemory] để xóa sạch 100% token của các DB khác khỏi RAM.
class AuthMemoryState {
  AuthMemoryState._();

  static final Map<String, ({DbInfo db, OdooSession session})> _temporarySessions = {};

  /// Lưu danh sách các session vừa được xác thực thành công vào bộ nhớ tạm RAM.
  static void setTemporarySessions(List<({DbInfo db, OdooSession session})> sessions) {
    _temporarySessions.clear();
    for (final item in sessions) {
      final key = _makeKey(item.db);
      _temporarySessions[key] = item;
    }
  }

  /// Lấy session của một Database cụ thể từ RAM.
  static ({DbInfo db, OdooSession session})? getSessionForDb(DbInfo db) {
    return _temporarySessions[_makeKey(db)];
  }

  /// Danh sách các Database ứng viên có session tạm hợp lệ trong RAM.
  static List<DbInfo> get candidateDbs =>
      _temporarySessions.values.map((e) => e.db).toList();

  /// Số lượng session tạm đang giữ trong RAM.
  static int get count => _temporarySessions.length;

  /// RAM có đang lưu giữ session tạm nào không.
  static bool get hasTemporarySessions => _temporarySessions.isNotEmpty;

  /// Kiểm tra bộ nhớ RAM có đang rỗng không.
  static bool get isEmpty => _temporarySessions.isEmpty;

  /// Snapshot chỉ đọc cho mục đích test / audit.
  static Map<String, ({DbInfo db, OdooSession session})> get snapshot =>
      Map.unmodifiable(_temporarySessions);

  /// [Phương án 1]: XÓA SẠCH HOÀN TOÀN (IMMEDIATE WIPE) toàn bộ Token tạm khỏi RAM.
  /// Gọi ngay lập tức khi:
  /// - Người dùng bấm chọn 1 DB mục tiêu để vào App.
  /// - Người dùng đóng/hủy Popup chọn DB.
  /// - Xác thực thất bại hoặc session kết thúc.
  static void clearTemporaryMemory() {
    _temporarySessions.clear();
  }

  static String _makeKey(DbInfo db) {
    return '${db.databaseName.trim().toLowerCase()}|${db.databaseUrl.trim().toLowerCase()}';
  }
}
