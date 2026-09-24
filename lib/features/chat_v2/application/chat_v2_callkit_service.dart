import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

/// Service quản lý giao diện CallKit / Full-Screen Incoming Call UI trên iOS & Android
class ChatV2CallKitService {
  ChatV2CallKitService._();
  static final ChatV2CallKitService instance = ChatV2CallKitService._();

  bool _isInitialized = false;

  void Function(Map<String, dynamic> extra)? onAcceptCall;
  void Function(Map<String, dynamic> extra)? onDeclineCall;
  void Function(Map<String, dynamic> extra)? onEndCall;
  void Function(Map<String, dynamic> extra)? onTimeoutCall;

  /// Khởi tạo listener lắng nghe các sự kiện hành động từ CallKit
  void initialize({
    void Function(Map<String, dynamic> extra)? onAccept,
    void Function(Map<String, dynamic> extra)? onDecline,
    void Function(Map<String, dynamic> extra)? onEnd,
    void Function(Map<String, dynamic> extra)? onTimeout,
  }) {
    if (kIsWeb) return;
    onAcceptCall = onAccept;
    onDeclineCall = onDecline;
    onEndCall = onEnd;
    onTimeoutCall = onTimeout;

    if (_isInitialized) return;
    _isInitialized = true;

    try {
      FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
        if (event == null) return;

        switch (event) {
          case CallEventActionCallAccept(:final callKitParams):
            final extra = callKitParams.extra != null
                ? Map<String, dynamic>.from(callKitParams.extra!)
                : <String, dynamic>{};
            debugPrint('[CallKit] Người dùng bấm Chấp nhận cuộc gọi: ${callKitParams.id}');
            onAcceptCall?.call(extra);
            break;
          case CallEventActionCallDecline(:final callKitParams):
            final extra = callKitParams.extra != null
                ? Map<String, dynamic>.from(callKitParams.extra!)
                : <String, dynamic>{};
            debugPrint('[CallKit] Người dùng bấm Từ chối cuộc gọi: ${callKitParams.id}');
            onDeclineCall?.call(extra);
            break;
          case CallEventActionCallEnded(:final callKitParams):
            final extra = callKitParams.extra != null
                ? Map<String, dynamic>.from(callKitParams.extra!)
                : <String, dynamic>{};
            debugPrint('[CallKit] Cuộc gọi kết thúc từ CallKit: ${callKitParams.id}');
            onEndCall?.call(extra);
            break;
          case CallEventActionCallTimeout(:final id):
            debugPrint('[CallKit] Hết thời gian chờ cuộc gọi (Timeout): $id');
            onTimeoutCall?.call(<String, dynamic>{'id': id});
            break;
          default:
            break;
        }
      });
    } catch (e) {
      debugPrint('[CallKit] Lỗi khởi tạo event listener: $e');
    }
  }

  /// Hiển thị màn hình cuộc gọi đến đè toàn màn hình / Apple CallKit
  Future<void> showIncomingCall({
    required String callUuid,
    required String callerName,
    String? callerAvatar,
    required int channelId,
    required int callerId,
    int duration = 30000,
  }) async {
    if (kIsWeb) return;

    final params = CallKitParams(
      id: callUuid,
      nameCaller: callerName,
      appName: 'VCloud',
      avatar: callerAvatar,
      handle: 'Cuộc gọi thoại',
      type: 0, // 0: Audio Call, 1: Video Call
      duration: duration,
      extra: <String, dynamic>{
        'channel_id': channelId,
        'caller_id': callerId,
        'caller_name': callerName,
      },
      headers: <String, dynamic>{'platform': 'flutter'},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0956FC',
        actionColor: '#4CAF50',
        textColor: '#FFFFFF',
        incomingCallNotificationChannelName: 'Cuộc gọi đến',
        missedCallNotificationChannelName: 'Cuộc gọi nhỡ',
        isShowCallID: false,
        textAccept: 'Trả lời',
        textDecline: 'Từ chối',
      ),
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: false,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'voiceChat',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    try {
      await FlutterCallkitIncoming.showCallkitIncoming(params);
      debugPrint('[CallKit] Đã hiển thị CallKit incoming UI cho UUID: $callUuid');
    } catch (e) {
      debugPrint('[CallKit] Lỗi hiển thị showCallkitIncoming: $e');
    }
  }

  /// Dập / Ẩn màn hình CallKit khi cuộc gọi đã kết thúc hoặc bị hủy
  Future<void> endCall(String callUuid) async {
    if (kIsWeb) return;
    try {
      await FlutterCallkitIncoming.endCall(callUuid);
    } catch (e) {
      debugPrint('[CallKit] Lỗi endCall: $e');
    }
  }

  /// Dập tất cả các cuộc gọi CallKit đang reo
  Future<void> endAllCalls() async {
    if (kIsWeb) return;
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('[CallKit] Lỗi endAllCalls: $e');
    }
  }

  /// Lấy danh sách cuộc gọi CallKit đang hoạt động
  Future<List<dynamic>?> activeCalls() async {
    if (kIsWeb) return [];
    try {
      return await FlutterCallkitIncoming.activeCalls();
    } catch (e) {
      debugPrint('[CallKit] Lỗi activeCalls: $e');
      return [];
    }
  }
}
