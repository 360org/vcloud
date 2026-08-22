import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'chat_v2_create_poll_sheet.dart';

class ChatV2InputBar extends StatefulWidget {
  const ChatV2InputBar({
    super.key,
    required this.onSend,
    this.onSendImage,
    this.onSendFile,
    this.onTyping,
    this.onCreatePoll,
    this.channelId,
    this.isSending = false,
    this.controller,
    this.focusNode,
  });

  final String? channelId;
  final VoidCallback? onCreatePoll;
  final Future<void> Function(String text) onSend;
  final Future<void> Function({
    required Uint8List bytes,
    required String filename,
    String? mimetype,
    String? caption,
  })? onSendImage;
  final Future<void> Function({
    required Uint8List bytes,
    required String filename,
    String? mimetype,
    String? caption,
  })? onSendFile;
  final void Function(bool isTyping)? onTyping;
  final bool isSending;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  @override
  State<ChatV2InputBar> createState() => _ChatV2InputBarState();
}

class _ChatV2InputBarState extends State<ChatV2InputBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final ImagePicker _picker = ImagePicker();
  bool _hasText = false;
  bool _isUploading = false;
  bool _isFocused = false;

  Uint8List? _selectedBytes;
  String? _selectedFilename;
  String? _selectedMimetype;
  bool _isSelectedImage = false;
  Timer? _typingDebounce;
  bool _isTyping = false;

  // Voice recording state
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isRecordCancelled = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  String? _recordPath;
  AudioEncoder _currentEncoder = AudioEncoder.aacLc;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted && _isFocused != _focusNode.hasFocus) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  void _onTextChanged() {
    final hasContent = _controller.text.trim().isNotEmpty;
    if (_hasText != hasContent) {
      setState(() => _hasText = hasContent);
    }
    if (widget.onTyping != null) {
      if (!_isTyping) {
        _isTyping = true;
        widget.onTyping!(true);
      }
      _typingDebounce?.cancel();
      _typingDebounce = Timer(const Duration(seconds: 2), () {
        _isTyping = false;
        widget.onTyping!(false);
      });
    }
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;
    try {
      final hasPerm = await _audioRecorder.hasPermission();
      if (!hasPerm) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng cấp quyền Micro trên trình duyệt/thiết bị để ghi âm'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      String? savePath;
      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        savePath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _recordPath = savePath;
      }

      // Tự động nhận diện encoder tương thích với platform
      AudioEncoder encoder = AudioEncoder.aacLc;
      if (kIsWeb) {
        if (await _audioRecorder.isEncoderSupported(AudioEncoder.opus)) {
          encoder = AudioEncoder.opus;
        } else if (await _audioRecorder.isEncoderSupported(AudioEncoder.wav)) {
          encoder = AudioEncoder.wav;
        }
      } else {
        if (!await _audioRecorder.isEncoderSupported(AudioEncoder.aacLc)) {
          if (await _audioRecorder.isEncoderSupported(AudioEncoder.opus)) {
            encoder = AudioEncoder.opus;
          }
        }
      }
      _currentEncoder = encoder;

      HapticFeedback.lightImpact();

      await _audioRecorder.start(
        RecordConfig(encoder: encoder),
        path: savePath ?? '',
      );

      setState(() {
        _isRecording = true;
        _isRecordCancelled = false;
        _recordDuration = Duration.zero;
      });

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _recordDuration += const Duration(seconds: 1));
        }
      });
    } catch (e) {
      debugPrint('Error starting record: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể bắt đầu ghi âm: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      if (!kIsWeb && path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    } catch (e) {
      debugPrint('Error cancelling record: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isRecordCancelled = false;
          _recordDuration = Duration.zero;
        });
      }
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();

    try {
      final path = await _audioRecorder.stop();
      final wasCancelled = _isRecordCancelled;

      setState(() {
        _isRecording = false;
        _isRecordCancelled = false;
        _recordDuration = Duration.zero;
      });

      if (wasCancelled || path == null || path.isEmpty) {
        if (!kIsWeb && path != null) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
        return;
      }

      Uint8List? bytes;
      String ext = 'm4a';
      String mime = 'audio/m4a';

      if (_currentEncoder == AudioEncoder.opus) {
        ext = kIsWeb ? 'webm' : 'opus';
        mime = kIsWeb ? 'audio/webm' : 'audio/opus';
      } else if (_currentEncoder == AudioEncoder.wav) {
        ext = 'wav';
        mime = 'audio/wav';
      }

      final filename = 'voice_${DateTime.now().millisecondsSinceEpoch}.$ext';

      if (kIsWeb) {
        final res = await http.get(Uri.parse(path));
        bytes = res.bodyBytes;
      } else {
        final file = File(path);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
          await file.delete();
        }
      }

      if (bytes != null && bytes.isNotEmpty && widget.onSendFile != null) {
        setState(() => _isUploading = true);
        await widget.onSendFile!(
          bytes: bytes,
          filename: filename,
          mimetype: mime,
        );
        setState(() => _isUploading = false);
      }
    } catch (e) {
      debugPrint('Error stopping record: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _handleSend() async {
    if (widget.isSending || _isUploading) return;

    final text = _controller.text.trim();

    // Nếu có tệp/ảnh đang được chọn -> gửi tệp kèm caption
    if (_selectedBytes != null) {
      final bytes = _selectedBytes!;
      final filename = _selectedFilename ??
          (_isSelectedImage
              ? 'image_${DateTime.now().millisecondsSinceEpoch}.jpg'
              : 'file_${DateTime.now().millisecondsSinceEpoch}');
      final mime = _selectedMimetype ??
          (_isSelectedImage ? 'image/jpeg' : 'application/octet-stream');
      final isImage = _isSelectedImage;
      final caption = text.isNotEmpty ? text : null;

      setState(() {
        _selectedBytes = null;
        _selectedFilename = null;
        _selectedMimetype = null;
        _isSelectedImage = false;
        _isUploading = true;
      });

      _controller.clear();
      setState(() {
        _hasText = false;
        _isUploading = false;
      });

      try {
        if (isImage && widget.onSendImage != null) {
          await widget.onSendImage!(
            bytes: bytes,
            filename: filename,
            mimetype: mime,
            caption: caption,
          );
        } else if (widget.onSendFile != null) {
          await widget.onSendFile!(
            bytes: bytes,
            filename: filename,
            mimetype: mime,
            caption: caption,
          );
        } else if (widget.onSendImage != null) {
          await widget.onSendImage!(
            bytes: bytes,
            filename: filename,
            mimetype: mime,
            caption: caption,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi gửi đính kèm: $e')),
          );
        }
      }
      return;
    }

    // Nếu chỉ có văn bản
    if (text.isEmpty) return;

    _controller.clear();
    setState(() => _hasText = false);
    await widget.onSend(text);
  }

  Future<void> _handlePickImage(ImageSource source) async {
    if (widget.isSending || _isUploading) return;

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      final filename = file.name.isNotEmpty
          ? file.name
          : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final mime = file.mimeType ?? 'image/jpeg';

      setState(() {
        _selectedBytes = bytes;
        _selectedFilename = filename;
        _selectedMimetype = mime;
        _isSelectedImage = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chọn ảnh: $e')),
        );
      }
    }
  }

  Future<void> _handlePickFile() async {
    if (widget.isSending || _isUploading) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể đọc dữ liệu tệp')),
          );
        }
        return;
      }

      final ext = file.extension?.toLowerCase();
      final isImg = ext == 'png' ||
          ext == 'jpg' ||
          ext == 'jpeg' ||
          ext == 'webp' ||
          ext == 'bmp' ||
          ext == 'ico' ||
          ext == 'heic' ||
          ext == 'heif';

      Uint8List finalBytes = bytes;
      String finalFilename = file.name;
      String finalMime = _guessMimeType(ext);

      if (isImg) {
        try {
          final compressed = await FlutterImageCompress.compressWithList(
            bytes,
            minWidth: 1600,
            minHeight: 1600,
            quality: 85,
            format: CompressFormat.jpeg,
          );
          if (compressed.isNotEmpty) {
            finalBytes = compressed;
          }
        } catch (_) {
          // Fallback to original bytes if compression fails
        }

        // Chuẩn hóa tên file sang đuôi .jpg và MIME image/jpeg
        final dotIndex = finalFilename.lastIndexOf('.');
        final baseName = dotIndex != -1 ? finalFilename.substring(0, dotIndex) : finalFilename;
        finalFilename = '$baseName.jpg';
        finalMime = 'image/jpeg';
      }

      setState(() {
        _selectedBytes = finalBytes;
        _selectedFilename = finalFilename;
        _selectedMimetype = finalMime;
        _isSelectedImage = isImg;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi chọn tệp: $e')),
        );
      }
    }
  }

  String _guessMimeType(String? ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'svg':
        return 'image/svg+xml';
      case 'bmp':
        return 'image/bmp';
      case 'ico':
        return 'image/x-icon';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _handleShareLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Vui lòng bật dịch vụ định vị (GPS) trên thiết bị của bạn.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Quyền truy cập vị trí bị từ chối.'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          showDialog<void>(
            context: context,
            builder: (dCtx) => AlertDialog(
              title: const Text('Quyền truy cập vị trí'),
              content: const Text(
                'Ứng dụng cần quyền vị trí để gửi tọa độ bản đồ trong chat. Vui lòng mở Cài đặt để cấp quyền.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: const Text('Đóng'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dCtx);
                    Geolocator.openAppSettings();
                  },
                  child: const Text('Mở Cài đặt'),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Đang lấy vị trí GPS hiện tại...'),
              ],
            ),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final lat = position.latitude;
      final lng = position.longitude;
      final locationMsg = '📍 Vị trí: https://maps.google.com/?q=$lat,$lng';

      await widget.onSend(locationMsg);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Không thể lấy vị trí: $e'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showAttachmentMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 12,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle pill
              Container(
                width: 38,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAttachmentActionButton(
                      icon: LucideIcons.image,
                      gradientColors: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                      label: 'Thư viện',
                      onTap: () {
                        Navigator.pop(ctx);
                        _handlePickImage(ImageSource.gallery);
                      },
                      isDark: isDark,
                    ),
                    _buildAttachmentActionButton(
                      icon: LucideIcons.camera,
                      gradientColors: const [Color(0xFFF43F5E), Color(0xFFE11D48)],
                      label: 'Máy ảnh',
                      onTap: () {
                        Navigator.pop(ctx);
                        _handlePickImage(ImageSource.camera);
                      },
                      isDark: isDark,
                    ),
                    _buildAttachmentActionButton(
                      icon: LucideIcons.fileText,
                      gradientColors: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      label: 'Tài liệu',
                      onTap: () {
                        Navigator.pop(ctx);
                        _handlePickFile();
                      },
                      isDark: isDark,
                    ),
                    _buildAttachmentActionButton(
                      icon: LucideIcons.barChart2,
                      gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
                      label: 'Bình chọn',
                      onTap: () {
                        Navigator.pop(ctx);
                        if (widget.onCreatePoll != null) {
                          widget.onCreatePoll!();
                        } else if (widget.channelId != null) {
                          ChatV2CreatePollSheet.show(context, widget.channelId!);
                        }
                      },
                      isDark: isDark,
                    ),
                    _buildAttachmentActionButton(
                      icon: LucideIcons.mapPin,
                      gradientColors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                      label: 'Vị trí',
                      onTap: () {
                        Navigator.pop(ctx);
                        _handleShareLocation();
                      },
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentActionButton({
    required IconData icon,
    required List<Color> gradientColors,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBusy = widget.isSending || _isUploading;
    final canSend = (_hasText || _selectedBytes != null) && !isBusy;
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final viewPaddingBottom = MediaQuery.of(context).padding.bottom;
    final bottomInset = viewInsetsBottom > 0
        ? 8.0
        : (viewPaddingBottom > 0 ? viewPaddingBottom + 4 : 12.0);

    return Container(
      width: double.infinity,
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 6, 8, bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Preview tệp/ảnh trước khi gửi nếu có tệp được chọn
                  if (_selectedBytes != null) ...[
                    Container(
                      margin: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F2C34) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          if (_isSelectedImage)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                _selectedBytes!,
                                width: 46,
                                height: 46,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                LucideIcons.fileText,
                                color: Colors.orange,
                                size: 24,
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _selectedFilename ??
                                      (_isSelectedImage ? 'Hình ảnh' : 'Tệp tin'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${(_selectedBytes!.length / 1024).toStringAsFixed(1)} KB',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Material(
                            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () {
                                setState(() {
                                  _selectedBytes = null;
                                  _selectedFilename = null;
                                  _selectedMimetype = null;
                                  _isSelectedImage = false;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  LucideIcons.x,
                                  size: 16,
                                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. Khung soạn thảo WhatsApp Input Pill (Chứa Kẹp giấy + TextField)
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 46, maxHeight: 120),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1F2C34)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Nút Đính kèm bên trong khung
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                  icon: _isUploading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF00C83A),
                                          ),
                                        )
                                      : Icon(
                                          LucideIcons.paperclip,
                                          size: 21,
                                          color: isDark
                                              ? const Color(0xFF8696A0)
                                              : const Color(0xFF54656F),
                                        ),
                                  onPressed: isBusy ? null : _showAttachmentMenu,
                                  tooltip: 'Đính kèm',
                                  splashRadius: 20,
                                ),
                              ),
                              // TextField or Recording UI
                              Expanded(
                                child: _isRecording
                                    ? Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        child: Row(
                                          children: [
                                            // Nút Hủy thu âm
                                            IconButton(
                                              icon: const Icon(LucideIcons.trash2, color: Color(0xFFEF4444), size: 20),
                                              tooltip: 'Hủy ghi âm',
                                              onPressed: _cancelRecording,
                                            ),
                                            const SizedBox(width: 4),
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFEF4444),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${_recordDuration.inMinutes.toString().padLeft(2, '0')}:${(_recordDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.white : Colors.black,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              _isRecordCancelled ? 'Thả tay để hủy' : 'Đang ghi âm...',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: _isRecordCancelled ? const Color(0xFFEF4444) : (isDark ? Colors.white54 : Colors.black54),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.only(left: 4, right: 14),
                                        child: TextField(
                                          controller: _controller,
                                    focusNode: _focusNode,
                                    textCapitalization: TextCapitalization.sentences,
                                    minLines: 1,
                                    maxLines: 5,
                                    textAlignVertical: TextAlignVertical.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.35,
                                      color: isDark
                                          ? const Color(0xFFE9EDEF)
                                          : const Color(0xFF111B21),
                                    ),
                                    cursorColor: const Color(0xFF00C83A),
                                    cursorWidth: 2.0,
                                    cursorRadius: const Radius.circular(2),
                                    decoration: InputDecoration(
                                      hintText: _selectedBytes != null
                                          ? 'Thêm chú thích...'
                                          : 'Nhập tin nhắn...',
                                      hintStyle: TextStyle(
                                        color: isDark
                                            ? const Color(0xFF8696A0)
                                            : const Color(0xFF8696A0),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      filled: false,
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    onSubmitted: (_) => _handleSend(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 2. Nút Gửi hoặc Ghi âm
                      GestureDetector(
                        onTap: () {
                          if (canSend) {
                            _handleSend();
                          } else if (_isRecording) {
                            _stopRecordingAndSend();
                          } else {
                            _startRecording();
                          }
                        },
                        onLongPressStart: canSend ? null : (_) => _startRecording(),
                        onLongPressMoveUpdate: canSend ? null : (details) {
                          if (details.localOffsetFromOrigin.dx < -60) {
                            if (!_isRecordCancelled) {
                              setState(() => _isRecordCancelled = true);
                              HapticFeedback.lightImpact();
                            }
                          } else {
                            if (_isRecordCancelled) {
                              setState(() => _isRecordCancelled = false);
                            }
                          }
                        },
                        onLongPressEnd: canSend ? null : (_) => _stopRecordingAndSend(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C83A),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00C83A).withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: isBusy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 150),
                                  transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                                  child: Icon(
                                    (_isRecording || canSend) ? LucideIcons.send : LucideIcons.mic,
                                    key: ValueKey('${_isRecording}_$canSend'),
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
