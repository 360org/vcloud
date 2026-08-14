import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/theme/app_theme.dart';

class ChatV2InputBar extends StatefulWidget {
  const ChatV2InputBar({
    super.key,
    required this.onSend,
    this.onSendImage,
    this.isSending = false,
  });

  final Future<void> Function(String text) onSend;
  final Future<void> Function({
    required Uint8List bytes,
    required String filename,
    String? mimetype,
    String? caption,
  })? onSendImage;
  final bool isSending;

  @override
  State<ChatV2InputBar> createState() => _ChatV2InputBarState();
}

class _ChatV2InputBarState extends State<ChatV2InputBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final ImagePicker _picker = ImagePicker();
  bool _hasText = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasContent = _controller.text.trim().isNotEmpty;
    if (_hasText != hasContent) {
      setState(() => _hasText = hasContent);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isSending || _isUploadingImage) return;

    _controller.clear();
    setState(() => _hasText = false);
    await widget.onSend(text);
  }

  Future<void> _handlePickImage(ImageSource source) async {
    if (widget.onSendImage == null || widget.isSending || _isUploadingImage) return;

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (file == null) return;

      setState(() => _isUploadingImage = true);

      final bytes = await file.readAsBytes();
      final filename = file.name.isNotEmpty ? file.name : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final mime = file.mimeType ?? 'image/jpeg';
      final caption = _controller.text.trim().isNotEmpty ? _controller.text.trim() : null;

      if (caption != null) {
        _controller.clear();
        setState(() => _hasText = false);
      }

      await widget.onSendImage!(
        bytes: bytes,
        filename: filename,
        mimetype: mime,
        caption: caption,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải ảnh: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _showImageSourceMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(LucideIcons.image, color: AppColors.primary),
                title: const Text('Thư viện ảnh'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handlePickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.camera, color: AppColors.primary),
                title: const Text('Chụp ảnh'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handlePickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBusy = widget.isSending || _isUploadingImage;

    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 12,
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE5E5EA),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Nút chọn ảnh
          IconButton(
            icon: _isUploadingImage
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    LucideIcons.image,
                    size: 22,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  ),
            onPressed: isBusy ? null : _showImageSourceMenu,
            tooltip: 'Gửi hình ảnh',
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black,
                ),
                decoration: const InputDecoration(
                  hintText: 'Nhập tin nhắn...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: (_hasText && !isBusy) ? _handleSend : null,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _hasText
                    ? AppColors.primary
                    : isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFE5E5EA),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      LucideIcons.send,
                      size: 18,
                      color: _hasText ? Colors.white : Colors.grey,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
