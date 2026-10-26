class AppMenuItem {
  const AppMenuItem({
    required this.id,
    required this.name,
    this.xmlid,
    this.actionId,
    this.webIcon,
    this.webIconData,
    this.nativeRoute,
    this.webUrl,
    this.isNative = false,
    this.isBookmarked = false,
  });

  final int id;
  final String name;
  final String? xmlid;
  final int? actionId;
  final String? webIcon;
  final String? webIconData;
  final String? nativeRoute;
  final String? webUrl;
  final bool isNative;
  final bool isBookmarked;

  factory AppMenuItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is num
        ? rawId.toInt()
        : int.tryParse(rawId?.toString() ?? '') ?? 0;

    final rawActionId = json['action_id'] ?? json['actionId'];
    final actionId = rawActionId is num
        ? rawActionId.toInt()
        : int.tryParse(rawActionId?.toString() ?? '');

    return AppMenuItem(
      id: id,
      name: (json['name'] ?? '').toString(),
      xmlid: json['xmlid']?.toString(),
      actionId: actionId,
      webIcon: (json['web_icon'] ?? json['webIcon'])?.toString(),
      webIconData: (json['web_icon_data'] ?? json['webIconData'])?.toString(),
      nativeRoute: (json['native_route'] ?? json['nativeRoute'])?.toString(),
      webUrl: (json['web_url'] ?? json['webUrl'])?.toString(),
      isNative: json['is_native'] == true || json['isNative'] == true,
      isBookmarked:
          json['is_bookmarked'] == true || json['isBookmarked'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (xmlid != null) 'xmlid': xmlid,
      if (actionId != null) 'action_id': actionId,
      if (webIcon != null) 'web_icon': webIcon,
      if (webIconData != null) 'web_icon_data': webIconData,
      if (nativeRoute != null) 'native_route': nativeRoute,
      if (webUrl != null) 'web_url': webUrl,
      'is_native': isNative,
      'is_bookmarked': isBookmarked,
    };
  }

  AppMenuItem copyWith({
    int? id,
    String? name,
    String? xmlid,
    int? actionId,
    String? webIcon,
    String? webIconData,
    String? nativeRoute,
    String? webUrl,
    bool? isNative,
    bool? isBookmarked,
  }) {
    return AppMenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      xmlid: xmlid ?? this.xmlid,
      actionId: actionId ?? this.actionId,
      webIcon: webIcon ?? this.webIcon,
      webIconData: webIconData ?? this.webIconData,
      nativeRoute: nativeRoute ?? this.nativeRoute,
      webUrl: webUrl ?? this.webUrl,
      isNative: isNative ?? this.isNative,
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppMenuItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          xmlid == other.xmlid &&
          actionId == other.actionId &&
          webIcon == other.webIcon &&
          webIconData == other.webIconData &&
          nativeRoute == other.nativeRoute &&
          webUrl == other.webUrl &&
          isNative == other.isNative &&
          isBookmarked == other.isBookmarked;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      xmlid.hashCode ^
      actionId.hashCode ^
      webIcon.hashCode ^
      webIconData.hashCode ^
      nativeRoute.hashCode ^
      webUrl.hashCode ^
      isNative.hashCode ^
      isBookmarked.hashCode;
}

class AppUtilityItem {
  const AppUtilityItem({
    required this.id,
    required this.name,
    this.icon,
    this.url,
    this.nativeRoute,
    this.webUrl,
  });

  final String id;
  final String name;
  final String? icon;
  final String? url;
  final String? nativeRoute;
  final String? webUrl;

  factory AppUtilityItem.fromJson(Map<String, dynamic> json) {
    return AppUtilityItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      icon: json['icon']?.toString(),
      url: json['url']?.toString(),
      nativeRoute: (json['native_route'] ?? json['nativeRoute'])?.toString(),
      webUrl: (json['web_url'] ?? json['webUrl'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (icon != null) 'icon': icon,
      if (url != null) 'url': url,
      if (nativeRoute != null) 'native_route': nativeRoute,
      if (webUrl != null) 'web_url': webUrl,
    };
  }

  AppUtilityItem copyWith({
    String? id,
    String? name,
    String? icon,
    String? url,
    String? nativeRoute,
    String? webUrl,
  }) {
    return AppUtilityItem(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      url: url ?? this.url,
      nativeRoute: nativeRoute ?? this.nativeRoute,
      webUrl: webUrl ?? this.webUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUtilityItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          icon == other.icon &&
          url == other.url &&
          nativeRoute == other.nativeRoute &&
          webUrl == other.webUrl;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      icon.hashCode ^
      url.hashCode ^
      nativeRoute.hashCode ^
      webUrl.hashCode;
}
