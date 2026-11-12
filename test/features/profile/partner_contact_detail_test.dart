import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/profile/data/models/partner_contact_detail.dart';

void main() {
  group('PartnerSmartMetrics', () {
    test('khởi tạo mặc định với tất cả chỉ số bằng 0', () {
      const metrics = PartnerSmartMetrics();
      expect(metrics.ticketCount, 0);
      expect(metrics.opportunityCount, 0);
      expect(metrics.saleOrderCount, 0);
      expect(metrics.taskCount, 0);
      expect(metrics.meetingCount, 0);
      expect(metrics.hasAnyMetric, isFalse);
    });

    test('parse đúng từ JSON đầy đủ', () {
      final json = {
        'ticket_count': 3,
        'opportunity_count': 2,
        'sale_order_count': 5,
        'task_count': 1,
        'meeting_count': 4,
      };
      final metrics = PartnerSmartMetrics.fromJson(json);
      expect(metrics.ticketCount, 3);
      expect(metrics.opportunityCount, 2);
      expect(metrics.saleOrderCount, 5);
      expect(metrics.taskCount, 1);
      expect(metrics.meetingCount, 4);
      expect(metrics.hasAnyMetric, isTrue);
    });

    test('parse an toàn khi dữ liệu dạng chuỗi hoặc null', () {
      final json = {
        'ticket_count': '12',
        'opportunity_count': null,
        'sale_order_count': 'invalid',
        'task_count': 0,
      };
      final metrics = PartnerSmartMetrics.fromJson(json);
      expect(metrics.ticketCount, 12);
      expect(metrics.opportunityCount, 0);
      expect(metrics.saleOrderCount, 0);
      expect(metrics.taskCount, 0);
      expect(metrics.hasAnyMetric, isTrue);
    });

    test('fromJson trả về mặc định khi truyền null', () {
      final metrics = PartnerSmartMetrics.fromJson(null);
      expect(metrics.ticketCount, 0);
      expect(metrics.hasAnyMetric, isFalse);
    });
  });

  group('PartnerContactDetail', () {
    test('parse đúng hồ sơ đầy đủ của khách hàng doanh nghiệp B2B từ Odoo Web', () {
      final json = {
        'id': 789,
        'name': 'Kiều Đại',
        'is_company': false,
        'parent_id': 101,
        'parent_name': 'CTY CP PHÁT TRIỂN CÔNG VIÊN CÂY XANH VÀ ĐÔ THỊ VŨNG TÀU',
        'email': 'upcgreen.com.vn',
        'phone': '0901234567',
        'function': 'Giám đốc sales',
        'vat': '3500144358',
        'street': 'Số 221 Võ Thị Sáu',
        'street2': 'Phường Vũng Tàu',
        'city': 'TP Vũng Tàu',
        'zip': '79000',
        'country_name': 'Việt Nam',
        'contact_address': 'Số 221 Võ Thị Sáu, Phường Vũng Tàu, TP Vũng Tàu, Việt Nam',
        'website': 'https://upcgreen.com.vn',
        'tags': ['Khách hàng VIP', 'B2B', ' '],
        'company_id': 1,
        'company_name': '360 CORP',
        'avatar_url': '/api/v1/mobile/avatar/res.partner/789',
        'smart_metrics': {
          'ticket_count': 4,
          'opportunity_count': 1,
          'sale_order_count': 2,
          'task_count': 0,
          'meeting_count': 0,
        },
      };

      final detail = PartnerContactDetail.fromJson(json);
      expect(detail.id, 789);
      expect(detail.name, 'Kiều Đại');
      expect(detail.isCompany, isFalse);
      expect(detail.parentId, 101);
      expect(detail.parentName, 'CTY CP PHÁT TRIỂN CÔNG VIÊN CÂY XANH VÀ ĐÔ THỊ VŨNG TÀU');
      expect(detail.email, 'upcgreen.com.vn');
      expect(detail.phone, '0901234567');
      expect(detail.function, 'Giám đốc sales');
      expect(detail.vat, '3500144358');
      expect(detail.contactAddress, 'Số 221 Võ Thị Sáu, Phường Vũng Tàu, TP Vũng Tàu, Việt Nam');
      expect(detail.website, 'https://upcgreen.com.vn');
      expect(detail.tags, ['Khách hàng VIP', 'B2B']);
      expect(detail.smartMetrics.ticketCount, 4);
      expect(detail.smartMetrics.opportunityCount, 1);
      expect(detail.smartMetrics.saleOrderCount, 2);

      // Kiểm tra helper getters
      expect(detail.effectiveCompanyName, 'CTY CP PHÁT TRIỂN CÔNG VIÊN CÂY XANH VÀ ĐÔ THỊ VŨNG TÀU');
      expect(
        detail.subtitleInfo,
        'Giám đốc sales · CTY CP PHÁT TRIỂN CÔNG VIÊN CÂY XANH VÀ ĐÔ THỊ VŨNG TÀU',
      );
    });

    test('parse đúng đối tác là chính doanh nghiệp độc lập (is_company = true)', () {
      final json = {
        'id': 202,
        'name': 'CÔNG TY TNHH CÔNG NGHỆ 360',
        'is_company': true,
        'parent_id': null,
        'parent_name': '',
        'vat': '0312345678',
        'contact_address': 'Quận 1, TP Hồ Chí Minh',
        'smart_metrics': null,
      };

      final detail = PartnerContactDetail.fromJson(json);
      expect(detail.id, 202);
      expect(detail.name, 'CÔNG TY TNHH CÔNG NGHỆ 360');
      expect(detail.isCompany, isTrue);
      expect(detail.effectiveCompanyName, 'CÔNG TY TNHH CÔNG NGHỆ 360');
      expect(detail.vat, '0312345678');
      expect(detail.smartMetrics.hasAnyMetric, isFalse);
    });

    test('xử lý an toàn khi JSON thiếu trường và không văng lỗi', () {
      final detail = PartnerContactDetail.fromJson({'id': 1, 'name': 'Khách Vãng Lai'});
      expect(detail.id, 1);
      expect(detail.name, 'Khách Vãng Lai');
      expect(detail.vat, isEmpty);
      expect(detail.contactAddress, isEmpty);
      expect(detail.tags, isEmpty);
      expect(detail.smartMetrics.ticketCount, 0);
      expect(detail.subtitleInfo, isEmpty);
    });
  });
}
