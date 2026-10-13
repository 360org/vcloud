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
  static const int _maxQueuedCandidates = 50;
  final List<RTCIceCandidate> _queuedRemoteCandidates = [];
  final List<RTCIceCandidate> _queuedLocalCandidates = [];

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

    // Nếu phía Odoo joinCall không trả về ICE servers (hoặc thiếu TURN), nạp dynamic config từ API /call/config
    List<dynamic> effectiveIceData = List<dynamic>.from(iceServersData);
    final hasTurnInData = effectiveIceData.any((s) {
      if (s is Map) {
        final u = s['urls'] ?? s['url'];
        return (u is List && u.any((url) => url.toString().startsWith('turn:'))) ||
            (u is String && u.startsWith('turn:'));
      }
      return false;
    });

    if (effectiveIceData.isEmpty || !hasTurnInData) {
      try {
        final dynamicIce = await repo.fetchCallConfig();
        if (dynamicIce.isNotEmpty) {
          if (effectiveIceData.isEmpty) {
            effectiveIceData = dynamicIce;
          } else {
            for (final d in dynamicIce) {
              final u = d['urls'] ?? d['url'];
              final isTurn = (u is List && u.any((url) => url.toString().startsWith('turn:'))) ||
                  (u is String && u.startsWith('turn:'));
              if (isTurn) effectiveIceData.add(d);
            }
          }
        }
      } catch (_) {}
    }

    // Chuyển đổi định dạng ICE servers sang WebRTC configuration
    final iceServers = <Map<String, dynamic>>[];
    for (final s in effectiveIceData) {
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

    // Đảm bảo luôn có STUN Google
    final hasStun = iceServers.any((s) {
      final u = s['urls'];
      return (u is List && u.any((url) => url.toString().startsWith('stun:'))) ||
          (u is String && u.startsWith('stun:'));
    });
    if (!hasStun) {
      iceServers.insert(0, {
        'urls': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'],
      });
    }

    // Cảnh báo nếu không có TURN server trong môi trường Symmetric NAT
    final hasTurn = iceServers.any((s) {
      final u = s['urls'];
      return (u is List && u.any((url) => url.toString().startsWith('turn:'))) ||
          (u is String && u.startsWith('turn:'));
    });
    if (!hasTurn) {
      debugPrint('ℹ️ [WebRTC] Lưu ý: Chưa nạp TURN Server. Cuộc gọi P2P có thể gặp hạn chế trên mạng Symmetric NAT.');
    }

    final configuration = <String, dynamic>{
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    };

    try {
      final pc = await createPeerConnection(configuration);
      _peerConnection = pc;

      pc.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('[WebRTC] Connection state: $state');
        onConnectionState?.call(state);
      };

      // Lắng nghe Remote Audio Track nhận được từ peer (chống mất tiếng 2 chiều)
      pc.onTrack = (RTCTrackEvent event) {
        debugPrint('[WebRTC] 🎧 Nhận remote track: kind=${event.track.kind}, id=${event.track.id}, enabled=${event.track.enabled}');
        if (event.track.kind == 'audio') {
          event.track.enabled = true;
          if (event.streams.isNotEmpty) {
            for (final stream in event.streams) {
              for (final track in stream.getAudioTracks()) {
                track.enabled = true;
              }
            }
          }
          if (!kIsWeb) {
            try {
              Helper.ensureAudioSession();
              Helper.setSpeakerphoneOn(_isSpeaker);
            } catch (_) {}
          }
        }
      };

      // Tương thích ngược với luồng onAddStream legacy
      pc.onAddStream = (MediaStream stream) {
        debugPrint('[WebRTC] 🎧 Nhận remote stream: id=${stream.id}, audioTracks=${stream.getAudioTracks().length}');
        for (final track in stream.getAudioTracks()) {
          track.enabled = true;
        }
        if (!kIsWeb) {
          try {
            Helper.ensureAudioSession();
            Helper.setSpeakerphoneOn(_isSpeaker);
          } catch (_) {}
        }
      };

      // Khi tìm thấy ICE Candidate cục bộ -> gửi sang peer qua Odoo 19 notify_call_members
      pc.onIceCandidate = (RTCIceCandidate candidate) {
        if (candidate.candidate == null) return;
        if (_targetSessionIds.isNotEmpty && _localSessionId > 0) {
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
        } else {
          if (_queuedLocalCandidates.length >= _maxQueuedCandidates) {
            _queuedLocalCandidates.removeAt(0);
          }
          _queuedLocalCandidates.add(candidate);
        }
      };

      // Thu âm Micro cục bộ (Voice call only)
      try {
        final mediaConstraints = <String, dynamic>{
          'audio': {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          },
          'video': false,
        };

        _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
        final stream = _localStream;
        if (stream != null) {
          for (final track in stream.getAudioTracks()) {
            track.enabled = true;
            if (!kIsWeb) {
              try {
                await Helper.setMicrophoneMute(false, track);
              } catch (_) {}
            }
            await pc.addTrack(track, stream);
          }
        }
      } catch (mediaErr) {
        debugPrint('⚠️ [WebRTC] Không thể khởi tạo Micro cục bộ ($mediaErr). Cuộc gọi tiếp tục ở chế độ nhận âm thanh (listen-only).');
      }

      if (!kIsWeb) {
        try {
          await Helper.ensureAudioSession();
          await Helper.setSpeakerphoneOn(_isSpeaker);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[WebRTC] Native initialization error: $e');
    }
  }

  /// 2. Caller tạo SDP Offer và gửi sang Callee
  Future<void> createAndSendOffer() async {
    final pc = _peerConnection;
    if (pc == null) return;

    final constraints = <String, dynamic>{
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    };

    final offer = await pc.createOffer(constraints);
    await pc.setLocalDescription(offer);

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
  Future<void> handleOfferAndSendAnswer(
    Map<String, dynamic> sdpMap, {
    int? targetSessionId,
  }) async {
    final pc = _peerConnection;
    if (pc == null) return;

    if (targetSessionId != null && targetSessionId > 0) {
      if (!_targetSessionIds.contains(targetSessionId)) {
        _targetSessionIds.add(targetSessionId);
      }
    }

    final description = RTCSessionDescription(
      sdpMap['sdp']?.toString(),
      sdpMap['type']?.toString(),
    );
    await pc.setRemoteDescription(description);
    _hasRemoteDescription = true;
    await _flushQueuedCandidates();

    final constraints = <String, dynamic>{
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': false,
    };

    final answer = await pc.createAnswer(constraints);
    await pc.setLocalDescription(answer);

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
    final pc = _peerConnection;
    if (pc == null) return;
    final description = RTCSessionDescription(
      sdpMap['sdp']?.toString(),
      sdpMap['type']?.toString(),
    );
    await pc.setRemoteDescription(description);
    _hasRemoteDescription = true;
    await _flushQueuedCandidates();
  }

  /// 5. Nhận ICE Candidate từ đối phương (Buffer nếu RemoteDescription chưa sẵn sàng)
  Future<void> handleRemoteCandidate(Map<String, dynamic> candidateMap) async {
    final pc = _peerConnection;
    if (pc == null) return;
    final candidate = RTCIceCandidate(
      candidateMap['candidate']?.toString(),
      candidateMap['sdpMid']?.toString(),
      candidateMap['sdpMLineIndex'] is num ? (candidateMap['sdpMLineIndex'] as num).toInt() : 0,
    );
    if (_hasRemoteDescription) {
      await pc.addCandidate(candidate);
    } else {
      if (_queuedRemoteCandidates.length >= _maxQueuedCandidates) {
        _queuedRemoteCandidates.removeAt(0);
      }
      _queuedRemoteCandidates.add(candidate);
    }
  }

  Future<void> _flushQueuedCandidates() async {
    final pc = _peerConnection;
    if (pc == null) return;
    for (final candidate in _queuedRemoteCandidates) {
      try {
        await pc.addCandidate(candidate);
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

  /// Cập nhật danh sách targetSessionIds và xả các local ICE candidate đang xếp hàng
  void updateTargetSessionIds(List<int> targetIds) {
    for (final id in targetIds) {
      if (id > 0 && !_targetSessionIds.contains(id)) {
        _targetSessionIds.add(id);
      }
    }
    _flushQueuedLocalCandidates();
  }

  void _flushQueuedLocalCandidates() {
    if (_localSessionId == 0 || _targetSessionIds.isEmpty) return;
    for (final candidate in List<RTCIceCandidate>.from(_queuedLocalCandidates)) {
      if (candidate.candidate == null) continue;
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
    }
    _queuedLocalCandidates.clear();
  }

  /// Hủy nhanh cuộc gọi giữa chừng và giải phóng bộ nhớ đệm
  void abort() {
    _queuedRemoteCandidates.clear();
    _queuedLocalCandidates.clear();
    _hasRemoteDescription = false;
  }

  /// Dọn dẹp tài nguyên cuộc gọi
  Future<void> dispose() async {
    abort();
    _queuedLocalCandidates.clear();
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
