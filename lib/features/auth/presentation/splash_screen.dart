import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/chat_v2/application/chat_v2_channels_controller.dart';
import '../../../features/home/application/home_summary_controller.dart';
import '../../../features/ticket/application/ticket_controller.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/brand_orbit_loader.dart';
import '../application/auth_controller.dart';

/// Modern executive light-themed splash screen for VCloud / Vua Hệ Thống / World360.
/// Harmonizes seamlessly with the official 3D Orbit Brand Loader & Ambient Aura design.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _isWarmingUp = false;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authState = ref.read(authControllerProvider);
      final user = authState.valueOrNull;
      if (user != null) {
        _warmupAndNavigate();
      } else if (!authState.isLoading) {
        context.go('/login');
      }
    });

    // Fail-safe 1.5s timeout: nếu mạng chậm hoặc auth state không đổi, tự động chuyển trang
    _fallbackTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      final user = ref.read(authControllerProvider).valueOrNull;
      if (user != null) {
        _warmupAndNavigate();
      } else {
        context.go('/login');
      }
    });
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _warmupAndNavigate() async {
    if (_isWarmingUp) return;
    _isWarmingUp = true;
    _fallbackTimer?.cancel();

    try {
      // Warm-up song song các core providers với timeout an toàn 800ms
      await Future.wait([
        ref.read(mobileDashboardSummaryProvider.future),
        ref.read(chatV2ChannelsProvider.future),
        ref.read(ticketsProvider.future),
      ]).timeout(const Duration(milliseconds: 800));
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
        _fallbackTimer?.cancel();
        context.go('/login');
      }
    });

    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // ── Radial Tech Background Gradient ──────────────────────────────
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.84),
                radius: 1.2,
                colors: [
                  Color(0xFFEEFBF3), // Soft Fresh Mint Peak (#eefbf3)
                  Color(0xFFF8FAFC), // Tech Slate Off-White (#f8fafc)
                  Color(0xFFFFFFFF), // Pure Crisp Base (#ffffff)
                ],
                stops: [0.0, 0.52, 1.0],
              ),
            ),
          ),

          // ── Ambient Glow 1 (Top Green-Blue Aura) ─────────────────────────
          Positioned(
            top: 40,
            left: screenWidth / 2 - 140,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00CE2C).withValues(alpha: 0.18),
                    const Color(0xFF0077CD).withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 0.75],
                ),
              ),
            )
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .scale(
                  begin: const Offset(0.92, 0.92),
                  end: const Offset(1.08, 1.08),
                  duration: 3000.ms,
                  curve: Curves.easeInOut,
                ),
          ),

          // ── Ambient Glow 2 (Bottom-Right Blue Aura) ──────────────────────
          Positioned(
            bottom: 80,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0077CD).withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),

          // ── Main Content Area ────────────────────────────────────────────
          SafeArea(
            child: SizedBox.expand(
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // ── Clean Authentic Brand Logo Hero ───────────────────────
                  Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0077CD).withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const BrandLogo(height: 70),
                  )
                      .animate()
                      .scale(
                        duration: 650.ms,
                        curve: Curves.easeOutBack,
                        begin: const Offset(0.85, 0.85),
                        end: const Offset(1.0, 1.0),
                      )
                      .fadeIn(duration: 450.ms),

                  const SizedBox(height: 18),

                  // ── Enterprise Tagline Badge ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00CE2C).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00CE2C).withValues(alpha: 0.22),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00CE2C).withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Status Indicator Dot (Pulsing green energy)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF00CE2C),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF00CE2C),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Hệ sinh thái Quản trị & Năng suất Doanh nghiệp',
                          style: TextStyle(
                            color: Color(0xFF00871D),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 250.ms, duration: 450.ms)
                      .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),

                  const Spacer(flex: 3),

                  // ── Official World360 3D Orbit Loader & Pulse Text ────────
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 3D Globe & Orbit Ring Loader
                      const BrandOrbitLoader(size: 78),
                      const SizedBox(height: 18),
                      // Pulse Status Text
                      const Text(
                        'ĐANG KẾT NỐI HỆ THỐNG...',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      )
                          .animate(
                            onPlay: (controller) => controller.repeat(reverse: true),
                          )
                          .fade(
                            begin: 0.45,
                            end: 1.0,
                            duration: 1000.ms,
                            curve: Curves.easeInOut,
                          ),
                    ],
                  )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 450.ms),

                  const Spacer(flex: 1),

                  // ── Bottom Corporate Footer ───────────────────────────────
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(
                      'WORLD360 CORP • v2.5.0',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 500.ms, duration: 400.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
