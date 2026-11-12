import 'package:flutter/foundation.dart';

@immutable
class PartnerSmartMetrics {
  final int ticketCount;
  final int opportunityCount;
  final int saleOrderCount;
  final int taskCount;
  final int meetingCount;

  const PartnerSmartMetrics({
    this.ticketCount = 0,
    this.opportunityCount = 0,
    this.saleOrderCount = 0,
    this.taskCount = 0,
    this.meetingCount = 0,
  });

  factory PartnerSmartMetrics.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PartnerSmartMetrics();
    return PartnerSmartMetrics(
      ticketCount: _toInt(json['ticket_count']),
      opportunityCount: _toInt(json['opportunity_count']),
      saleOrderCount: _toInt(json['sale_order_count']),
      taskCount: _toInt(json['task_count']),
      meetingCount: _toInt(json['meeting_count']),
    );
  }

  static int _toInt(dynamic val) {
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }

  bool get hasAnyMetric =>
      ticketCount > 0 ||
      opportunityCount > 0 ||
      saleOrderCount > 0 ||
      taskCount > 0 ||
      meetingCount > 0;
}

@immutable
class PartnerContactDetail {
  final int id;
  final String name;
  final bool isCompany;
  final int? parentId;
  final String parentName;
  final String email;
  final String phone;
  final String function;
  final String vat;
  final String street;
  final String street2;
  final String city;
  final String zip;
  final String countryName;
  final String contactAddress;
  final String website;
  final List<String> tags;
  final int? companyId;
  final String companyName;
  final String? avatarUrl;
  final PartnerSmartMetrics smartMetrics;

  const PartnerContactDetail({
    required this.id,
    required this.name,
    this.isCompany = false,
    this.parentId,
    this.parentName = '',
    this.email = '',
    this.phone = '',
    this.function = '',
    this.vat = '',
    this.street = '',
    this.street2 = '',
    this.city = '',
    this.zip = '',
    this.countryName = '',
    this.contactAddress = '',
    this.website = '',
    this.tags = const [],
    this.companyId,
    this.companyName = '',
    this.avatarUrl,
    this.smartMetrics = const PartnerSmartMetrics(),
  });

  factory PartnerContactDetail.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final List<String> parsedTags = [];
    if (rawTags is List) {
      for (final item in rawTags) {
        if (item != null && item.toString().trim().isNotEmpty) {
          parsedTags.add(item.toString().trim());
        }
      }
    }

    final rawMetrics = json['smart_metrics'];
    final metrics = rawMetrics is Map<String, dynamic>
        ? PartnerSmartMetrics.fromJson(rawMetrics)
        : const PartnerSmartMetrics();

    return PartnerContactDetail(
      id: json['id'] is num ? (json['id'] as num).toInt() : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      name: (json['name'] as String?)?.trim() ?? '',
      isCompany: json['is_company'] == true,
      parentId: json['parent_id'] is num ? (json['parent_id'] as num).toInt() : null,
      parentName: (json['parent_name'] as String?)?.trim() ?? '',
      email: (json['email'] as String?)?.trim() ?? '',
      phone: (json['phone'] as String?)?.trim() ?? '',
      function: (json['function'] as String?)?.trim() ?? '',
      vat: (json['vat'] as String?)?.trim() ?? '',
      street: (json['street'] as String?)?.trim() ?? '',
      street2: (json['street2'] as String?)?.trim() ?? '',
      city: (json['city'] as String?)?.trim() ?? '',
      zip: (json['zip'] as String?)?.trim() ?? '',
      countryName: (json['country_name'] as String?)?.trim() ?? '',
      contactAddress: (json['contact_address'] as String?)?.trim() ?? '',
      website: (json['website'] as String?)?.trim() ?? '',
      tags: parsedTags,
      companyId: json['company_id'] is num ? (json['company_id'] as num).toInt() : null,
      companyName: (json['company_name'] as String?)?.trim() ?? '',
      avatarUrl: (json['avatar_url'] as String?)?.trim(),
      smartMetrics: metrics,
    );
  }

  /// Tên tổ chức/công ty đại diện (ưu tiên parentName nếu là người đại diện, ngược lại companyName)
  String get effectiveCompanyName {
    if (parentName.isNotEmpty) return parentName;
    if (companyName.isNotEmpty) return companyName;
    return isCompany ? name : '';
  }

  /// Nhãn hiển thị chức vụ & doanh nghiệp gọn gàng
  String get subtitleInfo {
    final parts = <String>[];
    if (function.isNotEmpty) parts.add(function);
    if (effectiveCompanyName.isNotEmpty && effectiveCompanyName != name) {
      parts.add(effectiveCompanyName);
    }
    return parts.join(' · ');
  }
}
