import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../application/video_player_provider.dart';

/// Màn hình phát video In-App (Full In-App Video Player)
/// Áp dụng mô hình Clean Architecture & Quản lý State tối ưu bằng Riverpod
class ChatV2VideoPlayerScreen extends StatelessWidget {
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

  ChatV2VideoPlayerArgs get args => ChatV2VideoPlayerArgs(
        videoUrl: videoUrl,
        title: title,
        headers: headers,
        bytes: bytes,
        attachmentId: attachmentId,
      );

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
  Widget build(BuildContext context) {
    final view = _ChatV2VideoPlayerView(args: args);

    // Tự động kiểm tra ProviderScope; bọc dự phòng khi chạy trong isolated unit/widget tests
    try {
      ProviderScope.containerOf(context, listen: false);
      return view;
    } catch (_) {
      return ProviderScope(child: view);
    }
  }
}

class _ChatV2VideoPlayerView extends ConsumerStatefulWidget {
  final ChatV2VideoPlayerArgs args;

  const _ChatV2VideoPlayerView({required this.args});

  @override
  ConsumerState<_ChatV2VideoPlayerView> createState() =>
      _ChatV2VideoPlayerViewState();
}

class _ChatV2VideoPlayerViewState
    extends ConsumerState<_ChatV2VideoPlayerView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(chatV2VideoPlayerProvider(widget.args).notifier).initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(chatV2VideoPlayerProvider(widget.args).notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: GestureDetector(
          onTap: notifier.toggleControlsVisibility,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Video Surface (Rebuild chỉ khi khởi tạo xong hoặc đổi tỷ lệ khung hình)
              _VideoSurface(args: widget.args),

              // 2. Loading Indicator (Rebuild chỉ khi trạng thái isLoading đổi)
              _VideoLoadingIndicator(args: widget.args),

              // 3. Error State (Rebuild chỉ khi có lỗi phát sinh)
              _VideoErrorIndicator(args: widget.args),

              // 4. Center Play/Pause Overlay (Tối ưu Rebuild qua .select)
              _CenterPlayOverlay(args: widget.args),

              // 5. Top Bar: Back, Title, Orientation, Mute, Save actions
              _TopBar(args: widget.args),

              // 6. Bottom Bar: Seekbar, Real-time Timer labels
              _BottomControlsBar(args: widget.args),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SUB-WIDGETS: ÁP DỤNG TRIỆT ĐỂ ref.watch(provider.select(...))
// =============================================================================

/// 1. Khung hiển thị Video
class _VideoSurface extends ConsumerWidget {
  final ChatV2VideoPlayerArgs args;

  const _VideoSurface({required this.args});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (isInitialized, aspectRatio) = ref.watch(
      chatV2VideoPlayerProvider(args).select(
        (s) => (s.isInitialized, s.aspectRatio),
      ),
    );

    if (!isInitialized) return const SizedBox.shrink();

    final controller =
        ref.read(chatV2VideoPlayerProvider(args).notifier).videoPlayerController;
    if (controller == null) return const SizedBox.shrink();

    return Center(
      child: AspectRatio(
        aspectRatio: aspectRatio > 0 ? aspectRatio : 16 / 9,
        child: VideoPlayer(controller),
      ),
    );
  }
}

/// 2. Chỉ báo tải Video
class _VideoLoadingIndicator extends ConsumerWidget {
  final ChatV2VideoPlayerArgs args;

  const _VideoLoadingIndicator({required this.args});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      chatV2VideoPlayerProvider(args).select((s) => s.isLoading),
    );

    if (!isLoading) return const SizedBox.shrink();

    return const Center(
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
    );
  }
}

/// 3. Báo lỗi phát Video
class _VideoErrorIndicator extends ConsumerWidget {
  final ChatV2VideoPlayerArgs args;

  const _VideoErrorIndicator({required this.args});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (isLoading, errorMessage) = ref.watch(
      chatV2VideoPlayerProvider(args).select(
        (s) => (s.isLoading, s.errorMessage),
      ),
    );

    if (isLoading || errorMessage == null) return const SizedBox.shrink();

    return Center(
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
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(chatV2VideoPlayerProvider(args).notifier).initialize();
              },
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
    );
  }
}

/// 4. Nút Play/Pause/Replay trung tâm
class _CenterPlayOverlay extends ConsumerWidget {
  final ChatV2VideoPlayerArgs args;

  const _CenterPlayOverlay({required this.args});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (isInitialized, showControls, isLoading, isPlaying, isEnded) =
        ref.watch(
      chatV2VideoPlayerProvider(args).select(
        (s) => (
          s.isInitialized,
          s.showControls,
          s.isLoading,
          s.isPlaying,
          s.isEnded,
        ),
      ),
    );

    if (!isInitialized || !showControls || isLoading) {
      return const SizedBox.shrink();
    }

    final notifier = ref.read(chatV2VideoPlayerProvider(args).notifier);

    return Center(
      child: GestureDetector(
        onTap: notifier.togglePlayPause,
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
    );
  }
}

/// 5. Thanh tác vụ phía trên (Top Bar)
class _TopBar extends ConsumerWidget {
  final ChatV2VideoPlayerArgs args;

  const _TopBar({required this.args});

  Future<void> _handleSave(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(chatV2VideoPlayerProvider(args).notifier);

    try {
      final ok = await notifier.saveVideo();
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              ok ? 'Đã lưu video vào Thư viện ảnh' : 'Lưu video thất bại',
            ),
            backgroundColor: ok ? const Color(0xFF00C83A) : Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Lỗi tải video: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (showControls, isInitialized, isMuted, isSaving, isLandscape) =
        ref.watch(
      chatV2VideoPlayerProvider(args).select(
        (s) => (
          s.showControls,
          s.isInitialized,
          s.isMuted,
          s.isSaving,
          s.isLandscape,
        ),
      ),
    );

    final notifier = ref.read(chatV2VideoPlayerProvider(args).notifier);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      top: showControls ? 0 : -100,
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
                    args.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Nút Xoay màn hình (UX Enhancement)
                if (isInitialized)
                  IconButton(
                    icon: Icon(
                      isLandscape ? LucideIcons.minimize2 : LucideIcons.maximize2,
                      color: Colors.white,
                    ),
                    onPressed: notifier.toggleOrientation,
                    tooltip: isLandscape ? 'Màn hình dọc' : 'Xoay toàn màn hình',
                  ),
                // Nút Mute/Unmute
                if (isInitialized)
                  IconButton(
                    icon: Icon(
                      isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                      color: Colors.white,
                    ),
                    onPressed: notifier.toggleMute,
                    tooltip: isMuted ? 'Bật âm thanh' : 'Tắt âm thanh',
                  ),
                // Nút Lưu/Tải video
                IconButton(
                  icon: isSaving
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
                  onPressed: isSaving ? null : () => _handleSave(context, ref),
                  tooltip: 'Lưu vào máy',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 6. Thanh điều khiển phía dưới (Bottom Bar & Seekbar)
class _BottomControlsBar extends ConsumerStatefulWidget {
  final ChatV2VideoPlayerArgs args;

  const _BottomControlsBar({required this.args});

  @override
  ConsumerState<_BottomControlsBar> createState() => _BottomControlsBarState();
}

class _BottomControlsBarState extends ConsumerState<_BottomControlsBar> {
  double? _dragValue;

  String _formatDuration(Duration duration) {
    final minutes =
        duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString();
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final (showControls, isInitialized, position, duration, isPlaying) =
        ref.watch(
      chatV2VideoPlayerProvider(widget.args).select(
        (s) => (
          s.showControls,
          s.isInitialized,
          s.position,
          s.duration,
          s.isPlaying,
        ),
      ),
    );

    if (!isInitialized) return const SizedBox.shrink();

    final notifier =
        ref.read(chatV2VideoPlayerProvider(widget.args).notifier);

    final currentMs = _dragValue ?? position.inMilliseconds.toDouble();
    final maxMs = duration.inMilliseconds.toDouble() > 0
        ? duration.inMilliseconds.toDouble()
        : 1.0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      bottom: showControls ? 0 : -120,
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
                    overlayColor:
                        const Color(0xFF00C83A).withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: currentMs.clamp(0.0, maxMs),
                    min: 0.0,
                    max: maxMs,
                    onChangeStart: (_) {
                      notifier.cancelHideControlsTimer();
                    },
                    onChanged: (value) {
                      setState(() {
                        _dragValue = value;
                      });
                    },
                    onChangeEnd: (value) {
                      setState(() {
                        _dragValue = null;
                      });
                      notifier.seekTo(Duration(milliseconds: value.toInt()));
                      if (isPlaying) {
                        notifier.startHideControlsTimer();
                      }
                    },
                  ),
                ),
                // Timer labels (00:15 / 02:30)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(
                          _dragValue != null
                              ? Duration(milliseconds: _dragValue!.toInt())
                              : position,
                        ),
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
            ),
          ),
        ),
      ),
    );
  }
}
