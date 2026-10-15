import 'package:flutter/foundation.dart';

@immutable
class LivechatOperatorModel {
  final int id;
  final String name;
  final String livechatUsername;
  final String? avatarUrl;

  const LivechatOperatorModel({
    required this.id,
    required this.name,
    required this.livechatUsername,
    this.avatarUrl,
  });

  factory LivechatOperatorModel.fromJson(Map<String, dynamic> json) {
    return LivechatOperatorModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      livechatUsername: json['livechat_username'] as String? ?? json['name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'livechat_username': livechatUsername,
      'avatar_url': avatarUrl,
    };
  }
}

@immutable
class LivechatLastMessageModel {
  final int id;
  final String authorName;
  final String body;
  final String? date;

  const LivechatLastMessageModel({
    required this.id,
    required this.authorName,
    required this.body,
    this.date,
  });

  factory LivechatLastMessageModel.fromJson(Map<String, dynamic> json) {
    return LivechatLastMessageModel(
      id: json['id'] as int? ?? 0,
      authorName: json['author_name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      date: json['date'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_name': authorName,
      'body': body,
      'date': date,
    };
  }
}

@immutable
class LivechatSessionModel {
  final int channelId;
  final String uuid;
  final String channelName;
  final String channelType;
  final String? avatarUrl;
  final bool isOperatorOnline;
  final LivechatOperatorModel? operator;
  final LivechatLastMessageModel? lastMessage;

  const LivechatSessionModel({
    required this.channelId,
    required this.uuid,
    required this.channelName,
    required this.channelType,
    this.avatarUrl,
    required this.isOperatorOnline,
    this.operator,
    this.lastMessage,
  });

  factory LivechatSessionModel.fromJson(Map<String, dynamic> json) {
    return LivechatSessionModel(
      channelId: json['channel_id'] as int? ?? 0,
      uuid: json['uuid'] as String? ?? '',
      channelName: json['channel_name'] as String? ?? '',
      channelType: json['channel_type'] as String? ?? 'livechat',
      avatarUrl: json['avatar_url'] as String?,
      isOperatorOnline: json['is_operator_online'] as bool? ?? false,
      operator: json['operator'] != null && json['operator'] is Map<String, dynamic>
          ? LivechatOperatorModel.fromJson(json['operator'] as Map<String, dynamic>)
          : null,
      lastMessage: json['last_message'] != null && json['last_message'] is Map<String, dynamic>
          ? LivechatLastMessageModel.fromJson(json['last_message'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channel_id': channelId,
      'uuid': uuid,
      'channel_name': channelName,
      'channel_type': channelType,
      'avatar_url': avatarUrl,
      'is_operator_online': isOperatorOnline,
      'operator': operator?.toJson(),
      'last_message': lastMessage?.toJson(),
    };
  }
}
