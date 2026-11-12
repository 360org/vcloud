import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/odoo_api_client.dart';
import '../../../shared/models/profile.dart';
import '../../auth/application/auth_controller.dart';
import '../data/models/partner_contact_detail.dart';

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

/// Provider truy xuất chi tiết thông tin đối tác/khách hàng từ Odoo backend
final partnerContactDetailProvider =
    FutureProvider.family<PartnerContactDetail?, int>((ref, partnerId) async {
  if (partnerId <= 0) return null;
  try {
    final response = await odooApiClient.get('/api/v1/mobile/contacts/$partnerId');
    if (response is Map<String, dynamic>) {
      return PartnerContactDetail.fromJson(response);
    }
  } catch (e) {
    debugPrint('⚠️ [ProfileController] Failed to fetch contact $partnerId: $e');
  }
  return null;
});
