import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/api/mobile_attachment_repository.dart';
import '../../../../core/api/odoo_api_client.dart';
import '../../../../core/utils/local_attachment_cache.dart';
import '../../data/models/chat_v2_message.dart';

class ChatV2VoiceMessagePlayer extends StatefulWidget {
  final ChatV2Attachment attachment;
  final bool isMine;

  const ChatV2VoiceMessagePlayer({
    super.key,
    required this.attachment,
    required this.isMine,
  });

  @override
  State<ChatV2VoiceMessagePlayer> createState() => _ChatV2VoiceMessagePlayerState();
}

class _ChatV2VoiceMessagePlayerState extends State<ChatV2VoiceMessagePlayer> {
  late final AudioPlayer _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoading = false;
  Uint8List? _audioBytes;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state == PlayerState.completed) {
            _position = Duration.zero;
          }
        });
      }
    });

    _player.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          if (newDuration > Duration.zero) {
            _duration = newDuration;
          }
        });
      }
    });

    _player.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _togglePlay() async {
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        if (_position == Duration.zero ||
            _player.state == PlayerState.completed ||
            _player.state == PlayerState.stopped) {
          setState(() => _isLoading = true);

          Uint8List? bytes = _audioBytes ?? widget.attachment.bytes;

          // 1. Kiểm tra cache
          if (bytes == null || bytes.isEmpty) {
            final cacheKey = widget.attachment.name;
            bytes = LocalAttachmentCache.get(widget.attachment.id, altKey: cacheKey);
          }

          // 2. Fetch authenticated bytes từ Odoo API
          if (bytes == null || bytes.isEmpty) {
            final attId = int.tryParse(widget.attachment.id);
            if (attId != null && attId > 0) {
              bytes = await MobileAttachmentRepository().fetchBytes(
                attId,
                accessToken: widget.attachment.accessToken,
              );
            } else if (widget.attachment.downloadUrl != null &&
                widget.attachment.downloadUrl!.isNotEmpty) {
              bytes = await odooApiClient.fetchBytes(widget.attachment.downloadUrl!);
            } else if (widget.attachment.url != null &&
                widget.attachment.url!.isNotEmpty) {
              bytes = await odooApiClient.fetchBytes(widget.attachment.url!);
            }
          }

          if (bytes != null && bytes.isNotEmpty) {
            _audioBytes = bytes;
            final lower = widget.attachment.name.toLowerCase();
            String mime = widget.attachment.mimetype ?? '';
            if (mime.isEmpty || mime == 'audio/m4a') {
              if (lower.endsWith('.webm')) {
                mime = 'audio/webm';
              } else if (lower.endsWith('.opus')) {
                mime = 'audio/opus';
              } else if (lower.endsWith('.wav')) {
                mime = 'audio/wav';
              } else if (lower.endsWith('.mp3')) {
                mime = 'audio/mpeg';
              } else {
                mime = kIsWeb ? 'audio/mp4' : 'audio/m4a';
              }
            }
            if (kIsWeb && (mime == 'audio/m4a' || mime.isEmpty)) {
              mime = 'audio/mp4';
            }

            // Thiết lập AudioContext chuẩn cho loa ngoài trên iOS & Android
            try {
              await _player.setAudioContext(AudioContext(
                iOS: AudioContextIOS(
                  category: AVAudioSessionCategory.playback,
                  options: const {
                    AVAudioSessionOptions.defaultToSpeaker,
                    AVAudioSessionOptions.mixWithOthers,
                  },
                ),
                android: const AudioContextAndroid(
                  isSpeakerphoneOn: true,
                  stayAwake: true,
                  contentType: AndroidContentType.music,
                  usageType: AndroidUsageType.media,
                  audioFocus: AndroidAudioFocus.gain,
                ),
              ));
            } catch (_) {}

            Source source;
            if (kIsWeb) {
              source = BytesSource(bytes, mimeType: mime);
            } else {
              final tempDir = await getTemporaryDirectory();
              final ext = lower.endsWith('.webm')
                  ? 'webm'
                  : (lower.endsWith('.wav') ? 'wav' : (lower.endsWith('.opus') ? 'opus' : 'm4a'));
              final cleanId = widget.attachment.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
              final tempFile = File('${tempDir.path}/voice_${cleanId}_${DateTime.now().millisecondsSinceEpoch}.$ext');
              await tempFile.writeAsBytes(bytes, flush: true);
              source = DeviceFileSource(tempFile.path);
            }

            await _player.play(source);
          } else {
            debugPrint('Không thể tải dữ liệu âm thanh: ${widget.attachment.name}');
          }
        } else {
          await _player.resume();
        }
      }
    } catch (e) {
      debugPrint('Lỗi phát âm thanh: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const primaryColor = Color(0xFF00C83A);
    final iconBgColor = widget.isMine
        ? (isDark ? const Color(0xFF005C4B) : const Color(0xFF25D366))
        : (isDark ? const Color(0xFF202C33) : const Color(0xFF00C83A));

    final fgColor = widget.isMine
        ? (isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21))
        : (isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21));

    final subFgColor = fgColor.withValues(alpha: 0.65);

    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Nút Play / Pause tròn
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isPlaying ? LucideIcons.pause : LucideIcons.play,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
          const SizedBox(width: 8),

          // Slider & Thời gian
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3.5,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: primaryColor,
                    inactiveTrackColor: isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.15),
                    thumbColor: primaryColor,
                  ),
                  child: Slider(
                    value: _position.inMilliseconds.toDouble().clamp(
                          0.0,
                          _duration.inMilliseconds > 0
                              ? _duration.inMilliseconds.toDouble()
                              : 100.0,
                        ),
                    min: 0.0,
                    max: _duration.inMilliseconds > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 100.0,
                    onChanged: (value) {
                      _player.seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position > Duration.zero ? _position : _duration),
                        style: TextStyle(
                          fontSize: 11,
                          color: subFgColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!widget.isMine && _position == Duration.zero)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
