import 'package:flutter/foundation.dart';

@immutable
class LivechatChannelModel {
  final int id;
  final String name;
  final String description;
  final String? avatarUrl;
  final bool isAvailable;
  final String defaultMessage;

  const LivechatChannelModel({
    required this.id,
    required this.name,
    required this.description,
    this.avatarUrl,
    required this.isAvailable,
    required this.defaultMessage,
  });

  factory LivechatChannelModel.fromJson(Map<String, dynamic> json) {
    return LivechatChannelModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      isAvailable: json['is_available'] as bool? ?? false,
      defaultMessage: json['default_message'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'avatar_url': avatarUrl,
      'is_available': isAvailable,
      'default_message': defaultMessage,
    };
  }
}
