/// Trạng thái của một phiên gọi thoại
enum ChatV2CallState {
  idle,
  outgoingRinging,
  incomingRinging,
  connecting,
  connected,
  ended,
  rejected,
  missed,
  cancelled,
  failed;

  static ChatV2CallState fromString(String? val) {
    switch (val) {
      case 'ringing':
        return ChatV2CallState.outgoingRinging;
      case 'connecting':
        return ChatV2CallState.connecting;
      case 'connected':
        return ChatV2CallState.connected;
      case 'ended':
        return ChatV2CallState.ended;
      case 'rejected':
        return ChatV2CallState.rejected;
      case 'missed':
        return ChatV2CallState.missed;
      case 'cancelled':
        return ChatV2CallState.cancelled;
      default:
        return ChatV2CallState.idle;
    }
  }
}

/// Dữ liệu một phiên gọi thoại VCloud Voice Call
class ChatV2CallSession {
  final int id;
  final int channelId;
  final int callerId;
  final String callerName;
  final String? callerAvatar;
  final int receiverId;
  final String receiverName;
  final String? receiverAvatar;
  final ChatV2CallState state;
  final int duration;
  final bool isCaller;
  final String? sdpOffer;
  final String? sdpAnswer;
  final List<dynamic> iceCandidates;
  final DateTime? startedAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;

  const ChatV2CallSession({
    required this.id,
    required this.channelId,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatar,
    required this.state,
    this.duration = 0,
    this.isCaller = false,
    this.sdpOffer,
    this.sdpAnswer,
    this.iceCandidates = const [],
    this.startedAt,
    this.connectedAt,
    this.endedAt,
  });

  /// Định dạng thời lượng đàm thoại thành mm:ss (VD: 65s -> 01:05)
  String get formattedDuration {
    final mins = duration ~/ 60;
    final secs = duration % 60;
    final minStr = mins.toString().padLeft(2, '0');
    final secStr = secs.toString().padLeft(2, '0');
    return '$minStr:$secStr';
  }

  factory ChatV2CallSession.fromJson(Map<String, dynamic> json, {bool isReceiverView = false}) {
    final rawState = json['state']?.toString();
    ChatV2CallState stateEnum = ChatV2CallState.fromString(rawState);

    // Phân biệt outgoing vs incoming khi ở trạng thái ringing
    final isCallerVal = json['is_caller'] == true || (!isReceiverView && json['is_caller'] != false);
    if (stateEnum == ChatV2CallState.outgoingRinging && !isCallerVal) {
      stateEnum = ChatV2CallState.incomingRinging;
    }

    return ChatV2CallSession(
      id: (json['id'] is int) ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      channelId: (json['channel_id'] is int) ? json['channel_id'] as int : int.tryParse(json['channel_id']?.toString() ?? '0') ?? 0,
      callerId: (json['caller_id'] is int) ? json['caller_id'] as int : int.tryParse(json['caller_id']?.toString() ?? '0') ?? 0,
      callerName: json['caller_name']?.toString() ?? 'Người gọi',
      callerAvatar: json['caller_avatar']?.toString(),
      receiverId: (json['receiver_id'] is int) ? json['receiver_id'] as int : int.tryParse(json['receiver_id']?.toString() ?? '0') ?? 0,
      receiverName: json['receiver_name']?.toString() ?? 'Người nhận',
      receiverAvatar: json['receiver_avatar']?.toString(),
      state: stateEnum,
      duration: (json['duration'] is int) ? json['duration'] as int : int.tryParse(json['duration']?.toString() ?? '0') ?? 0,
      isCaller: isCallerVal,
      sdpOffer: json['sdp_offer']?.toString(),
      sdpAnswer: json['sdp_answer']?.toString(),
      iceCandidates: (json['ice_candidates'] is List) ? json['ice_candidates'] as List<dynamic> : const [],
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at'].toString()) : null,
      connectedAt: json['connected_at'] != null ? DateTime.tryParse(json['connected_at'].toString()) : null,
      endedAt: json['ended_at'] != null ? DateTime.tryParse(json['ended_at'].toString()) : null,
    );
  }

  ChatV2CallSession copyWith({
    int? id,
    int? channelId,
    int? callerId,
    String? callerName,
    String? callerAvatar,
    int? receiverId,
    String? receiverName,
    String? receiverAvatar,
    ChatV2CallState? state,
    int? duration,
    bool? isCaller,
    String? sdpOffer,
    String? sdpAnswer,
    List<dynamic>? iceCandidates,
    DateTime? startedAt,
    DateTime? connectedAt,
    DateTime? endedAt,
  }) {
    return ChatV2CallSession(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerAvatar: callerAvatar ?? this.callerAvatar,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverAvatar: receiverAvatar ?? this.receiverAvatar,
      state: state ?? this.state,
      duration: duration ?? this.duration,
      isCaller: isCaller ?? this.isCaller,
      sdpOffer: sdpOffer ?? this.sdpOffer,
      sdpAnswer: sdpAnswer ?? this.sdpAnswer,
      iceCandidates: iceCandidates ?? this.iceCandidates,
      startedAt: startedAt ?? this.startedAt,
      connectedAt: connectedAt ?? this.connectedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }
}
