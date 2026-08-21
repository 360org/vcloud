import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Lightweight, high-performance fireworks & confetti celebration overlay.
/// Triggers vibrant colorful bursts and falling confetti particles when 8h work is reached.
class CelebrationFireworksOverlay extends StatefulWidget {
  const CelebrationFireworksOverlay({
    super.key,
    required this.child,
    this.autoTrigger = false,
  });

  final Widget child;
  final bool autoTrigger;

  static void trigger(BuildContext context) {
    final state = context.findAncestorStateOfType<_CelebrationFireworksOverlayState>();
    state?.fire();
  }

  @override
  State<CelebrationFireworksOverlay> createState() => _CelebrationFireworksOverlayState();
}

class _CelebrationFireworksOverlayState extends State<CelebrationFireworksOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();
  bool _hasAutoTriggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..addListener(() {
        setState(() {
          for (final p in _particles) {
            p.update();
          }
        });
      });

    if (widget.autoTrigger) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        fire();
      });
    }
  }

  @override
  void didUpdateWidget(CelebrationFireworksOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoTrigger && !_hasAutoTriggered) {
      _hasAutoTriggered = true;
      fire();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void fire() {
    _particles.clear();
    final colors = [
      AppColors.primary,
      AppColors.success,
      const Color(0xFFFFD700), // Gold
      const Color(0xFFFF4081), // Pink
      const Color(0xFF00E5FF), // Cyan
      const Color(0xFFAA00FF), // Violet
      const Color(0xFFFF6D00), // Orange
    ];

    // Spawn 2 fireworks bursts + 50 confetti rain particles
    for (int i = 0; i < 75; i++) {
      final isBurst = i < 35;
      final startX = isBurst
          ? (i % 2 == 0 ? 0.3 : 0.7) + (_random.nextDouble() * 0.1 - 0.05)
          : _random.nextDouble();
      final startY = isBurst ? 0.35 + (_random.nextDouble() * 0.1) : -0.05;

      final angle = isBurst ? _random.nextDouble() * 2 * math.pi : math.pi / 2 + (_random.nextDouble() - 0.5);
      final speed = isBurst ? 4.0 + _random.nextDouble() * 9.0 : 2.0 + _random.nextDouble() * 5.0;

      _particles.add(
        _Particle(
          x: startX,
          y: startY,
          vx: math.cos(angle) * speed * (isBurst ? 0.003 : 0.0015),
          vy: math.sin(angle) * speed * (isBurst ? 0.003 : 0.002) - (isBurst ? 0.004 : 0.0),
          color: colors[_random.nextInt(colors.length)],
          size: 4.0 + _random.nextDouble() * 7.0,
          rotation: _random.nextDouble() * 2 * math.pi,
          vRot: (_random.nextDouble() - 0.5) * 0.2,
          isStar: _random.nextBool(),
          gravity: isBurst ? 0.00015 : 0.0001,
        ),
      );
    }

    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_controller.isAnimating)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _FireworksPainter(
                  particles: _particles,
                  progress: _controller.value,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.rotation,
    required this.vRot,
    required this.isStar,
    required this.gravity,
  });

  double x;
  double y;
  double vx;
  double vy;
  final Color color;
  final double size;
  double rotation;
  final double vRot;
  final bool isStar;
  final double gravity;
  double opacity = 1.0;

  void update() {
    x += vx;
    y += vy;
    vy += gravity;
    rotation += vRot;
    opacity = (1.0 - (y > 0.8 ? (y - 0.8) * 4 : 0.0)).clamp(0.0, 1.0);
  }
}

class _FireworksPainter extends CustomPainter {
  _FireworksPainter({required this.particles, required this.progress});

  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final fadeOut = (1.0 - progress).clamp(0.0, 1.0);

    for (final p in particles) {
      final px = p.x * size.width;
      final py = p.y * size.height;
      final alpha = (p.opacity * fadeOut * 255).clamp(0, 255).toInt();
      if (alpha <= 0) continue;

      final paint = Paint()
        ..color = p.color.withAlpha(alpha)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rotation);

      if (p.isStar) {
        // Draw 4-point sparkle star
        final path = Path();
        final s = p.size;
        path.moveTo(0, -s);
        path.quadraticBezierTo(0, 0, s, 0);
        path.quadraticBezierTo(0, 0, 0, s);
        path.quadraticBezierTo(0, 0, -s, 0);
        path.quadraticBezierTo(0, 0, 0, -s);
        canvas.drawPath(path, paint);
      } else {
        // Draw confetti ribbon
        canvas.drawRRect(
          RRect.fromLTRBR(-p.size / 2, -p.size / 4, p.size / 2, p.size / 4, const Radius.circular(2)),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _FireworksPainter oldDelegate) => true;
}
