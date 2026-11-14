class LinkMetadata {
  const LinkMetadata({
    required this.url,
    required this.originalUrl,
    required this.domain,
    this.title,
    this.description,
    this.imageUrl,
    required this.fetchedAt,
    this.isInternalOdooUrl = false,
  });

  /// URL đích đã chuẩn hóa (có scheme http/https)
  final String url;

  /// URL thô ban đầu trích xuất từ tin nhắn
  final String originalUrl;

  /// Tên miền hiển thị (VD: 'github.com', 'vnexpress.net') hoặc site_name
  final String domain;

  /// Tiêu đề OpenGraph / trang HTML
  final String? title;

  /// Mô tả OpenGraph / meta description
  final String? description;

  /// Đường dẫn ảnh đại diện (đã qua kiểm tra an toàn SSRF)
  final String? imageUrl;

  /// Thời điểm tải metadata
  final DateTime fetchedAt;

  /// Cờ đánh dấu URL thuộc hệ thống Odoo nội bộ
  final bool isInternalOdooUrl;

  /// Kiểm tra metadata có nội dung hiển thị tối thiểu (tiêu đề, mô tả hoặc ảnh)
  bool get hasContent =>
      (title?.trim().isNotEmpty == true) ||
      (description?.trim().isNotEmpty == true) ||
      (imageUrl?.trim().isNotEmpty == true);

  /// Kiểm tra metadata còn hạn sử dụng trong bộ nhớ đệm (TTL 24 giờ)
  bool isFresh({Duration ttl = const Duration(hours: 24)}) {
    return DateTime.now().difference(fetchedAt) < ttl;
  }

  factory LinkMetadata.fromJson(Map<String, dynamic> json) {
    return LinkMetadata(
      url: json['url']?.toString() ?? '',
      originalUrl: json['original_url']?.toString() ?? '',
      domain: json['domain']?.toString() ?? '',
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      imageUrl: json['image_url']?.toString(),
      fetchedAt: json['fetched_at'] != null
          ? DateTime.tryParse(json['fetched_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isInternalOdooUrl: json['is_internal_odoo_url'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'url': url,
      'original_url': originalUrl,
      'domain': domain,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'fetched_at': fetchedAt.toIso8601String(),
      'is_internal_odoo_url': isInternalOdooUrl,
    };
  }
}
