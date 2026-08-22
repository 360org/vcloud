import 'package:flutter/material.dart';
import '../../data/models/chat_v2_reaction.dart';

class ChatV2ReactionDetailsSheet extends StatelessWidget {
  final List<ChatV2Reaction> reactions;
  final String? currentUserName;

  const ChatV2ReactionDetailsSheet({
    super.key,
    required this.reactions,
    this.currentUserName,
  });

  static const List<List<Color>> _avatarGradients = [
    [Color(0xFF0284C7), Color(0xFF0EA5E9)],
    [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
    [Color(0xFF059669), Color(0xFF10B981)],
    [Color(0xFFD97706), Color(0xFFF59E0B)],
    [Color(0xFFDC2626), Color(0xFFEF4444)],
    [Color(0xFF0891B2), Color(0xFF06B6D4)],
    [Color(0xFFEA580C), Color(0xFFF97316)],
    [Color(0xFF4F46E5), Color(0xFF6366F1)],
    [Color(0xFFDB2777), Color(0xFFEC4899)],
    [Color(0xFF0D9488), Color(0xFF14B8A6)],
  ];

  static List<Color> getAvatarGradient(String name) {
    if (name.isEmpty) return _avatarGradients[0];
    final hash = name.codeUnits.fold(0, (a, b) => a + b);
    return _avatarGradients[hash % _avatarGradients.length];
  }

  static String getInitial(String name) {
    if (name.trim().isEmpty) return '?';
    return name.trim()[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    int totalCount = reactions.fold(0, (sum, r) => sum + r.count);
    
    final List<Map<String, dynamic>> allMembers = [];
    for (var r in reactions) {
      for (var p in r.partners) {
        allMembers.add({
          'id': p['id'],
          'name': p['name'],
          'emoji': r.content,
        });
      }
    }

    return DefaultTabController(
      length: reactions.length + 1,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Biểu tượng cảm xúc',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: const Color(0xFF00C83A),
              labelColor: const Color(0xFF00C83A),
              unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: isDark ? Colors.white10 : Colors.black12,
              tabs: [
                Tab(text: 'Tất cả $totalCount'),
                ...reactions.map((r) => Tab(text: '${r.content} ${r.count}')),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildMemberList(allMembers, isDark),
                  ...reactions.map((r) {
                    final members = r.partners.map((p) => {
                      'id': p['id'],
                      'name': p['name'],
                      'emoji': r.content,
                    }).toList();
                    return _buildMemberList(members, isDark);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberList(List<Map<String, dynamic>> members, bool isDark) {
    if (members.isEmpty) {
      return Center(
        child: Text(
          'Không có dữ liệu',
          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
        ),
      );
    }
    
    return ListView.builder(
      itemCount: members.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final member = members[index];
        final name = member['name'] as String? ?? 'Unknown';
        final emoji = member['emoji'] as String? ?? '';
        final grad = getAvatarGradient(name);
        
        final isMe = currentUserName != null && 
                     currentUserName!.trim().isNotEmpty &&
                     name.trim().toLowerCase() == currentUserName!.trim().toLowerCase();

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: grad,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  getInitial(name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            isMe ? '$name (Bạn)' : name,
            style: TextStyle(
              fontWeight: isMe ? FontWeight.w700 : FontWeight.w600,
              fontSize: 15,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        );
      },
    );
  }
}
