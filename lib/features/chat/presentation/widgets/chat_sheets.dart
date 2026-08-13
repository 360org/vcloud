import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/core/api/mobile_attachment_repository.dart';
import 'package:vcloud/core/theme/app_theme.dart';
import 'package:vcloud/core/utils/file_download.dart';
import 'package:vcloud/shared/widgets/ui_kit.dart';

import 'chat_helpers.dart';

enum AttachmentType { gallery, camera, document, poll, location, contact }

class AttachmentAction {
  const AttachmentAction({
    required this.type,
    required this.label,
    required this.icon,
  });

  final AttachmentType type;
  final String label;
  final IconData icon;
}

class PollSheet extends StatefulWidget {
  const PollSheet({super.key, this.onCreated});

  final void Function(
    String question,
    List<String> options,
    bool isMultiple,
    bool isAnonymous,
  )? onCreated;

  @override
  State<PollSheet> createState() => _PollSheetState();
}

class _PollSheetState extends State<PollSheet> {
  final _questionController = TextEditingController();
  final _optionControllers = [TextEditingController(), TextEditingController()];
  bool _multipleChoice = false;
  bool _anonymous = true;

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 8) return;
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    final controller = _optionControllers.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 10,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x260F172A),
                blurRadius: 24,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: AppColors.chatGrad,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        LucideIcons.barChart3,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tạo bình chọn',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Gửi câu hỏi để mọi người cùng bỏ phiếu',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                PollTextField(
                  controller: _questionController,
                  hintText: 'Câu hỏi bình chọn',
                  icon: LucideIcons.circleHelp,
                ),
                const SizedBox(height: 16),
                const PollLabel('Lựa chọn'),
                const SizedBox(height: 8),
                for (var index = 0; index < _optionControllers.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: PollOptionField(
                      controller: _optionControllers[index],
                      index: index,
                      canRemove: _optionControllers.length > 2,
                      onRemove: () => _removeOption(index),
                    ),
                  ),
                PressableScale(
                  onTap: _addOption,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.plus,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Thêm lựa chọn',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                PollSwitchTile(
                  icon: LucideIcons.listChecks,
                  title: 'Cho phép chọn nhiều đáp án',
                  value: _multipleChoice,
                  onChanged: (value) => setState(() => _multipleChoice = value),
                ),
                const SizedBox(height: 8),
                PollSwitchTile(
                  icon: LucideIcons.eyeOff,
                  title: 'Bình chọn ẩn danh',
                  value: _anonymous,
                  onChanged: (value) => setState(() => _anonymous = value),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    label: 'Tạo bình chọn',
                    icon: LucideIcons.send,
                    onPressed: () {
                      final question = _questionController.text.trim();
                      final options = _optionControllers
                          .map((c) => c.text.trim())
                          .where((t) => t.isNotEmpty)
                          .toList();

                      if (question.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng nhập câu hỏi bình chọn.'),
                          ),
                        );
                        return;
                      }
                      if (options.length < 2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng nhập ít nhất 2 lựa chọn.'),
                          ),
                        );
                        return;
                      }

                      Navigator.pop(context);
                      widget.onCreated?.call(
                        question,
                        options,
                        _multipleChoice,
                        _anonymous,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã tạo bình chọn thành công!'),
                        ),
                      );
                    },
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

class PollTextField extends StatelessWidget {
  const PollTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        hintText: hintText,
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: const Color(0xFFF3F6FC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class PollOptionField extends StatelessWidget {
  const PollOptionField({
    super.key,
    required this.controller,
    required this.index,
    required this.canRemove,
    required this.onRemove,
  });

  final TextEditingController controller;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        prefixIcon: Center(
          widthFactor: 1,
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        suffixIcon: canRemove
            ? IconButton(
                tooltip: 'Xóa lựa chọn',
                onPressed: onRemove,
                icon: const Icon(LucideIcons.x, size: 18),
                color: AppColors.textMuted,
              )
            : null,
        hintText: 'Lựa chọn ${index + 1}',
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: const Color(0xFFF3F6FC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class PollLabel extends StatelessWidget {
  const PollLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class PollSwitchTile extends StatelessWidget {
  const PollSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.28),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class AttachmentPickerSheet extends StatefulWidget {
  const AttachmentPickerSheet({super.key, required this.onSelected});

  final ValueChanged<AttachmentAction> onSelected;

  @override
  State<AttachmentPickerSheet> createState() => _AttachmentPickerSheetState();
}

class _AttachmentPickerSheetState extends State<AttachmentPickerSheet> {
  static const _actions = [
    AttachmentAction(
      type: AttachmentType.gallery,
      label: 'Thư viện ảnh',
      icon: LucideIcons.image,
    ),
    AttachmentAction(
      type: AttachmentType.camera,
      label: 'Máy ảnh',
      icon: LucideIcons.camera,
    ),
    AttachmentAction(
      type: AttachmentType.document,
      label: 'Tài liệu',
      icon: LucideIcons.fileText,
    ),
    AttachmentAction(
      type: AttachmentType.poll,
      label: 'Tạo bình chọn',
      icon: LucideIcons.barChart3,
    ),
    AttachmentAction(
      type: AttachmentType.location,
      label: 'Vị trí',
      icon: LucideIcons.mapPin,
    ),
    AttachmentAction(
      type: AttachmentType.contact,
      label: 'Liên hệ',
      icon: LucideIcons.contact,
    ),
  ];

  static const _itemColors = [
    Color(0xFF10B981), // Gallery - Green
    Color(0xFF3B82F6), // Camera - Blue
    Color(0xFFF59E0B), // Document - Orange
    Color(0xFF8B5CF6), // Poll - Purple
    Color(0xFFEF4444), // Location - Red
    Color(0xFF06B6D4), // Contact - Teal
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AttachmentSheetHeader(),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _actions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (context, index) {
                  final action = _actions[index];
                  final color = _itemColors[index];
                  return AttachmentGridItem(
                    icon: action.icon,
                    color: color,
                    label: action.label,
                    onTap: () => widget.onSelected(action),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AttachmentSheetHeader extends StatelessWidget {
  const AttachmentSheetHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Thêm tệp đính kèm',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class AttachmentGridItem extends StatelessWidget {
  const AttachmentGridItem({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ImageDetailViewer extends StatefulWidget {
  const ImageDetailViewer({
    super.key,
    required this.heroTag,
    required this.imageData,
  });

  final String heroTag;
  final dynamic imageData;

  @override
  State<ImageDetailViewer> createState() => _ImageDetailViewerState();
}

class _ImageDetailViewerState extends State<ImageDetailViewer> {
  double _dragOffset = 0.0;

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (widget.imageData is Uint8List) {
      imageWidget = Image.memory(
        widget.imageData as Uint8List,
        fit: BoxFit.contain,
      );
    } else if (widget.imageData is File) {
      imageWidget = Image.file(
        widget.imageData as File,
        fit: BoxFit.contain,
      );
    } else {
      imageWidget = const Icon(Icons.broken_image, color: Colors.white, size: 60);
    }

    final opacity = (1.0 - (_dragOffset.abs() / 300.0)).clamp(0.2, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: opacity),
      body: SafeArea(
        child: Stack(
          children: [
            GestureDetector(
              onVerticalDragUpdate: (details) {
                setState(() {
                  _dragOffset += details.delta.dy;
                });
              },
              onVerticalDragEnd: (details) {
                if (_dragOffset.abs() > 100 || details.velocity.pixelsPerSecond.dy.abs() > 500) {
                  Navigator.of(context).pop();
                } else {
                  setState(() {
                    _dragOffset = 0.0;
                  });
                }
              },
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: Center(
                  child: Hero(
                    tag: widget.heroTag,
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: imageWidget,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImagePreviewSheet extends StatefulWidget {
  const ImagePreviewSheet({
    super.key,
    required this.filename,
    required this.bytes,
    required this.mimetype,
    required this.onSend,
  });

  final String filename;
  final Uint8List bytes;
  final String mimetype;
  final Future<void> Function(MobileAttachmentUpload upload, String? caption) onSend;

  @override
  State<ImagePreviewSheet> createState() => _ImagePreviewSheetState();
}

class _ImagePreviewSheetState extends State<ImagePreviewSheet> {
  final TextEditingController _captionController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (_sending) return;
    setState(() => _sending = true);
    final upload = MobileAttachmentUpload(
      filename: widget.filename,
      bytes: widget.bytes,
      mimetype: widget.mimetype,
    );
    await widget.onSend(upload, _captionController.text);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Gửi hình ảnh',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      color: AppColors.textSecondary,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                constraints: const BoxConstraints(maxHeight: 280),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.6),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.memory(
                    widget.bytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: TextField(
                          controller: _captionController,
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _handleSend(),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Thêm chú thích...',
                            hintStyle: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    PressableScale(
                      onTap: _sending ? null : _handleSend,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2AABEE),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x332AABEE),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                LucideIcons.send,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TxtReaderSheet extends StatelessWidget {
  const TxtReaderSheet({
    super.key,
    required this.fileName,
    required this.content,
    required this.bytes,
  });

  final String fileName;
  final String content;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
              child: Row(
                children: [
                  const Icon(LucideIcons.fileCode, color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${lines.length} dòng • ${formatFileSize(bytes.length)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.copy, size: 20),
                    tooltip: 'Sao chép',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã sao chép nội dung tệp.')),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.download, size: 20),
                    tooltip: 'Tải về',
                    onPressed: () async {
                      await saveBytesToFile(bytes, fileName);
                    },
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 38,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            lines[index],
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              fontFamily: 'monospace',
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DocumentActionSheet extends StatelessWidget {
  const DocumentActionSheet({
    super.key,
    required this.fileName,
    required this.ext,
    required this.bytes,
    this.previewUrl,
  });

  final String fileName;
  final String ext;
  final Uint8List bytes;
  final String? previewUrl;

  @override
  Widget build(BuildContext context) {
    final iconColor = fileAccentColor(fileName);
    final icon = fileIcon(fileName);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Định dạng ${ext.toUpperCase()} • ${formatFileSize(bytes.length)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(LucideIcons.download, size: 20),
            label: const Text(
              'Tải xuống & Mở bằng ứng dụng',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await saveBytesToFile(bytes, fileName);
            },
          ),
          if (previewUrl != null && previewUrl!.isNotEmpty) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                minimumSize: const Size.fromHeight(48),
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(LucideIcons.externalLink, size: 20),
              label: const Text(
                'Mở bằng liên kết xem trực tiếp',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              onPressed: () {
                Navigator.pop(context);
                openDownloadUrl(previewUrl!);
              },
            ),
          ],
        ],
      ),
    );
  }
}
