import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/profile.dart';
import '../../auth/application/auth_controller.dart';

final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return null;

  return Profile(
    id: user.id,
    email: user.email ?? '',
    displayName: user.userMetadata['display_name'] as String? ?? '',
    role: 'employee',
  );
});

final canChangeTicketStatusProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentProfileProvider).value;
  if (profile == null) return false;
  return profile.isStaff || profile.isAdmin;
});
