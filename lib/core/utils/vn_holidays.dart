import 'package:flutter/foundation.dart';

/// Information about a Vietnamese Public Holiday or Observance Day.
@immutable
class VnHolidayInfo {
  const VnHolidayInfo({
    required this.name,
    required this.shortLabel,
    this.isOfficialOff = true,
  });

  final String name;
  final String shortLabel;
  final bool isOfficialOff;
}

/// Utility class for identifying Vietnamese Public Holidays & Festivals.
class VnHolidays {
  const VnHolidays._();

  static VnHolidayInfo? getHoliday(DateTime date) {
    final m = date.month;
    final d = date.day;
    final y = date.year;

    // Fixed Solar Public Holidays
    if (m == 1 && d == 1) {
      return const VnHolidayInfo(name: 'Tết Dương Lịch 🎆', shortLabel: 'Tết DL');
    }
    if (m == 4 && d == 30) {
      return const VnHolidayInfo(name: 'Giải phóng Miền Nam (30/4) 🇻🇳', shortLabel: 'Lễ 30/4');
    }
    if (m == 5 && d == 1) {
      return const VnHolidayInfo(name: 'Quốc tế Lao động (1/5) 🛠️', shortLabel: 'Lễ 1/5');
    }
    if (m == 9 && (d == 1 || d == 2 || d == 3)) {
      return const VnHolidayInfo(name: 'Quốc Khánh Việt Nam (2/9) 🇻🇳', shortLabel: 'Quốc Khánh');
    }

    // Cultural Observances in VN (Working days)
    if (m == 3 && d == 8) {
      return const VnHolidayInfo(name: 'Quốc tế Phụ nữ (8/3) 💐', shortLabel: '8/3', isOfficialOff: false);
    }
    if (m == 10 && d == 20) {
      return const VnHolidayInfo(name: 'Ngày Phụ nữ VN (20/10) 🌹', shortLabel: '20/10', isOfficialOff: false);
    }
    if (m == 11 && d == 20) {
      return const VnHolidayInfo(name: 'Ngày Nhà giáo VN (20/11) 👩‍🏫', shortLabel: '20/11', isOfficialOff: false);
    }
    if (m == 12 && d == 22) {
      return const VnHolidayInfo(name: 'Ngày QĐND Việt Nam (22/12) 🎖️', shortLabel: '22/12', isOfficialOff: false);
    }

    // Lunar-based Official Holidays mapped for 2025, 2026, 2027
    if (y == 2026) {
      // Tết Nguyên Đán Bính Ngọ 2026 (16/02 ➔ 21/02/2026)
      if (m == 2 && d == 16) return const VnHolidayInfo(name: '30 Tết Bính Ngọ 🎆', shortLabel: '30 Tết');
      if (m == 2 && d == 17) return const VnHolidayInfo(name: 'Mùng 1 Tết Bính Ngọ 🧨', shortLabel: 'Mùng 1');
      if (m == 2 && d == 18) return const VnHolidayInfo(name: 'Mùng 2 Tết Bính Ngọ 🧧', shortLabel: 'Mùng 2');
      if (m == 2 && d == 19) return const VnHolidayInfo(name: 'Mùng 3 Tết Bính Ngọ 🧧', shortLabel: 'Mùng 3');
      if (m == 2 && d == 20) return const VnHolidayInfo(name: 'Mùng 4 Tết Bính Ngọ 🧧', shortLabel: 'Mùng 4');
      if (m == 2 && d == 21) return const VnHolidayInfo(name: 'Mùng 5 Tết Bính Ngọ 🧧', shortLabel: 'Mùng 5');

      // Giỗ Tổ Hùng Vương 2026 (10/3 Âm = 26/04/2026)
      if (m == 4 && d == 26) return const VnHolidayInfo(name: 'Giỗ Tổ Hùng Vương (10/3 Âm) 👑', shortLabel: 'Giỗ Tổ');
    } else if (y == 2025) {
      // Tết Ất Tỵ 2025 (28/01 ➔ 02/02/2025)
      if (m == 1 && d == 28) return const VnHolidayInfo(name: '30 Tết Ất Tỵ 🎆', shortLabel: '30 Tết');
      if (m == 1 && d == 29) return const VnHolidayInfo(name: 'Mùng 1 Tết Ất Tỵ 🧨', shortLabel: 'Mùng 1');
      if (m == 1 && d == 30) return const VnHolidayInfo(name: 'Mùng 2 Tết Ất Tỵ 🧧', shortLabel: 'Mùng 2');
      if (m == 1 && d == 31) return const VnHolidayInfo(name: 'Mùng 3 Tết Ất Tỵ 🧧', shortLabel: 'Mùng 3');
      if (m == 2 && d == 1) return const VnHolidayInfo(name: 'Mùng 4 Tết Ất Tỵ 🧧', shortLabel: 'Mùng 4');
      if (m == 2 && d == 2) return const VnHolidayInfo(name: 'Mùng 5 Tết Ất Tỵ 🧧', shortLabel: 'Mùng 5');

      // Giỗ Tổ Hùng Vương 2025 (07/04/2025)
      if (m == 4 && d == 7) return const VnHolidayInfo(name: 'Giỗ Tổ Hùng Vương (10/3 Âm) 👑', shortLabel: 'Giỗ Tổ');
    }

    return null;
  }
}
