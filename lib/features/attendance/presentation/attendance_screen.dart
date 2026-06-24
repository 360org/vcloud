import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/attendance.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../auth/application/auth_controller.dart';
import '../application/attendance_controller.dart';

/// Mockup 03 — dedicated Check-in screen: live clock, big CHECK-IN /
/// CHECK-OUT, current location, history link.
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  bool _busy = false;

  static const _weekdays = [
    'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'
  ];

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
        const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _viDate {
    final wd = _weekdays[_now.weekday - 1];
    final d = _now.day.toString().padLeft(2, '0');
    final m = _now.month.toString().padLeft(2, '0');
    return '$wd, $d/$m/${_now.year}';
  }

  Future<void> _handle(bool checkIn) async {
    setState(() => _busy = true);
    try {
      final a = ref.read(attendanceActionsProvider);
      checkIn ? await a.checkIn() : await a.checkOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Failure: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = ref.watch(openSessionProvider);
    final isCheckedIn = open != null;
    final user = ref.watch(authControllerProvider).value;
    final name = (user?.userMetadata?['display_name'] as String?) ??
        user?.email?.split('@').first ??
        'Bạn';
    final clock =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';

    return AppScaffold(
      title: 'Check-in',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Center(
            child: UserAvatar(
                userId: currentUserId(), displayName: name, size: 84),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(clock,
                style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: 1)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(_viDate,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
          ),
          const SizedBox(height: 28),
          Center(
            child: _BigCircleButton(
              enabled: !isCheckedIn && !_busy,
              busy: _busy,
              onTap: () => _handle(true),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text('Hoặc',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
          ),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: isCheckedIn && !_busy ? () => _handle(false) : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('CHECK-OUT',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ),
          ),
          const SizedBox(height: 24),
          _LocationRow(open: open),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => context.push('/attendance/history'),
              child: const Text('Xem lịch sử check-in'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigCircleButton extends StatelessWidget {
  const _BigCircleButton({
    required this.enabled,
    required this.busy,
    required this.onTap,
  });
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gradient = enabled
        ? AppColors.successGrad
        : const LinearGradient(
            colors: [AppColors.textMuted, AppColors.textMuted]);
    final glow = enabled ? AppColors.success : AppColors.textMuted;
    final circle = GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 156,
        height: 156,
        decoration: BoxDecoration(
          gradient: gradient,
          shape: BoxShape.circle,
          boxShadow: AppColors.glow(glow, opacity: 0.45),
        ),
        child: busy
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.mapPin, color: Colors.white, size: 32),
                  SizedBox(height: 6),
                  Text('CHECK-IN',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                ],
              ),
      ),
    );
    // Gentle breathing pulse while it's actionable.
    if (!enabled) return circle;
    return circle
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 1.0, end: 1.05, duration: 1200.ms, curve: Curves.easeInOut);
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.open});
  final Attendance? open;

  @override
  Widget build(BuildContext context) {
    final hasCoords = open?.checkinLat != null && open?.checkinLng != null;
    final sub = hasCoords
        ? '${open!.checkinLat!.toStringAsFixed(5)}, ${open!.checkinLng!.toStringAsFixed(5)}'
        : '155 Nguyễn Thái Học, P. Tam Thắng, TP. HCM';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('VCCI Building HCM',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
