import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../data/chat_v2_call_repository.dart';

/// Callbacks thông báo trạng thái từ WebRTC Engine
typedef OnConnectionStateChanged = void Function(RTCPeerConnectionState state);
typedef OnIceCandidateCallback = void Function(RTCIceCandidate candidate);

/// Engine quản lý WebRTC PeerConnection, MediaStream âm thanh P2P
class ChatV2WebRtcEngine {
  final ChatV2CallRepository repo;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _hasRemoteDescription = false;
  final List<RTCIceCandidate> _queuedRemoteCandidates = [];

  int _localSessionId = 0;
  List<int> _targetSessionIds = [];

  OnConnectionStateChanged? onConnectionState;

  ChatV2WebRtcEngine({required this.repo});

  int get localSessionId => _localSessionId;
  bool get isMuted => _isMuted;
  bool get isSpeaker => _isSpeaker;

  /// 1. Khởi tạo PeerConnection với ICE servers từ Odoo
  Future<void> initialize({
    required int localSessionId,
    required List<int> targetSessionIds,
    required List<dynamic> iceServersData,
  }) async {
    _localSessionId = localSessionId;
    _targetSessionIds = targetSessionIds;

    // Chuyển đổi định dạng ICE servers từ Odoo sang WebRTC configuration
    final iceServers = <Map<String, dynamic>>[];
    for (final s in iceServersData) {
      if (s is Map) {
        final serverMap = <String, dynamic>{};
        if (s['urls'] != null) {
          serverMap['urls'] = s['urls'];
        } else if (s['url'] != null) {
          serverMap['urls'] = s['url'];
        }
        if (s['username'] != null) serverMap['username'] = s['username'];
        if (s['credential'] != null) serverMap['credential'] = s['credential'];
        iceServers.add(serverMap);
      }
    }

    // Fallback STUN Google nếu Odoo không cấu hình TURN
    if (iceServers.isEmpty) {
      iceServers.add({
        'urls': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'],
      });
    }

    final configuration = <String, dynamic>{
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[WebRTC] Connection state: $state');
      onConnectionState?.call(state);
    };

    // Khi tìm thấy ICE Candidate cục bộ -> gửi sang peer qua Odoo 19 notify_call_members
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null) return;
      _sendSignaling(
        event: 'ice-candidate',
        payload: {
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        },
      );
    };

    // Thu âm Micro cục bộ (Voice call only)
    final mediaConstraints = <String, dynamic>{
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    for (final track in _localStream!.getAudioTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }
  }

  /// 2. Caller tạo SDP Offer và gửi sang Callee
  Future<void> createAndSendOffer() async {
    if (_peerConnection == null) return;

    final constraints = <String, dynamic>{
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    };

    final offer = await _peerConnection!.createOffer(constraints);
    await _peerConnection!.setLocalDescription(offer);

    await _sendSignaling(
      event: 'offer',
      payload: {
        'sdp': {
          'type': offer.type,
          'sdp': offer.sdp,
        },
      },
    );
  }

  /// 3. Callee nhận Offer, tạo và gửi lại SDP Answer
  Future<void> handleOfferAndSendAnswer(Map<String, dynamic> sdpMap) async {
    if (_peerConnection == null) return;

    final description = RTCSessionDescription(
      sdpMap['sdp']?.toString(),
      sdpMap['type']?.toString(),
    );
    await _peerConnection!.setRemoteDescription(description);
    _hasRemoteDescription = true;
    await _flushQueuedCandidates();

    final constraints = <String, dynamic>{
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    };

    final answer = await _peerConnection!.createAnswer(constraints);
    await _peerConnection!.setLocalDescription(answer);

    await _sendSignaling(
      event: 'answer',
      payload: {
        'sdp': {
          'type': answer.type,
          'sdp': answer.sdp,
        },
      },
    );
  }

  /// 4. Caller nhận SDP Answer từ Callee
  Future<void> handleAnswer(Map<String, dynamic> sdpMap) async {
    if (_peerConnection == null) return;
    final description = RTCSessionDescription(
      sdpMap['sdp']?.toString(),
      sdpMap['type']?.toString(),
    );
    await _peerConnection!.setRemoteDescription(description);
    _hasRemoteDescription = true;
    await _flushQueuedCandidates();
  }

  /// 5. Nhận ICE Candidate từ đối phương (Buffer nếu RemoteDescription chưa sẵn sàng)
  Future<void> handleRemoteCandidate(Map<String, dynamic> candidateMap) async {
    if (_peerConnection == null) return;
    final candidate = RTCIceCandidate(
      candidateMap['candidate']?.toString(),
      candidateMap['sdpMid']?.toString(),
      candidateMap['sdpMLineIndex'] is num ? (candidateMap['sdpMLineIndex'] as num).toInt() : 0,
    );
    if (_hasRemoteDescription) {
      await _peerConnection!.addCandidate(candidate);
    } else {
      _queuedRemoteCandidates.add(candidate);
    }
  }

  Future<void> _flushQueuedCandidates() async {
    if (_peerConnection == null) return;
    for (final candidate in _queuedRemoteCandidates) {
      try {
        await _peerConnection!.addCandidate(candidate);
      } catch (e) {
        debugPrint('[WebRTC] Lỗi add queued ICE candidate: $e');
      }
    }
    _queuedRemoteCandidates.clear();
  }

  /// 6. Gửi bản tin Signaling qua Odoo 19 Core
  Future<void> _sendSignaling({
    required String event,
    required Map<String, dynamic> payload,
  }) async {
    if (_localSessionId == 0 || _targetSessionIds.isEmpty) return;

    final content = jsonEncode({
      'event': event,
      'payload': payload,
    });

    await repo.notifyCallMembers(
      senderSessionId: _localSessionId,
      targetSessionIds: _targetSessionIds,
      content: content,
    );
  }

  /// Bật/Tắt Micro
  void toggleMute() {
    _isMuted = !_isMuted;
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !_isMuted;
      }
    }
    // Đồng bộ trạng thái mute lên Odoo Discuss để Web thấy icon gạch chéo micro
    if (_localSessionId > 0) {
      repo.updateAndBroadcast(
        sessionId: _localSessionId,
        values: {'is_muted': _isMuted},
      );
    }
  }

  /// Bật/Tắt Loa ngoài
  void toggleSpeaker() {
    _isSpeaker = !_isSpeaker;
    if (!kIsWeb) {
      Helper.setSpeakerphoneOn(_isSpeaker);
    }
  }

  /// Dọn dẹp tài nguyên cuộc gọi
  Future<void> dispose() async {
    try {
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });
      await _localStream?.dispose();
      _localStream = null;
    } catch (_) {}

    try {
      await _peerConnection?.close();
      await _peerConnection?.dispose();
      _peerConnection = null;
    } catch (_) {}
  }
}
