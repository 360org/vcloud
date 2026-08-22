import 'package:equatable/equatable.dart';

class ChatV2Reaction extends Equatable {
  final String content;
  final int count;
  final List<dynamic> partners;
  final bool hasMe;

  const ChatV2Reaction({
    required this.content,
    required this.count,
    required this.partners,
    required this.hasMe,
  });

  factory ChatV2Reaction.fromJson(Map<String, dynamic> json) {
    return ChatV2Reaction(
      content: json['content'] as String? ?? '',
      count: json['count'] as int? ?? 0,
      partners: json['partners'] as List<dynamic>? ?? [],
      hasMe: json['has_me'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'count': count,
      'partners': partners,
      'has_me': hasMe,
    };
  }

  ChatV2Reaction copyWith({
    String? content,
    int? count,
    List<dynamic>? partners,
    bool? hasMe,
  }) {
    return ChatV2Reaction(
      content: content ?? this.content,
      count: count ?? this.count,
      partners: partners ?? this.partners,
      hasMe: hasMe ?? this.hasMe,
    );
  }

  @override
  List<Object?> get props => [content, count, partners, hasMe];
}
