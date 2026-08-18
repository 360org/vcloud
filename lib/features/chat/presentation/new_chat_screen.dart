import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../auth/application/auth_controller.dart';
import '../application/conversations_controller.dart';

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen>
    with TickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final _usersProvider = FutureProvider.autoDispose<List<Profile>>((ref) async {
    final repo = ref.read(chatRepositoryProvider);
    return repo.allUsers();
  });
  bool _busy = false;

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _open(String partnerId) async {
    setState(() => _busy = true);
    try {
      final id = await ref
          .read(conversationActionsProvider)
          .openDirect(partnerId);
      if (mounted) context.go('/chat/$id');
    } on Failure catch (f) {
      _snack(f.message);
    } catch (e) {
      _snack('Không thể bắt đầu trò chuyện: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            LucideIcons.chevronLeft,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            size: 22,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/chat');
            }
          },
        ),
        title: Text(
          'Cuộc trò chuyện mới',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
              ),
            ),
            child: TabBar(
              controller: _tab,
              indicatorColor: const Color(0xFF00C83A),
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: const Color(0xFF00C83A),
              unselectedLabelColor:
                  isDark ? Colors.white60 : const Color(0xFF64748B),
              labelStyle: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'Cá nhân'),
                Tab(text: 'Tạo nhóm'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          Consumer(
            builder: (_, ref, _) {
              final users = ref.watch(_usersProvider);
              final currentUser = ref.watch(authControllerProvider).valueOrNull;
              final currentUserId = currentUser?.id;
              final meta = currentUser?.userMetadata;
              final currentPartnerId = meta?['partner_id']?.toString() ??
                  meta?['partner']?['id']?.toString();

              final filteredUsers = users.whenData((rawList) {
                return rawList.where((p) {
                  final isSelf = (currentUserId != null &&
                          (p.id == currentUserId ||
                              p.partnerId == currentUserId)) ||
                      (currentPartnerId != null &&
                          (p.partnerId == currentPartnerId ||
                              p.id == currentPartnerId));
                  return !isSelf;
                }).toList();
              });

              return _DirectChatList(
                users: filteredUsers,
                busy: _busy,
                onOpen: _open,
                onRetry: () => ref.invalidate(_usersProvider),
              );
            },
          ),
          _GroupForm(
            onCreate: (name, ids) async {
              if (name.trim().isEmpty || ids.isEmpty) {
                _snack('Vui lòng nhập tên nhóm và chọn ít nhất 1 thành viên.');
                return;
              }
              setState(() => _busy = true);
              try {
                final id = await ref
                    .read(conversationActionsProvider)
                    .createGroup(name.trim(), ids);
                if (!context.mounted) return;
                context.go('/chat/$id');
              } catch (e) {
                _snack('Không thể tạo nhóm: $e');
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _DirectChatList extends StatefulWidget {
  const _DirectChatList({
    required this.users,
    required this.busy,
    required this.onOpen,
    required this.onRetry,
  });

  final AsyncValue<List<Profile>> users;
  final bool busy;
  final Future<void> Function(String partnerId) onOpen;
  final VoidCallback onRetry;

  @override
  State<_DirectChatList> createState() => _DirectChatListState();
}

class _DirectChatListState extends State<_DirectChatList> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return widget.users.when(
      data: (list) {
        final filtered = _query.isEmpty
            ? list
            : list.where((p) {
                final q = _query.toLowerCase();
                return p.displayName.toLowerCase().contains(q) ||
                    p.email.toLowerCase().contains(q);
              }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  fontSize: 14.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    LucideIcons.search,
                    size: 18,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            LucideIcons.x,
                            size: 16,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  hintText: 'Tìm kiếm theo tên hoặc email...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF00C83A),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _query.isEmpty
                              ? 'Chưa có đồng nghiệp nào'
                              : 'Không tìm thấy đồng nghiệp phù hợp',
                          style: TextStyle(
                            fontSize: 14.5,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: 72,
                        endIndent: 16,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFE2E8F0),
                      ),
                      itemBuilder: (_, i) {
                        final p = filtered[i];
                        return Material(
                          type: MaterialType.transparency,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: UserAvatar(
                              userId: p.id,
                              displayName: p.displayName,
                              email: p.email,
                              avatarUrl: p.avatarUrl,
                              size: 44,
                            ),
                            title: Text(
                              p.displayName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            subtitle: Text(
                              p.email,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white60
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            trailing: widget.busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF00C83A),
                                    ),
                                  )
                                : Icon(
                                    LucideIcons.messageSquare,
                                    size: 19,
                                    color: isDark
                                        ? Colors.white54
                                        : const Color(0xFF94A3B8),
                                  ),
                            onTap: widget.busy || p.partnerId == null
                                ? null
                                : () => widget.onOpen(p.partnerId!),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        error: e,
        onRetry: widget.onRetry,
      ),
    );
  }
}

class _GroupForm extends ConsumerStatefulWidget {
  const _GroupForm({required this.onCreate});
  final Future<void> Function(String name, List<String> ids) onCreate;

  @override
  ConsumerState<_GroupForm> createState() => _GroupFormState();
}

class _GroupFormState extends ConsumerState<_GroupForm> {
  final _name = TextEditingController();
  final Set<String> _selected = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _name.addListener(_onNameChanged);
  }

  void _onNameChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.removeListener(_onNameChanged);
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final users = ref.watch(_GroupUsers.list);
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    final currentUserId = currentUser?.id;
    final meta = currentUser?.userMetadata;
    final currentPartnerId = meta?['partner_id']?.toString() ??
        meta?['partner']?['id']?.toString();

    return users.when(
      data: (rawList) {
        // Lọc bỏ chính mình khỏi danh sách chọn thành viên (vì người tạo mặc định là thành viên)
        final list = rawList.where((p) {
          final isSelf = (currentUserId != null &&
                  (p.id == currentUserId ||
                      p.partnerId == currentUserId)) ||
              (currentPartnerId != null &&
                  (p.partnerId == currentPartnerId ||
                      p.id == currentPartnerId));
          return !isSelf;
        }).toList();

        final filtered = _query.isEmpty
            ? list
            : list
                  .where(
                    (p) => p.displayName.toLowerCase().contains(
                      _query.toLowerCase(),
                    ),
                  )
                  .toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _name,
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontSize: 14.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  labelText: 'Tên nhóm trò chuyện',
                  labelStyle: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                  prefixIcon: Icon(
                    LucideIcons.users,
                    size: 18,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF00C83A),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    LucideIcons.search,
                    size: 18,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                  hintText: 'Tìm kiếm thành viên...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF00C83A),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final id in _selected)
                      InputChip(
                        label: Text(
                          list
                              .firstWhere(
                                (p) =>
                                    (p.partnerId ?? p.id) == id || p.id == id,
                                orElse: () => Profile(
                                  id: id,
                                  email: '',
                                  displayName: 'Thành viên',
                                ),
                              )
                              .displayName,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        backgroundColor: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFE2E8F0),
                        deleteIconColor: isDark
                            ? Colors.white60
                            : const Color(0xFF64748B),
                        onDeleted: () => setState(() => _selected.remove(id)),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              padding: const EdgeInsets.symmetric(vertical: 4),
              separatorBuilder: (_, _) => Divider(
                height: 1,
                indent: 72,
                endIndent: 16,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFE2E8F0),
              ),
              itemBuilder: (_, i) {
                final p = filtered[i];
                final targetId = p.partnerId ?? p.id;
                return CheckboxListTile(
                  value: _selected.contains(targetId),
                  activeColor: const Color(0xFF00C83A),
                  checkColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  secondary: UserAvatar(
                    userId: p.id,
                    displayName: p.displayName,
                    email: p.email,
                    avatarUrl: p.avatarUrl,
                    size: 40,
                  ),
                  title: Text(
                    p.displayName,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  subtitle: Text(
                    p.email,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selected.add(targetId);
                      } else {
                        _selected.remove(targetId);
                      }
                    });
                  },
                );
              },
            ),
          ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  icon: const Icon(LucideIcons.check, size: 18),
                  onPressed: _selected.isEmpty || _name.text.trim().isEmpty
                      ? null
                      : () => widget.onCreate(_name.text, _selected.toList()),
                  label: Text(
                    _selected.isEmpty
                        ? 'Chọn ít nhất 1 thành viên'
                        : 'Tạo nhóm (${_selected.length} thành viên)',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00C83A),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark
                        ? Colors.white12
                        : const Color(0xFFE2E8F0),
                    disabledForegroundColor: isDark
                        ? Colors.white38
                        : const Color(0xFF94A3B8),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(error: e),
    );
  }
}

class _GroupUsers {
  static final list = FutureProvider.autoDispose<List<Profile>>((ref) async {
    final repo = ref.read(chatRepositoryProvider);
    return repo.allUsers();
  });
}
