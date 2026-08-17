import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ChatV2InputBar extends StatefulWidget {
  const ChatV2InputBar({
    super.key,
    required this.onSend,
    this.onSendImage,
    this.onSendFile,
    this.onTyping,
    this.isSending = false,
    this.controller,
    this.focusNode,
  });

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
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle pill
              Container(
                width: 38,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Row(
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
                ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
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
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
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
                              // TextField
                              Expanded(
                                child: Padding(
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
                      // 2. Nút Gửi WhatsApp (Floating Action Button tròn xanh lá)
                      GestureDetector(
                        onTap: canSend ? _handleSend : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: canSend
                                ? const Color(0xFF00C83A)
                                : (isDark
                                    ? const Color(0xFF1F2C34)
                                    : const Color(0xFF00C83A).withValues(alpha: 0.45)),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (canSend ? const Color(0xFF00C83A) : Colors.black)
                                    .withValues(alpha: canSend ? 0.35 : 0.08),
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
                              : const Icon(
                                  LucideIcons.send,
                                  size: 20,
                                  color: Colors.white,
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
