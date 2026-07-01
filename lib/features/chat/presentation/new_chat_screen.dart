import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
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

  Future<void> _open(String otherId) async {
    setState(() => _busy = true);
    try {
      final id = await ref
          .read(conversationActionsProvider)
          .openDirect(otherId);
      if (mounted) context.go('/chat/$id');
    } on Failure catch (f) {
      _snack(f.message);
    } catch (e) {
      _snack('Could not start chat: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('New conversation'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Direct'),
            Tab(text: 'Group'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          Consumer(
            builder: (_, ref, _) {
              final users = ref.watch(_usersProvider);
              return users.when(
                data: (list) {
                  if (list.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No teammates yet'),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final p = list[i];
                      return Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          leading: UserAvatar(
                            userId: p.id,
                            displayName: p.displayName,
                            email: p.email,
                            avatarUrl: p.avatarUrl,
                          ),
                          title: Text(p.displayName),
                          subtitle: Text(p.email),
                          trailing: _busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.chat_bubble_outline),
                          onTap: _busy ? null : () => _open(p.id),
                        ),
                      );
                    },
                  );
                },
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(_usersProvider),
                ),
              );
            },
          ),
          _GroupForm(
            onCreate: (name, ids) async {
              if (name.trim().isEmpty || ids.isEmpty) {
                _snack('Name + at least one member required.');
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
                _snack('Could not create group: $e');
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
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(_GroupUsers.list);
    return users.when(
      data: (list) {
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
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  prefixIcon: Icon(Icons.group),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search teammates',
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final id in _selected)
                      InputChip(
                        label: Text(
                          list.firstWhere((p) => p.id == id).displayName,
                        ),
                        onDeleted: () => setState(() => _selected.remove(id)),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = filtered[i];
                  return CheckboxListTile(
                    value: _selected.contains(p.id),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(p.id);
                        } else {
                          _selected.remove(p.id);
                        }
                      });
                    },
                    title: Text(p.displayName),
                    subtitle: Text(p.email),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  icon: const Icon(Icons.check),
                  onPressed:
                      _selected.isEmpty ||
                          _name.text.trim().isEmpty ||
                          _selected.length < 2
                      ? null
                      : () => widget.onCreate(_name.text, _selected.toList()),
                  label: const Text('Create group'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
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
