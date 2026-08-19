import 'dart:convert';

/// Đại diện cho một phương án bình chọn
class ChatV2PollOption {
  final int id;
  final String text;
  final List<int> voterIds;
  final List<String> voterNames;
  final int voteCount;

  const ChatV2PollOption({
    required this.id,
    required this.text,
    this.voterIds = const [],
    this.voterNames = const [],
    this.voteCount = 0,
  });

  bool hasVoted(int? partnerId) {
    if (partnerId == null) return false;
    return voterIds.contains(partnerId);
  }

  factory ChatV2PollOption.fromJson(Map<String, dynamic> json) {
    final rawVoters = json['voters'] as List<dynamic>? ?? [];
    final vIds = <int>[];
    final vNames = <String>[];

    for (final v in rawVoters) {
      if (v is Map<String, dynamic>) {
        if (v['id'] != null) vIds.add((v['id'] as num).toInt());
        if (v['name'] != null) vNames.add(v['name'].toString());
      } else if (v is num) {
        vIds.add(v.toInt());
      }
    }

    final rawVoterIds = json['voter_ids'] as List<dynamic>?;
    if (rawVoterIds != null) {
      for (final id in rawVoterIds) {
        if (id is num && !vIds.contains(id.toInt())) {
          vIds.add(id.toInt());
        }
      }
    }

    return ChatV2PollOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      text: json['text']?.toString() ?? '',
      voterIds: vIds,
      voterNames: vNames,
      voteCount: (json['vote_count'] as num?)?.toInt() ?? vIds.length,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'voters': [
        for (int i = 0; i < voterIds.length; i++)
          {
            'id': voterIds[i],
            'name': i < voterNames.length ? voterNames[i] : 'Thành viên',
          }
      ],
      'voter_ids': voterIds,
      'vote_count': voteCount,
    };
  }

  ChatV2PollOption copyWith({
    int? id,
    String? text,
    List<int>? voterIds,
    List<String>? voterNames,
    int? voteCount,
  }) {
    return ChatV2PollOption(
      id: id ?? this.id,
      text: text ?? this.text,
      voterIds: voterIds ?? this.voterIds,
      voterNames: voterNames ?? this.voterNames,
      voteCount: voteCount ?? this.voteCount,
    );
  }
}

/// Đại diện cho toàn bộ cuộc bình chọn trong tin nhắn
class ChatV2Poll {
  final String id;
  final String question;
  final List<ChatV2PollOption> options;
  final bool allowMultiple;
  final int? creatorId;
  final String? creatorName;
  final int totalVotes;
  final int totalVoters;
  final bool isClosed;

  const ChatV2Poll({
    required this.id,
    required this.question,
    required this.options,
    this.allowMultiple = false,
    this.creatorId,
    this.creatorName,
    this.totalVotes = 0,
    this.totalVoters = 0,
    this.isClosed = false,
  });

  bool hasUserVoted(int? partnerId) {
    if (partnerId == null) return false;
    return options.any((opt) => opt.hasVoted(partnerId));
  }

  List<int> getUserVotedOptionIds(int? partnerId) {
    if (partnerId == null) return [];
    return options
        .where((opt) => opt.hasVoted(partnerId))
        .map((opt) => opt.id)
        .toList();
  }

  factory ChatV2Poll.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? [];
    final parsedOptions = rawOptions
        .whereType<Map<String, dynamic>>()
        .map((o) => ChatV2PollOption.fromJson(o))
        .toList();

    return ChatV2Poll(
      id: json['id']?.toString() ?? '',
      question: json['question']?.toString() ?? '',
      options: parsedOptions,
      allowMultiple: json['allow_multiple'] == true,
      creatorId: (json['creator_id'] as num?)?.toInt(),
      creatorName: json['creator_name']?.toString(),
      totalVotes: (json['total_votes'] as num?)?.toInt() ??
          parsedOptions.fold(0, (sum, o) => sum + o.voteCount),
      totalVoters: (json['total_voters'] as num?)?.toInt() ?? 0,
      isClosed: json['is_closed'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options.map((o) => o.toJson()).toList(),
      'allow_multiple': allowMultiple,
      'creator_id': creatorId,
      'creator_name': creatorName,
      'total_votes': totalVotes,
      'total_voters': totalVoters,
      'is_closed': isClosed,
    };
  }

  /// Trích xuất ChatV2Poll từ chuỗi HTML body hoặc content của mail.message
  static ChatV2Poll? tryParseFromBody(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;

    final body = raw.trim();

    // 1. Tự động unescape HTML entities để nhận diện chuỗi JSON / Comment dù bị Odoo encode
    final unescaped = body
        .replaceAll('&quot;', '"')
        .replaceAll('&#34;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');

    try {
      // 2. Tìm comment: <!-- POLL_DATA:{...} -->
      final commentMatch = RegExp(
        r'<!--\s*POLL_DATA:\s*(\{.*?\})\s*-->',
        dotAll: true,
      ).firstMatch(unescaped);

      if (commentMatch != null) {
        final jsonStr = commentMatch.group(1);
        if (jsonStr != null) {
          final decoded = json.decode(jsonStr) as Map<String, dynamic>;
          return ChatV2Poll.fromJson(decoded);
        }
      }

      // 3. Tìm thẻ <div class="o_poll_json"...>{...}</div> hoặc <span class="o_poll_data"...>{...}</span>
      final jsonTagMatch = RegExp(
        r'class=[\x27"](?:o_poll_json|o_poll_data)[\x27"][^>]*>(\{.*?\})<\/(?:div|span)>',
        dotAll: true,
      ).firstMatch(unescaped);
      if (jsonTagMatch != null) {
        final rawJson = jsonTagMatch.group(1);
        if (rawJson != null) {
          final decoded = json.decode(rawJson) as Map<String, dynamic>;
          return ChatV2Poll.fromJson(decoded);
        }
      }

      // 4. Tìm data-poll="..."
      final attrMatch = RegExp(r'data-poll=[\x27"]([^\x27"]+)[\x27"]').firstMatch(unescaped);
      if (attrMatch != null) {
        final rawAttr = attrMatch.group(1);
        if (rawAttr != null) {
          final decoded = json.decode(rawAttr) as Map<String, dynamic>;
          return ChatV2Poll.fromJson(decoded);
        }
      }

      // 5. Tìm chuỗi JSON nhúng chứa "question" và "options" bằng bộ đếm ngoặc nhọn
      for (final marker in ['"question":', '"options":', '"id":"poll_', '"id": "poll_']) {
        final targetIdx = unescaped.indexOf(marker);
        if (targetIdx != -1) {
          final startBrace = unescaped.lastIndexOf('{', targetIdx);
          if (startBrace != -1) {
            int depth = 0;
            int endBrace = -1;
            for (int i = startBrace; i < unescaped.length; i++) {
              if (unescaped[i] == '{') {
                depth++;
              } else if (unescaped[i] == '}') {
                depth--;
                if (depth == 0) {
                  endBrace = i;
                  break;
                }
              }
            }
            if (endBrace != -1) {
              final rawJson = unescaped.substring(startBrace, endBrace + 1);
              final decoded = json.decode(rawJson) as Map<String, dynamic>;
              if (decoded.containsKey('question') && decoded.containsKey('options')) {
                return ChatV2Poll.fromJson(decoded);
              }
            }
          }
        }
      }

      // 6. FALLBACK PARSER: Nhận diện cấu trúc HTML / Text thuần khi Odoo sanitize lọc mất JSON
      // Dạng: 📊 <Câu hỏi> ... <Phương án 1> (0 phiếu) ... <Phương án 2> (0 phiếu)
      if (unescaped.contains('📊') || unescaped.contains('o_poll_card') || unescaped.contains('[Bình chọn]')) {
        String question = '';
        final qMatch = RegExp(r'(?:📊|\[Bình chọn\])\s*(?:<b>)?([^<\n]+?)(?:<\/b>)?(?:\s*<|\s*\n|\s*\d+\s*\()').firstMatch(unescaped);
        if (qMatch != null) {
          question = qMatch.group(1)?.trim() ?? '';
        }

        final options = <ChatV2PollOption>[];
        // Quét các lựa chọn dạng <li><b>Opt</b> (X phiếu)</li> hoặc Opt (X phiếu)
        final optRegex = RegExp(r'(?:<li>\s*(?:<b>)?)?([^\n<]+?)(?:<\/b>)?\s*\((\d+)\s*(?:phiếu|votes?)\)(?:<\/li>)?', caseSensitive: false);
        final optMatches = optRegex.allMatches(unescaped);

        int optId = 1;
        for (final m in optMatches) {
          var optText = m.group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '';
          if (optText.startsWith('📊')) {
            optText = optText.replaceFirst(RegExp(r'📊\s*'), '').trim();
          }
          final votes = int.tryParse(m.group(2) ?? '0') ?? 0;
          if (optText.isNotEmpty && optText != question && !optText.toLowerCase().contains('tổng cộng')) {
            options.add(ChatV2PollOption(
              id: optId++,
              text: optText,
              voteCount: votes,
            ));
          }
        }

        if (options.length >= 2) {
          int totalVotes = options.fold(0, (sum, o) => sum + o.voteCount);
          final totalMatch = RegExp(r'Tổng cộng:\s*(\d+)').firstMatch(unescaped);
          if (totalMatch != null) {
            totalVotes = int.tryParse(totalMatch.group(1) ?? '') ?? totalVotes;
          }

          return ChatV2Poll(
            id: 'poll_${question.hashCode}',
            question: question.isNotEmpty ? question : 'Bình chọn',
            options: options,
            totalVotes: totalVotes,
            totalVoters: totalVotes,
          );
        }
      }
    } catch (_) {
      // Bỏ qua lỗi cú pháp nếu chuỗi không hợp lệ
    }

    return null;
  }

  /// Tạo chuỗi HTML tin nhắn chứa POLL_DATA hoàn chỉnh
  static String buildMessageBody({
    required String question,
    required List<String> options,
    bool allowMultiple = false,
    int? creatorId,
    String? creatorName,
  }) {
    final pollId = 'poll_${DateTime.now().millisecondsSinceEpoch}';
    final optionList = <Map<String, dynamic>>[];
    for (int i = 0; i < options.length; i++) {
      optionList.add({
        'id': i + 1,
        'text': options[i].trim(),
        'voters': [],
        'voter_ids': [],
        'vote_count': 0,
      });
    }

    final pollData = {
      'id': pollId,
      'question': question.trim(),
      'options': optionList,
      'allow_multiple': allowMultiple,
      'creator_id': creatorId,
      'creator_name': creatorName,
      'total_votes': 0,
      'total_voters': 0,
      'is_closed': false,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    final jsonStr = json.encode(pollData);

    final buffer = StringBuffer();
    buffer.write('<div class="o_poll_card" data-poll="${jsonStr.replaceAll('"', '&quot;')}">');
    buffer.write('<p>📊 <b>${question.trim()}</b></p>');
    buffer.write('<ul>');
    for (final opt in options) {
      buffer.write('<li><b>${opt.trim()}</b> (0 phiếu)</li>');
    }
    buffer.write('</ul>');
    buffer.write('<p><i>Tổng cộng: 0 lượt bình chọn</i></p>');
    buffer.write('<div class="o_poll_json" style="display:none;font-size:0px;line-height:0;opacity:0;">$jsonStr</div>');
    buffer.write('<!-- POLL_DATA:$jsonStr -->');
    buffer.write('</div>');

    return buffer.toString();
  }
}
