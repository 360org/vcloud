import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/profile.dart';
import '../../auth/application/auth_controller.dart';

/// Provider to fetch the current user's profile from the profiles table
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return null;

  try {
    final response = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    return Profile.fromMap(response);
  } catch (e) {
    // If profile doesn't exist, create a default one
    return Profile(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'] as String? ?? '',
      role: 'customer',
    );
  }
});

/// Helper to check if current user can change ticket status
final canChangeTicketStatusProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentProfileProvider).value;
  if (profile == null) return false;
  return profile.isStaff || profile.isAdmin;
});
