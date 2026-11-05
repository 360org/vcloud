// Part of ENV_17. See LICENSE file for full copyright and licensing details.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Chat V2 Responsive List & Modern UI Snippet Tests (10 Cases)', () {
    // ── Case 1: URL format - Odoo / Vua Hệ Thống ────────────────────────────
    test('TC-01: Định dạng URL nội bộ thành [Liên kết Hệ thống]', () {
      const url = 'https://vuahethong.net/web#id=16450&model=mail.channel';
      final lower = url.toLowerCase();
      final uri = Uri.tryParse(url.trim());
      final host = uri?.host.toLowerCase() ?? '';

      final String displayText;
      if (host.contains('vuahethong') || lower.contains('/crm') || lower.contains('/odoo')) {
        displayText = '[Liên kết Hệ thống]';
      } else if (host.isNotEmpty) {
        displayText = '[Liên kết: $host]';
      } else {
        displayText = '[Liên kết]';
      }

      expect(displayText, equals('[Liên kết Hệ thống]'));
    });

    // ── Case 2: URL format - Tên miền bên ngoài ─────────────────────────────
    test('TC-02: Định dạng URL ngoại vi thành [Liên kết: <host>]', () {
      const url = 'https://github.com/360org/vcloud/pull/12';
      final lower = url.toLowerCase();
      final uri = Uri.tryParse(url.trim());
      final host = uri?.host.toLowerCase() ?? '';

      final String displayText;
      if (host.contains('vuahethong') || lower.contains('/crm') || lower.contains('/odoo')) {
        displayText = '[Liên kết Hệ thống]';
      } else if (host.isNotEmpty) {
        displayText = '[Liên kết: $host]';
      } else {
        displayText = '[Liên kết]';
      }

      expect(displayText, equals('[Liên kết: github.com]'));
    });

    // ── Case 3: URL format - Đường dẫn CRM Odoo không domain ────────────────
    test('TC-03: Định dạng URL CRM nội bộ thành [Liên kết Hệ thống]', () {
      const url = 'http://localhost:8069/crm/lead/42';
      final lower = url.toLowerCase();
      final uri = Uri.tryParse(url.trim());
      final host = uri?.host.toLowerCase() ?? '';

      final String displayText;
      if (host.contains('vuahethong') || lower.contains('/crm') || lower.contains('/odoo')) {
        displayText = '[Liên kết Hệ thống]';
      } else if (host.isNotEmpty) {
        displayText = '[Liên kết: $host]';
      } else {
        displayText = '[Liên kết]';
      }

      expect(displayText, equals('[Liên kết Hệ thống]'));
    });

    // ── Case 4: Nhận diện tập tin hình ảnh ──────────────────────────────────
    test('TC-04: Nhận diện file ảnh thành [Hình ảnh]', () {
      const filename = 'screenshot_2026_11_05.png';
      final lower = filename.toLowerCase();
      final isImage = lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.webp');

      expect(isImage, isTrue);
      final displayText = isImage ? '[Hình ảnh]' : filename;
      expect(displayText, equals('[Hình ảnh]'));
    });

    // ── Case 5: Nhận diện file ghi âm ───────────────────────────────────────
    test('TC-05: Nhận diện file ghi âm thành [Ghi âm]', () {
      const audioName = 'voice_message_001.m4a';
      final lower = audioName.toLowerCase();
      final isVoice = lower.endsWith('.m4a') ||
          lower.endsWith('.mp3') ||
          lower.endsWith('.aac') ||
          lower.startsWith('voice_');

      expect(isVoice, isTrue);
      final displayText = isVoice ? '[Ghi âm]' : audioName;
      expect(displayText, equals('[Ghi âm]'));
    });

    // ── Case 6: Nhận diện file tài liệu ─────────────────────────────────────
    test('TC-06: Nhận diện file tài liệu kỹ thuật thành [Tập tin]', () {
      const docName = 'Bao_Cao_Nghiem_Thu.pdf';
      final lower = docName.toLowerCase();
      final isDoc = lower.endsWith('.pdf') ||
          lower.endsWith('.docx') ||
          lower.endsWith('.xlsx');

      expect(isDoc, isTrue);
      final displayText = isDoc ? '[Tập tin]' : docName;
      expect(displayText, equals('[Tập tin]'));
    });

    // ── Case 7: Phân biệt cuộc gọi nhỡ đi vs cuộc gọi nhỡ đến ───────────────
    test('TC-07: Phân biệt cuộc gọi nhỡ đi vs cuộc gọi nhỡ đến', () {
      const msg = '❌ Cuộc gọi nhỡ';
      String getDisplayText({required bool isMine}) =>
          isMine ? '[Cuộc gọi nhỡ đi]' : '[Cuộc gọi nhỡ]';
      final lower = msg.toLowerCase();
      final isMissedCall = lower.contains('nhỡ') || lower.startsWith('❌');

      expect(isMissedCall, isTrue);
      expect(getDisplayText(isMine: true), equals('[Cuộc gọi nhỡ đi]'));
      expect(getDisplayText(isMine: false), equals('[Cuộc gọi nhỡ]'));
    });

    // ── Case 8: Parse thời lượng cuộc gọi thoại ─────────────────────────────
    test('TC-08: Tách thời lượng cuộc gọi thoại thành công', () {
      const callMsg = '📞 Cuộc gọi thoại (02:45)';
      final cleanMsg = callMsg.replaceAll('📞', '').trim();
      final timeMatch = RegExp(r'\((\d{1,2}:\d{2}(?::\d{2})?)\)').firstMatch(cleanMsg);

      expect(timeMatch, isNotNull);
      final displayText = '[Cuộc gọi thoại] (${timeMatch!.group(1)})';
      expect(displayText, equals('[Cuộc gọi thoại] (02:45)'));
    });

    // ── Case 9: Responsive Breakpoint kiểm tra Mobile vs Tablet / iPad ──────
    test('TC-09: Responsive Breakpoint phân định chính xác Mobile (<600) và Tablet (>=600)', () {
      const iphoneWidth = 393.0; // iPhone 16 Pro
      const androidWidth = 412.0; // Pixel 8
      const ipadMiniWidth = 744.0; // iPad Mini
      const ipadAirWidth = 820.0; // iPad Air
      const ipadProWidth = 1024.0; // iPad Pro 11"

      bool isTablet(double width) => width >= 600;

      expect(isTablet(iphoneWidth), isFalse, reason: 'iPhone là mobile');
      expect(isTablet(androidWidth), isFalse, reason: 'Android Phone là mobile');
      expect(isTablet(ipadMiniWidth), isTrue, reason: 'iPad Mini là tablet');
      expect(isTablet(ipadAirWidth), isTrue, reason: 'iPad Air là tablet');
      expect(isTablet(ipadProWidth), isTrue, reason: 'iPad Pro là tablet');
    });

    // ── Case 10: Ràng buộc MaxWidth 880px cho Tablet / iPad ─────────────────
    test('TC-10: Ràng buộc MaxWidth 880px giới hạn chiều rộng chuẩn, chống vỡ giao diện trên tablet', () {
      const maxWidth = 880.0;
      double clampedWidth(double screenWidth) {
        return screenWidth > maxWidth ? maxWidth : screenWidth;
      }

      expect(clampedWidth(393.0), equals(393.0));
      expect(clampedWidth(744.0), equals(744.0));
      expect(clampedWidth(880.0), equals(880.0));
      expect(clampedWidth(1024.0), equals(880.0));
      expect(clampedWidth(1366.0), equals(880.0));
    });
  });
}
