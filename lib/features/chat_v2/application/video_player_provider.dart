import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/api/mobile_attachment_repository.dart';
import '../../../../core/api/odoo_api_client.dart';
import '../../../../core/utils/gallery_saver.dart';
import '../../../../core/utils/local_attachment_cache.dart';

/// Tham số cấu hình cho phiên phát video (Family Parameter)
@immutable
class ChatV2VideoPlayerArgs {
  final String videoUrl;
  final String title;
  final Map<String, String>? headers;
  final Uint8List? bytes;
  final String? attachmentId;

  const ChatV2VideoPlayerArgs({
    required this.videoUrl,
    this.title = 'Video',
    this.headers,
    this.bytes,
    this.attachmentId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatV2VideoPlayerArgs &&
          runtimeType == other.runtimeType &&
          videoUrl == other.videoUrl &&
          title == other.title &&
          attachmentId == other.attachmentId;

  @override
  int get hashCode => Object.hash(videoUrl, title, attachmentId);
}

/// Trạng thái bất biến của trình phát video (Immutable Video Player State)
@immutable
class ChatV2VideoPlayerState {
  final bool isInitialized;
  final bool isLoading;
  final String? errorMessage;
  final bool isPlaying;
  final bool isMuted;
  final bool isSaving;
  final bool showControls;
  final Duration position;
  final Duration duration;
  final double aspectRatio;
  final bool isLandscape;

  const ChatV2VideoPlayerState({
    this.isInitialized = false,
    this.isLoading = true,
    this.errorMessage,
    this.isPlaying = false,
    this.isMuted = false,
    this.isSaving = false,
    this.showControls = true,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.aspectRatio = 16 / 9,
    this.isLandscape = false,
  });

  bool get isEnded => duration > Duration.zero && position >= duration;

  ChatV2VideoPlayerState copyWith({
    bool? isInitialized,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool? isPlaying,
    bool? isMuted,
    bool? isSaving,
    bool? showControls,
    Duration? position,
    Duration? duration,
    double? aspectRatio,
    bool? isLandscape,
  }) {
    return ChatV2VideoPlayerState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isPlaying: isPlaying ?? this.isPlaying,
      isMuted: isMuted ?? this.isMuted,
      isSaving: isSaving ?? this.isSaving,
      showControls: showControls ?? this.showControls,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      isLandscape: isLandscape ?? this.isLandscape,
    );
  }
}

/// Provider tự động giải phóng RAM khi thoát màn hình (AutoDispose Family)
final chatV2VideoPlayerProvider = StateNotifierProvider.autoDispose
    .family<ChatV2VideoController, ChatV2VideoPlayerState, ChatV2VideoPlayerArgs>(
  (ref, args) => ChatV2VideoController(args),
);

/// Controller điều khiển toàn bộ nghiệp vụ phát video theo Clean Architecture
class ChatV2VideoController extends StateNotifier<ChatV2VideoPlayerState> {
  final ChatV2VideoPlayerArgs args;

  VideoPlayerController? _controller;
  VideoPlayerController? get videoPlayerController => _controller;

  Uint8List? _cachedBytes;
  Timer? _hideControlsTimer;
  File? _tempFile;

  ChatV2VideoController(this.args)
      : super(const ChatV2VideoPlayerState()) {
    _cachedBytes = args.bytes;
  }

  /// Khởi tạo luồng phát video (Network URL kèm headers Odoo hoặc Local Temp File)
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // 1. Nếu có bytes từ trước (hoặc cache), ghi ra file tạm để phát mượt mà
      if (_cachedBytes != null && _cachedBytes!.isNotEmpty && !kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        final ext = args.title.contains('.') ? args.title.split('.').last : 'mp4';
        final file = File(
          '${tempDir.path}/vcloud_video_${DateTime.now().millisecondsSinceEpoch}.$ext',
        );
        await file.writeAsBytes(_cachedBytes!);
        _tempFile = file;
        _controller = VideoPlayerController.file(file);
      } else {
        // 2. Thử khởi tạo từ Network URL
        final uri = Uri.parse(args.videoUrl);
        final authHeaders = args.headers ?? odooApiClient.authHeaders;

        if (kIsWeb) {
          _controller = VideoPlayerController.networkUrl(uri);
        } else {
          _controller = VideoPlayerController.networkUrl(
            uri,
            httpHeaders: authHeaders ?? const <String, String>{},
          );
        }
      }

      await _controller!.initialize();
      _controller!.addListener(_onPlayerStateChanged);

      final val = _controller!.value;
      state = state.copyWith(
        isInitialized: true,
        isLoading: false,
        isPlaying: true,
        duration: val.duration,
        position: val.position,
        aspectRatio: val.aspectRatio > 0 ? val.aspectRatio : 16 / 9,
      );

      _controller!.play();
      startHideControlsTimer();
    } catch (e) {
      debugPrint('[ChatV2VideoPlayer] Network init failed: $e, trying download fallback...');

      // 3. Fallback: Nếu stream trực tiếp lỗi do auth/redirect, tải file về máy và phát offline
      if (!kIsWeb && mounted) {
        try {
          Uint8List? downloadedBytes = _cachedBytes;
          if (downloadedBytes == null || downloadedBytes.isEmpty) {
            final attId = int.tryParse(args.attachmentId ?? '');
            if (attId != null && attId > 0) {
              downloadedBytes = await MobileAttachmentRepository().fetchBytes(attId);
            } else {
              downloadedBytes = await odooApiClient.fetchBytes(args.videoUrl);
            }
          }

          if (downloadedBytes.isNotEmpty) {
            _cachedBytes = downloadedBytes;
            LocalAttachmentCache.save(args.title, downloadedBytes);

            final tempDir = await getTemporaryDirectory();
            final ext = args.title.contains('.') ? args.title.split('.').last : 'mp4';
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

            final val = _controller!.value;
            state = state.copyWith(
              isInitialized: true,
              isLoading: false,
              clearError: true,
              isPlaying: true,
              duration: val.duration,
              position: val.position,
              aspectRatio: val.aspectRatio > 0 ? val.aspectRatio : 16 / 9,
            );

            _controller!.play();
            startHideControlsTimer();
            return;
          }
        } catch (downloadErr) {
          debugPrint('[ChatV2VideoPlayer] Download fallback failed: $downloadErr');
        }
      }

      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Không thể phát video: ${e.toString()}',
        );
      }
    }
  }

  void _onPlayerStateChanged() {
    if (!mounted || _controller == null) return;
    final val = _controller!.value;
    state = state.copyWith(
      isPlaying: val.isPlaying,
      position: val.position,
      duration: val.duration,
      aspectRatio: val.aspectRatio > 0 ? val.aspectRatio : state.aspectRatio,
    );
  }

  /// Bật / Tạm dừng phát video
  void togglePlayPause() {
    if (_controller == null || !state.isInitialized) return;
    HapticFeedback.lightImpact();

    if (_controller!.value.isPlaying) {
      _controller!.pause();
      cancelHideControlsTimer();
      state = state.copyWith(isPlaying: false, showControls: true);
    } else {
      if (_controller!.value.position >= _controller!.value.duration) {
        _controller!.seekTo(Duration.zero);
      }
      _controller!.play();
      state = state.copyWith(isPlaying: true);
      startHideControlsTimer();
    }
  }

  /// Bật / Tắt âm thanh
  void toggleMute() {
    if (_controller == null || !state.isInitialized) return;
    HapticFeedback.lightImpact();
    final newMuted = !state.isMuted;
    _controller!.setVolume(newMuted ? 0.0 : 1.0);
    state = state.copyWith(isMuted: newMuted);
  }

  /// Tua đến vị trí cụ thể
  void seekTo(Duration target) {
    if (_controller == null || !state.isInitialized) return;
    _controller!.seekTo(target);
    state = state.copyWith(position: target);
  }

  /// Ẩn / Hiện thanh điều khiển
  void toggleControlsVisibility() {
    final nextShow = !state.showControls;
    state = state.copyWith(showControls: nextShow);

    if (nextShow && (_controller?.value.isPlaying ?? false)) {
      startHideControlsTimer();
    } else {
      cancelHideControlsTimer();
    }
  }

  /// Bắt đầu bộ đếm tự động ẩn điều khiển sau 4 giây
  void startHideControlsTimer() {
    cancelHideControlsTimer();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        state = state.copyWith(showControls: false);
      }
    });
  }

  /// Hủy bộ đếm ẩn điều khiển
  void cancelHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = null;
  }

  /// Xoay ngang / dọc màn hình (UX Enhancement: Orientation Toggle)
  Future<void> toggleOrientation() async {
    final nextLandscape = !state.isLandscape;
    state = state.copyWith(isLandscape: nextLandscape);
    HapticFeedback.lightImpact();

    if (nextLandscape) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  /// Lưu video vào thư viện thiết bị
  Future<bool> saveVideo() async {
    if (state.isSaving) return false;
    state = state.copyWith(isSaving: true);

    try {
      Uint8List? bytes = _cachedBytes;

      if (bytes == null || bytes.isEmpty) {
        final attId = int.tryParse(args.attachmentId ?? '');
        if (attId != null && attId > 0) {
          bytes = await MobileAttachmentRepository().fetchBytes(attId);
        } else {
          bytes = await odooApiClient.fetchBytes(args.videoUrl);
        }
      }

      if (bytes.isEmpty) {
        throw Exception('Không tìm thấy dữ liệu video để lưu');
      }

      _cachedBytes = bytes;
      final cleanName = args.title.isNotEmpty ? args.title : 'video.mp4';
      final ok = await GallerySaver.saveVideo(
        bytes: bytes,
        fileName: cleanName,
      );
      return ok;
    } finally {
      if (mounted) {
        state = state.copyWith(isSaving: false);
      }
    }
  }

  @override
  void dispose() {
    cancelHideControlsTimer();
    _controller?.removeListener(_onPlayerStateChanged);
    _controller?.dispose();

    // Khôi phục chiều xoay màn hình mặc định
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    try {
      _tempFile?.deleteSync();
    } catch (_) {}

    super.dispose();
  }
}
