import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/api/mobile_attachment_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/ticket.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../application/ticket_controller.dart';

class CreateTicketScreen extends ConsumerStatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  ConsumerState<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends ConsumerState<CreateTicketScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _ccEmail = TextEditingController();
  final _attachments = <_TicketAttachmentDraft>[];
  final _imagePicker = ImagePicker();

  TicketPriority _priority = TicketPriority.p3;
  _TicketTag _tag = _ticketTags.first;
  int? _teamId;
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _ccEmail.dispose();
    super.dispose();
  }

  Future<void> _submit(List<TicketTeamOption> teams) async {
    if (!_form.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final selectedTeamId = _selectedTeamId(teams);
      await ref
          .read(ticketActionsProvider)
          .create(
            title: _title.text.trim(),
            description: _buildDescription(),
            priority: _priority,
            category: selectedTeamId.toString(),
            tagIds: _tag.id == null ? const <int>[] : <int>[_tag.id!],
            attachments: _attachmentUploads(),
          );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Failure: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _buildDescription() {
    final ccEmail = _ccEmail.text.trim();
    final lines = <String>[
      _description.text.trim(),
      if (_attachments.isNotEmpty) '',
      if (_attachments.isNotEmpty)
        'Tai lieu dinh kem: ${_attachments.map((file) => file.name).join(', ')}',
      if (ccEmail.isNotEmpty) '',
      if (ccEmail.isNotEmpty) 'CC email: $ccEmail',
    ];
    return lines.where((line) => line.isNotEmpty).join('\n');
  }

  List<MobileAttachmentUpload> _attachmentUploads() {
    return [
      for (final attachment in _attachments)
        MobileAttachmentUpload(
          filename: attachment.name,
          bytes: attachment.bytes,
          mimetype: attachment.mimetype,
        ),
    ];
  }

  Future<void> _addAttachment() async {
    final source = await showModalBottomSheet<_AttachmentSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AttachmentSourceSheet(),
    );
    if (source == null) return;

    final picked = switch (source) {
      _AttachmentSource.photo => await _pickImage(ImageSource.gallery),
      _AttachmentSource.camera => await _pickImage(ImageSource.camera),
      _AttachmentSource.document => await _pickDocument(),
    };
    if (picked == null || !mounted) return;

    setState(() => _attachments.add(picked));
  }

  Future<_TicketAttachmentDraft?> _pickImage(ImageSource source) async {
    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 2200,
    );
    if (image == null) return null;
    return _TicketAttachmentDraft(
      name: image.name,
      bytes: await image.readAsBytes(),
      mimetype: _mimetypeForName(image.name),
      source: source == ImageSource.camera
          ? _AttachmentSource.camera
          : _AttachmentSource.photo,
    );
  }

  Future<_TicketAttachmentDraft?> _pickDocument() async {
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
    if (file == null || file.bytes == null) return null;
    return _TicketAttachmentDraft(
      name: file.name,
      bytes: file.bytes!,
      mimetype: _mimetypeForName(file.name),
      source: _AttachmentSource.document,
    );
  }

  int _selectedTeamId(List<TicketTeamOption> teams) {
    final current = _teamId;
    if (current != null && teams.any((team) => team.id == current)) {
      return current;
    }
    return teams.isEmpty ? 1 : teams.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final teams = ref.watch(ticketTeamsProvider);

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _CreateTicketHeader(),
                const SizedBox(height: 16),
                _TicketSummary(priority: _priority, tag: _tag),
                const SizedBox(height: 14),
                _FormPanel(
                  children: [
                    _TicketTextField(
                      controller: _title,
                      label: 'Tiêu đề',
                      hintText: 'Ví dụ: Không đăng nhập được Odoo',
                      icon: LucideIcons.type,
                      maxLength: 120,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Vui lòng nhập tiêu đề';
                        if (text.length > 120) return 'Tối đa 120 ký tự';
                        return null;
                      },
                    ),
                    _DescriptionComposer(
                      controller: _description,
                      attachments: _attachments,
                      onAddAttachment: _addAttachment,
                      onRemoveAttachment: (attachment) {
                        setState(() => _attachments.remove(attachment));
                      },
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Vui lòng mô tả vấn đề';
                        if (text.length < 12) {
                          return 'Mô tả cần rõ hơn một chút';
                        }
                        return null;
                      },
                    ),
                    _PriorityStars(
                      priority: _priority,
                      onChanged: (priority) {
                        setState(() => _priority = priority);
                      },
                    ),
                    _TicketDropdown<_TicketTag>(
                      label: 'Tag',
                      icon: LucideIcons.tag,
                      value: _tag,
                      items: _ticketTags,
                      itemLabel: (item) => item.label,
                      onChanged: (value) {
                        if (value != null) setState(() => _tag = value);
                      },
                    ),
                    _TicketTextField(
                      controller: _ccEmail,
                      label: 'CC email',
                      hintText: 'email1@360.com, email2@360.com',
                      icon: LucideIcons.mail,
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateCcEmail,
                    ),
                    teams.when(
                      data: (items) => _TicketDropdown<int>(
                        label: 'Team xử lý lỗi',
                        icon: LucideIcons.users,
                        value: _selectedTeamId(items),
                        items: [
                          if (items.isEmpty) 1,
                          for (final team in items) team.id,
                        ],
                        itemLabel: (id) {
                          final match = items.where((team) => team.id == id);
                          return match.isEmpty
                              ? 'Hỗ trợ chung'
                              : match.first.name;
                        },
                        onChanged: (value) {
                          if (value != null) setState(() => _teamId = value);
                        },
                      ),
                      loading: () => const _LoadingTeamField(),
                      error: (_, _) => _TicketDropdown<int>(
                        label: 'Team xử lý lỗi',
                        icon: LucideIcons.users,
                        value: 1,
                        items: const <int>[1],
                        itemLabel: (_) => 'Hỗ trợ chung',
                        onChanged: (value) {
                          if (value != null) setState(() => _teamId = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                teams.when(
                  data: (items) => GradientButton(
                    label: 'Gửi ticket',
                    icon: LucideIcons.send,
                    gradient: AppColors.ticketGrad,
                    glowColor: AppColors.ticket,
                    loading: _submitting,
                    onPressed: _submitting ? null : () => _submit(items),
                  ),
                  loading: () => const GradientButton(
                    label: 'Đang tải team',
                    icon: LucideIcons.loader,
                    gradient: AppColors.ticketGrad,
                    glowColor: AppColors.ticket,
                    loading: true,
                    onPressed: null,
                  ),
                  error: (_, _) => GradientButton(
                    label: 'Gửi ticket',
                    icon: LucideIcons.send,
                    gradient: AppColors.ticketGrad,
                    glowColor: AppColors.ticket,
                    loading: _submitting,
                    onPressed: _submitting ? null : () => _submit(const []),
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

class _CreateTicketHeader extends StatelessWidget {
  const _CreateTicketHeader();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleWidth = (constraints.maxWidth - 120).clamp(180.0, 292.0);
        return SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: PressableScale(
                  onTap: () => Navigator.maybePop(context),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: _softSurfaceDecoration(
                      context: context,
                      radius: 24,
                    ),
                    child: Icon(
                      LucideIcons.chevronLeft,
                      color: context.textColor,
                      size: 24,
                    ),
                  ),
                ),
              ),
              Center(
                child: SizedBox(
                  width: titleWidth,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    alignment: Alignment.center,
                    decoration: _softSurfaceDecoration(
                      context: context,
                      radius: 24,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.ticketPlus,
                          color: AppColors.ticket,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Tạo ticket',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.textColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TicketSummary extends StatelessWidget {
  const _TicketSummary({required this.priority, required this.tag});

  final TicketPriority priority;
  final _TicketTag tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.ticketGrad,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.glow(AppColors.ticket, opacity: 0.18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              LucideIcons.sparkles,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phiếu hỗ trợ mới',
                  style: AppTextStyles.title.copyWith(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SummaryPill(label: _priorityLabel(priority)),
                    _SummaryPill(label: tag.label),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: _softSurfaceDecoration(context: context, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _DescriptionComposer extends StatelessWidget {
  const _DescriptionComposer({
    required this.controller,
    required this.attachments,
    required this.onAddAttachment,
    required this.onRemoveAttachment,
    required this.validator,
  });

  final TextEditingController controller;
  final List<_TicketAttachmentDraft> attachments;
  final VoidCallback onAddAttachment;
  final ValueChanged<_TicketAttachmentDraft> onRemoveAttachment;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Mô tả vấn đề'),
        const SizedBox(height: 8),
        Container(
          decoration: _composerDecoration(context),
          child: Column(
            children: [
              TextFormField(
                controller: controller,
                validator: validator,
                minLines: 5,
                maxLines: 8,
                textInputAction: TextInputAction.newline,
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: 'Mô tả lỗi, bước tái hiện, ảnh hưởng hiện tại...',
                  hintStyle: TextStyle(
                    color: context.textMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(top: 17),
                    child: Icon(
                      LucideIcons.messageSquareText,
                      color: context.textMuted,
                      size: 21,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 48,
                    maxWidth: 48,
                  ),
                  counterText: '',
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.fromLTRB(0, 17, 16, 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                ),
              ),
              Divider(height: 1, color: context.borderColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _ComposerActionButton(onTap: onAddAttachment),
                        const Spacer(),
                        Text(
                          attachments.isEmpty
                              ? 'Chưa có tài liệu'
                              : '${attachments.length} tài liệu',
                          style: AppTextStyles.caption.copyWith(
                            color: context.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (attachments.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final attachment in attachments)
                            _DocumentChip(
                              attachment: attachment,
                              onRemove: () => onRemoveAttachment(attachment),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComposerActionButton extends StatelessWidget {
  const _ComposerActionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: context.softColor(AppColors.ticket),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.ticket.withValues(alpha: 0.18)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.paperclip, color: AppColors.ticket, size: 17),
            SizedBox(width: 7),
            Text(
              'Thêm tài liệu',
              style: TextStyle(
                color: AppColors.ticket,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentChip extends StatelessWidget {
  const _DocumentChip({required this.attachment, required this.onRemove});

  final _TicketAttachmentDraft attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.fromLTRB(9, 7, 6, 7),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(attachment.icon, color: AppColors.ticket, size: 15),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              attachment.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.textColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              LucideIcons.x,
              color: context.textMuted,
              size: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentSourceSheet extends StatelessWidget {
  const _AttachmentSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            const SectionHeader(title: 'Thêm tài liệu'),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final item in _attachmentSourceItems) ...[
                  Expanded(
                    child: _AttachmentSourceTile(
                      item: item,
                      onTap: () => Navigator.pop(context, item.source),
                    ),
                  ),
                  if (item != _attachmentSourceItems.last)
                    const SizedBox(width: 10),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentSourceTile extends StatelessWidget {
  const _AttachmentSourceTile({required this.item, required this.onTap});

  final _AttachmentSourceItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 92,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.softColor(item.color),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: item.color.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: item.color, size: 24),
            const SizedBox(height: 8),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: item.color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketTextField extends StatelessWidget {
  const _TicketTextField({
    required this.controller,
    required this.label,
    required this.hintText,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.maxLength,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLength: maxLength,
          textInputAction: TextInputAction.next,
          style: TextStyle(
            color: context.textColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
          decoration: _inputDecoration(context: context, hintText: hintText, icon: icon),
        ),
      ],
    );
  }
}

class _TicketDropdown<T> extends StatelessWidget {
  const _TicketDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final T value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          icon: Icon(LucideIcons.chevronDown, color: context.textMuted),
          decoration: _inputDecoration(context: context, hintText: label, icon: icon),
          dropdownColor: context.cardColor,
          borderRadius: BorderRadius.circular(18),
          style: TextStyle(
            color: context.textColor,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabel(item), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _PriorityStars extends StatelessWidget {
  const _PriorityStars({required this.priority, required this.onChanged});

  final TicketPriority priority;
  final ValueChanged<TicketPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedStars = _priorityStars(priority);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Mức độ ưu tiên'),
        const SizedBox(height: 8),
        Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: _fieldDecoration(context),
          child: Row(
            children: [
              for (var i = 1; i <= 4; i++) ...[
                PressableScale(
                  onTap: () => onChanged(_priorityFromStars(i)),
                  child: Icon(
                    LucideIcons.star,
                    color: i <= selectedStars
                        ? AppColors.ticket
                        : context.textMuted,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(width: 1, height: 24, color: context.borderColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _priorityLabel(priority),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoadingTeamField extends StatelessWidget {
  const _LoadingTeamField();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Team xử lý lỗi'),
        const SizedBox(height: 8),
        Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: _fieldDecoration(context),
          child: Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Đang tải team...',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.label.copyWith(
        color: context.textColor,
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

InputDecoration _inputDecoration({
  required BuildContext context,
  required String hintText,
  required IconData icon,
  bool multiline = false,
}) {
  return InputDecoration(
    hintText: hintText,
    counterText: '',
    prefixIcon: Align(
      widthFactor: 1,
      heightFactor: 1,
      alignment: multiline ? Alignment.topCenter : Alignment.center,
      child: Padding(
        padding: EdgeInsets.only(top: multiline ? 17 : 0),
        child: Icon(icon, color: context.textMuted, size: 21),
      ),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 48, maxWidth: 48),
    hintStyle: TextStyle(
      color: context.textMuted,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.35,
    ),
    filled: true,
    fillColor: context.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFFAFBFE),
    contentPadding: EdgeInsets.fromLTRB(
      0,
      multiline ? 17 : 0,
      16,
      multiline ? 17 : 0,
    ),
    constraints: multiline ? null : const BoxConstraints(minHeight: 58),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: BorderSide(color: context.borderColor),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: AppColors.danger),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: AppColors.ticket, width: 1.4),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: AppColors.danger),
    ),
  );
}

BoxDecoration _fieldDecoration(BuildContext context) {
  return BoxDecoration(
    color: context.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFFAFBFE),
    borderRadius: BorderRadius.circular(17),
    border: Border.all(color: context.borderColor),
  );
}

BoxDecoration _composerDecoration(BuildContext context) {
  return BoxDecoration(
    color: context.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFFAFBFE),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: context.borderColor),
    boxShadow: const [
      BoxShadow(color: Color(0x030F172A), blurRadius: 10, offset: Offset(0, 4)),
    ],
  );
}

BoxDecoration _softSurfaceDecoration({
  required BuildContext context,
  required double radius,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: isDark ? const Color(0xFF1E293B) : AppColors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : AppColors.border.withValues(alpha: 0.7),
    ),
    boxShadow: const [
      BoxShadow(color: Color(0x080F172A), blurRadius: 14, offset: Offset(0, 6)),
    ],
  );
}

String? _validateCcEmail(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;

  final emails = text
      .split(RegExp(r'[,;\s]+'))
      .where((email) => email.isNotEmpty);
  final invalid = emails.where((email) => !_emailPattern.hasMatch(email));
  return invalid.isEmpty ? null : 'CC email không hợp lệ';
}

int _priorityStars(TicketPriority priority) => switch (priority) {
  TicketPriority.p1 => 4,
  TicketPriority.p2 => 3,
  TicketPriority.p3 => 2,
  TicketPriority.p4 => 1,
};

TicketPriority _priorityFromStars(int stars) => switch (stars) {
  4 => TicketPriority.p1,
  3 => TicketPriority.p2,
  2 => TicketPriority.p3,
  _ => TicketPriority.p4,
};

String _priorityLabel(TicketPriority priority) => switch (priority) {
  TicketPriority.p1 => 'Khẩn cấp',
  TicketPriority.p2 => 'Cao',
  TicketPriority.p3 => 'Bình thường',
  TicketPriority.p4 => 'Thấp',
};

class _TicketTag {
  const _TicketTag({required this.id, required this.label});

  final int? id;
  final String label;
}

enum _AttachmentSource { photo, camera, document }

class _TicketAttachmentDraft {
  const _TicketAttachmentDraft({
    required this.name,
    required this.bytes,
    required this.source,
    this.mimetype,
  });

  final String name;
  final Uint8List bytes;
  final _AttachmentSource source;
  final String? mimetype;

  IconData get icon => switch (source) {
    _AttachmentSource.photo => LucideIcons.image,
    _AttachmentSource.camera => LucideIcons.camera,
    _AttachmentSource.document => LucideIcons.fileText,
  };
}

class _AttachmentSourceItem {
  const _AttachmentSourceItem({
    required this.source,
    required this.label,
    required this.icon,
    required this.color,
  });

  final _AttachmentSource source;
  final String label;
  final IconData icon;
  final Color color;
}

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? _mimetypeForName(String name) {
  final extension = name.split('.').last.toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'pdf' => 'application/pdf',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' =>
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt' => 'text/plain',
    _ => null,
  };
}

const _attachmentSourceItems = <_AttachmentSourceItem>[
  _AttachmentSourceItem(
    source: _AttachmentSource.photo,
    label: 'Ảnh',
    icon: LucideIcons.image,
    color: AppColors.chat,
  ),
  _AttachmentSourceItem(
    source: _AttachmentSource.camera,
    label: 'Camera',
    icon: LucideIcons.camera,
    color: AppColors.timesheet,
  ),
  _AttachmentSourceItem(
    source: _AttachmentSource.document,
    label: 'Tài liệu',
    icon: LucideIcons.fileText,
    color: AppColors.ticket,
  ),
];

const _ticketTags = <_TicketTag>[
  _TicketTag(id: null, label: 'Không chọn'),
  _TicketTag(id: 1, label: 'Đăng nhập'),
  _TicketTag(id: 2, label: 'Odoo'),
  _TicketTag(id: 3, label: 'Thiết bị'),
  _TicketTag(id: 4, label: 'Mạng'),
  _TicketTag(id: 5, label: 'Dữ liệu'),
];
