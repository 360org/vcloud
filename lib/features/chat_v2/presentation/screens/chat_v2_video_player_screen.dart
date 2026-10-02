import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/api/mobile_attachment_repository.dart';
import '../../../../core/api/odoo_api_client.dart';
import '../../../../core/utils/gallery_saver.dart';
import '../../../../core/utils/local_attachment_cache.dart';

/// Màn hình phát video In-App (Full In-App Video Player)
/// Hỗ trợ phát video trực tiếp từ URL Odoo (kèm auth headers) hoặc bytes bộ nhớ đệm
class ChatV2VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final Map<String, String>? headers;
  final Uint8List? bytes;
  final String? attachmentId;

  const ChatV2VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    this.title = 'Video',
    this.headers,
    this.bytes,
    this.attachmentId,
  });

  /// Chuyển cảnh mở trình phát video với hiệu ứng Fade mượt mà chuẩn Zalo/Telegram
  static Route<void> route({
    required String videoUrl,
    String title = 'Video',
    Map<String, String>? headers,
    Uint8List? bytes,
    String? attachmentId,
  }) {
    return PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ChatV2VideoPlayerScreen(
          videoUrl: videoUrl,
          title: title,
          headers: headers,
          bytes: bytes,
          attachmentId: attachmentId,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
          child: child,
        );
      },
    );
  }

  @override
  State<ChatV2VideoPlayerScreen> createState() => _ChatV2VideoPlayerScreenState();
}

class _ChatV2VideoPlayerScreenState extends State<ChatV2VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showControls = true;
  bool _isMuted = false;
  bool _isSaving = false;
  Uint8List? _cachedBytes;
  Timer? _hideControlsTimer;
  File? _tempFile;

  @override
  void initState() {
    super.initState();
    _cachedBytes = widget.bytes;
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Nếu có bytes từ trước (hoặc cache), ghi ra file tạm để phát mượt mà nhất
      if (_cachedBytes != null && _cachedBytes!.isNotEmpty && !kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        final ext = widget.title.contains('.') ? widget.title.split('.').last : 'mp4';
        final file = File(
          '${tempDir.path}/vcloud_video_${DateTime.now().millisecondsSinceEpoch}.$ext',
        );
        await file.writeAsBytes(_cachedBytes!);
        _tempFile = file;
        _controller = VideoPlayerController.file(file);
      } else {
        // 2. Thử khởi tạo từ network URL
        final uri = Uri.parse(widget.videoUrl);
        final authHeaders = widget.headers ?? odooApiClient.authHeaders;

        if (kIsWeb) {
          _controller = VideoPlayerController.networkUrl(uri);
        } else {
          // Trên native mobile, thử stream networkUrl có headers
          _controller = VideoPlayerController.networkUrl(
            uri,
            httpHeaders: authHeaders ?? const <String, String>{},
          );
        }
      }

      await _controller!.initialize();

      _controller!.addListener(_onPlayerStateChanged);
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
        // Tự động phát khi tải xong
        _controller!.play();
        _startHideControlsTimer();
      }
    } catch (e) {
      debugPrint('[ChatV2VideoPlayer] Network init failed: $e, trying download fallback...');

      // 3. Fallback: Nếu stream trực tiếp lỗi do auth/redirect, tải file về máy và phát offline
      if (!kIsWeb && mounted) {
        try {
          Uint8List? downloadedBytes = _cachedBytes;
          if (downloadedBytes == null || downloadedBytes.isEmpty) {
            final attId = int.tryParse(widget.attachmentId ?? '');
            if (attId != null && attId > 0) {
              downloadedBytes = await MobileAttachmentRepository().fetchBytes(attId);
            } else {
              downloadedBytes = await odooApiClient.fetchBytes(widget.videoUrl);
            }
          }

          if (downloadedBytes.isNotEmpty) {
            _cachedBytes = downloadedBytes;
            LocalAttachmentCache.save(widget.title, downloadedBytes);

            final tempDir = await getTemporaryDirectory();
            final ext = widget.title.contains('.') ? widget.title.split('.').last : 'mp4';
            final file = File(
              '${tempDir.path}/vcloud_video_${DateTime.now().millisecondsSinceEpoch}.$ext',
            );
            await file.writeAsBytes(downloadedBytes);
            _tempFile = file;

            _controller?.removeListener(_onPlayerStateChanged);
            await _controller?.dispose();

            _controller = VideoPlayerController.file(file);
            await _controller!.initialize();
            _controller!.addListener(_onPlayerStateChanged);

            if (mounted) {
              setState(() {
                _isInitialized = true;
                _isLoading = false;
                _errorMessage = null;
              });
              _controller!.play();
              _startHideControlsTimer();
              return;
            }
          }
        } catch (downloadErr) {
          debugPrint('[ChatV2VideoPlayer] Download fallback failed: $downloadErr');
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không thể phát video: ${e.toString()}';
        });
      }
    }
  }

  void _onPlayerStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    HapticFeedback.lightImpact();

    if (_controller!.value.isPlaying) {
      _controller!.pause();
      _cancelHideControlsTimer();
      setState(() => _showControls = true);
    } else {
      // Nếu video đã kết thúc, tua lại từ đầu
      if (_controller!.value.position >= _controller!.value.duration) {
        _controller!.seekTo(Duration.zero);
      }
      _controller!.play();
      _startHideControlsTimer();
    }
  }

  void _toggleMute() {
    if (_controller == null || !_isInitialized) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _toggleControlsVisibility() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls && (_controller?.value.isPlaying ?? false)) {
      _startHideControlsTimer();
    } else {
      _cancelHideControlsTimer();
    }
  }

  void _startHideControlsTimer() {
    _cancelHideControlsTimer();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _showControls = false);
      }
    });
  }

  void _cancelHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = null;
  }

  Future<void> _handleSaveVideo() async {
    if (_isSaving) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);

    try {
      Uint8List? bytes = _cachedBytes;

      if (bytes == null || bytes.isEmpty) {
        final attId = int.tryParse(widget.attachmentId ?? '');
        if (attId != null && attId > 0) {
          bytes = await MobileAttachmentRepository().fetchBytes(attId);
        } else {
          bytes = await odooApiClient.fetchBytes(widget.videoUrl);
        }
      }

      if (bytes.isEmpty) {
        throw Exception('Không tìm thấy dữ liệu video để lưu');
      }

      _cachedBytes = bytes;
      final cleanName = widget.title.isNotEmpty ? widget.title : 'video.mp4';
      final ok = await GallerySaver.saveVideo(
        bytes: bytes,
        fileName: cleanName,
      );

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(ok ? 'Đã lưu video vào Thư viện ảnh' : 'Lưu video thất bại'),
            backgroundColor: ok ? const Color(0xFF00C83A) : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Lỗi tải video: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString();
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _cancelHideControlsTimer();
    _controller?.removeListener(_onPlayerStateChanged);
    _controller?.dispose();
    try {
      _tempFile?.deleteSync();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = _controller?.value.position ?? Duration.zero;
    final duration = _controller?.value.duration ?? Duration.zero;
    final isPlaying = _controller?.value.isPlaying ?? false;
    final isEnded = duration > Duration.zero && position >= duration;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: GestureDetector(
          onTap: _toggleControlsVisibility,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Trình phát Video
              Center(
                child: _isInitialized && _controller != null
                    ? AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio > 0
                            ? _controller!.value.aspectRatio
                            : 16 / 9,
                        child: VideoPlayer(_controller!),
                      )
                    : const SizedBox.shrink(),
              ),

              // 2. Loading Indicator
              if (_isLoading)
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C83A)),
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Đang tải video...',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              // 3. Error State
              if (_errorMessage != null && !_isLoading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.alertCircle,
                          color: Colors.redAccent,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _initializePlayer,
                          icon: const Icon(LucideIcons.rotateCw, size: 18),
                          label: const Text('Thử lại'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C83A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 4. Center Play/Pause/Replay Overlay Button
              if (_isInitialized && _showControls && !_isLoading)
                Center(
                  child: GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isEnded
                            ? LucideIcons.rotateCcw
                            : (isPlaying ? LucideIcons.pause : LucideIcons.play),
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),

              // 5. Top Bar: Back button, Title, Action Buttons
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                top: _showControls ? 0 : -100,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                            onPressed: () => Navigator.of(context).maybePop(),
                            tooltip: 'Đóng',
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Nút Mute/Unmute
                          if (_isInitialized)
                            IconButton(
                              icon: Icon(
                                _isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                                color: Colors.white,
                              ),
                              onPressed: _toggleMute,
                              tooltip: _isMuted ? 'Bật âm thanh' : 'Tắt âm thanh',
                            ),
                          // Nút Lưu/Tải video
                          IconButton(
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(LucideIcons.download, color: Colors.white),
                            onPressed: _isSaving ? null : _handleSaveVideo,
                            tooltip: 'Lưu vào máy',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 6. Bottom Bar: Progress Seekbar, Duration timer
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                bottom: _showControls ? 0 : -120,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isInitialized && _controller != null) ...[
                            // Slider / Progress Seekbar
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 14,
                                ),
                                activeTrackColor: const Color(0xFF00C83A),
                                inactiveTrackColor: Colors.white24,
                                thumbColor: const Color(0xFF00C83A),
                                overlayColor: const Color(0xFF00C83A).withValues(alpha: 0.2),
                              ),
                              child: Slider(
                                value: position.inMilliseconds
                                    .toDouble()
                                    .clamp(0.0, duration.inMilliseconds.toDouble()),
                                min: 0.0,
                                max: duration.inMilliseconds.toDouble() > 0
                                    ? duration.inMilliseconds.toDouble()
                                    : 1.0,
                                onChangeStart: (_) {
                                  _cancelHideControlsTimer();
                                },
                                onChanged: (value) {
                                  setState(() {});
                                },
                                onChangeEnd: (value) {
                                  _controller?.seekTo(
                                    Duration(milliseconds: value.toInt()),
                                  );
                                  if (isPlaying) {
                                    _startHideControlsTimer();
                                  }
                                },
                              ),
                            ),
                            // Timer labels
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
