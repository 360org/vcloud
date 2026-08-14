import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/core/api/mobile_attachment_repository.dart';
import 'package:vcloud/core/theme/app_theme.dart';
import 'package:vcloud/core/utils/local_attachment_cache.dart';
import 'package:vcloud/shared/widgets/ui_kit.dart';

import 'chat_helpers.dart';
import 'chat_sheets.dart';
import 'chat_wallpaper.dart';

class ComposerCircleButton extends StatelessWidget {
  const ComposerCircleButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Tooltip(
      message: tooltip,
      child: PressableScale(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceElevated.withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.62),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? context.borderColor
                      : Colors.white.withValues(alpha: 0.72),
                ),
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(15),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(icon, color: context.textColor, size: 27),
            ),
          ),
        ),
      ),
    );
  }
}

class ComposerWithAttachments extends StatefulWidget {
  const ComposerWithAttachments({
    super.key,
    required this.controller,
    required this.sending,
    required this.onSubmit,
    required this.onAttachment,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSubmit;
  final Future<void> Function(MobileAttachmentUpload attachment) onAttachment;

  @override
  State<ComposerWithAttachments> createState() =>
      _ComposerWithAttachmentsState();
}

class _ComposerWithAttachmentsState extends State<ComposerWithAttachments> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1400,
        maxHeight: 1400,
      );
      if (!context.mounted || image == null) return;
      final bytes = await image.readAsBytes();
      if (!context.mounted) return;
      LocalAttachmentCache.save(image.name, bytes);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => ImagePreviewSheet(
          filename: image.name,
          bytes: bytes,
          mimetype: mimetypeForName(image.name) ?? 'image/jpeg',
          onSend: (upload, caption) async {
            Navigator.pop(sheetContext);
            if (caption != null && caption.trim().isNotEmpty) {
              widget.controller.text = caption.trim();
              widget.onSubmit();
            }
            await widget.onAttachment(upload);
          },
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không mở được camera/gallery: $e')),
      );
    }
  }

  Future<void> _pickDocument(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const <String>[
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'txt',
          'png',
          'jpg',
          'jpeg',
        ],
      );
      final file = result?.files.single;
      if (!context.mounted || file == null) return;
      final bytes = file.bytes;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không đọc được nội dung tài liệu.')),
        );
        return;
      }
      LocalAttachmentCache.save(file.name, bytes);
      await widget.onAttachment(
        MobileAttachmentUpload(
          filename: file.name,
          bytes: bytes,
          mimetype: mimetypeForName(file.name),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không mở được tài liệu: $e')));
    }
  }

  void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label sắp có')));
  }

  void _openAttachmentSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => AttachmentPickerSheet(
        onSelected: (action) async {
          Navigator.pop(sheetContext);
          switch (action.type) {
            case AttachmentType.gallery:
              await _pickImage(context, ImageSource.gallery);
            case AttachmentType.camera:
              await _pickImage(context, ImageSource.camera);
            case AttachmentType.document:
              await _pickDocument(context);
            case AttachmentType.poll:
              _openPollSheet(context);
            case AttachmentType.location:
              _showComingSoon(context, 'Vị trí');
            case AttachmentType.contact:
              _showComingSoon(context, 'Liên hệ');
          }
        },
      ),
    );
  }

  void _openPollSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PollSheet(
        onCreated: (question, options, isMultiple, isAnonymous) {
          _sendPollMessage(question, options, isMultiple, isAnonymous);
        },
      ),
    );
  }

  void _sendPollMessage(
    String question,
    List<String> options,
    bool isMultiple,
    bool isAnonymous,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('📊 BÌNH CHỌN: $question');
    final settings = <String>[];
    if (isMultiple) settings.add('Nhiều đáp án');
    if (isAnonymous) settings.add('Ẩn danh');
    if (settings.isNotEmpty) {
      buffer.writeln('(${settings.join(' • ')})');
    }
    buffer.writeln();

    final numberEmojis = ['1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣', '6️⃣', '7️⃣', '8️⃣'];
    for (var i = 0; i < options.length; i++) {
      final emoji = i < numberEmojis.length ? numberEmojis[i] : '${i + 1}.';
      buffer.writeln('$emoji ${options[i]}');
    }

    widget.controller.text = buffer.toString();
    widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (context.isDarkMode ? AppColors.darkBg : Colors.white).withValues(alpha: 0),
            (context.isDarkMode ? AppColors.darkBg : Colors.white).withValues(alpha: 0.34),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ComposerCircleButton(
              tooltip: 'Thêm nội dung',
              icon: LucideIcons.plus,
              onTap: () => _openAttachmentSheet(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FrostedSurface(
                radius: 26,
                isFocused: _focusNode.hasFocus,
                child: TextField(
                  focusNode: _focusNode,
                  controller: widget.controller,
                  enabled: !widget.sending,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => widget.onSubmit(),
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Nhập tin nhắn...',
                    hintStyle: TextStyle(
                      color: context.textSecondary.withValues(alpha: 0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Biểu tượng',
                      onPressed: () {},
                      icon: const Icon(LucideIcons.smile, size: 23),
                      color: context.textSecondary,
                    ),
                    filled: false,
                    contentPadding: const EdgeInsets.fromLTRB(18, 12, 6, 12),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                final hasText = widget.controller.text.trim().isNotEmpty;
                if (!hasText) return const SizedBox.shrink();
                return ComposerCircleButton(
                  tooltip: 'Gửi',
                  icon: LucideIcons.send,
                  loading: widget.sending,
                  onTap: widget.sending ? null : widget.onSubmit,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
