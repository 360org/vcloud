import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/chat_v2/application/chat_v2_channels_controller.dart';
import '../../../features/home/application/home_summary_controller.dart';
import '../../../features/ticket/application/ticket_controller.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../application/auth_controller.dart';

/// Modern executive light-themed splash screen for VCloud / Vua Hệ Thống.
/// Harmonizes seamlessly with the app's clean white and mint palette.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _isWarmingUp = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authControllerProvider).valueOrNull;
      if (user != null) {
        _warmupAndNavigate();
      }
    });
  }

  Future<void> _warmupAndNavigate() async {
    if (_isWarmingUp) return;
    _isWarmingUp = true;

    try {
      // Warm-up song song các core providers với timeout an toàn 1000ms
      await Future.wait([
        ref.read(mobileDashboardSummaryProvider.future),
        ref.read(chatV2ChannelsProvider.future),
        ref.read(ticketsProvider.future),
      ]).timeout(const Duration(milliseconds: 1000));
    } catch (_) {
      // Fail-soft: Timeout hoặc lỗi mạng nhẹ vẫn mở Home với dữ liệu sẵn có
    }

    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        _warmupAndNavigate();
      } else if (!next.isLoading) {
        context.go('/login');
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // ── Fresh Light Mint Gradient Background ─────────────────────────
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFE8F5E9), // Soft Mint Top
                  Color(0xFFF1F8F2), // Light Fresh Green Accent
                  Color(0xFFF8FAFC), // Crisp Off-White Bottom
                ],
              ),
            ),
          ),

          // ── Ambient Emerald Aura Glow ────────────────────────────────────
          Positioned(
            top: -60,
            left: MediaQuery.of(context).size.width / 2 - 150,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.16),
              ),
            )
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1.1, 1.1),
                  duration: 2500.ms,
                  curve: Curves.easeInOut,
                ),
          ),

          // ── Main Content Column ──────────────────────────────────────────
          SafeArea(
            child: SizedBox.expand(
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // ── Clean Crisp Brand Logo ───────────────────────────────
                  Container(
                    width: 220,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0).withValues(alpha: 0.9),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.07),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const BrandLogo(height: 62),
                  )
                      .animate()
                      .scale(
                        duration: 650.ms,
                        curve: Curves.easeOutBack,
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1.0, 1.0),
                      )
                      .fadeIn(duration: 450.ms),

                  const SizedBox(height: 26),

                  // ── Brand Title & Tagline ─────────────────────────────────
                  const Text(
                    'VUA HỆ THỐNG',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 180.ms, duration: 450.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),

                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFD1FAE5),
                      ),
                    ),
                    child: const Text(
                      'Hệ sinh thái Quản trị & Năng suất Doanh nghiệp',
                      style: TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 300.ms, duration: 450.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),

                  const Spacer(flex: 3),

                  // ── Modern Refined Emerald Loader ─────────────────────────
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF10B981),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Đang kết nối hệ thống...',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      )
                          .animate(
                            onPlay: (controller) => controller.repeat(reverse: true),
                          )
                          .fade(
                            begin: 0.6,
                            end: 1.0,
                            duration: 1000.ms,
                            curve: Curves.easeInOut,
                          ),
                    ],
                  )
                      .animate()
                      .fadeIn(delay: 450.ms, duration: 450.ms),

                  const Spacer(flex: 1),

                  // ── Bottom Corporate Footer ───────────────────────────────
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(
                      '360 CORP • v2.4.0',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 550.ms, duration: 400.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
