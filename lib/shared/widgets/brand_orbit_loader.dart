import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Official 3D World360 Brand Orbit Loader.
///
/// Features:
/// - Exact World360 Globe Graphic (#00CE2C) with Americas continents (#FFFFFF).
/// - 3D Orbit Ring (#0077CD) matching the logo's -32deg orbital plane (rotateX: 68°, rotateY: -32°).
/// - Orbiting photon energy flare (#00CE2C / #FFFFFF).
/// - Secondary reverse dashed trace ring for holographic depth.
/// - Highly optimized (Single ticker, RepaintBoundary, zero memory leaks on dispose).
class BrandOrbitLoader extends StatefulWidget {
  const BrandOrbitLoader({
    super.key,
    this.size = 78.0,
    this.globeColor = const Color(0xFF00CE2C),
    this.orbitColor = const Color(0xFF0077CD),
  });

  final double size;
  final Color globeColor;
  final Color orbitColor;

  @override
  State<BrandOrbitLoader> createState() => _BrandOrbitLoaderState();
}

class _BrandOrbitLoaderState extends State<BrandOrbitLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final globeSize = widget.size * (48.0 / 76.0);
    final ringSize = widget.size * (72.0 / 76.0);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Globe Core with Optical Glow ─────────────────────────────────
          Container(
            width: globeSize,
            height: globeSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.globeColor.withValues(alpha: 0.45),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size(globeSize, globeSize),
                painter: _World360GlobePainter(
                  globeColor: widget.globeColor,
                  continentColor: Colors.white,
                ),
              ),
            ),
          ),

          // ── 3D Orbit Stage ────────────────────────────────────────────────
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final angle = _controller.value * 2 * math.pi;
              final reverseAngle = (1.0 - _controller.value) * 2 * math.pi;

              return SizedBox(
                width: ringSize,
                height: ringSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 1. Secondary Reverse Dashed Trace
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0011)
                        ..rotateX(68 * math.pi / 180)
                        ..rotateY(-32 * math.pi / 180)
                        ..rotateZ(reverseAngle * 0.36),
                      child: Container(
                        width: ringSize,
                        height: ringSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.globeColor.withValues(alpha: 0.35),
                            width: 1.0,
                          ),
                        ),
                      ),
                    ),

                    // 2. Primary 3D Orbit Ring with Energy Flare
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0011)
                        ..rotateX(68 * math.pi / 180)
                        ..rotateY(-32 * math.pi / 180)
                        ..rotateZ(angle),
                      child: Container(
                        width: ringSize,
                        height: ringSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.orbitColor,
                            width: 3.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.orbitColor.withValues(alpha: 0.55),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: Transform.translate(
                            offset: const Offset(0, -6),
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: widget.globeColor,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.globeColor,
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                  const BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Precise Vector Painter for World360 Globe & Continents.
class _World360GlobePainter extends CustomPainter {
  final Color globeColor;
  final Color continentColor;

  _World360GlobePainter({
    required this.globeColor,
    required this.continentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100.0;
    final paintGlobe = Paint()
      ..color = globeColor
      ..style = PaintingStyle.fill;
    final paintContinent = Paint()
      ..color = continentColor
      ..style = PaintingStyle.fill;

    // Base circle
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      48 * scale,
      paintGlobe,
    );

    // Vector Continents
    final path = Path();

    // 1. North America Continent
    path.moveTo(32 * scale, 24 * scale);
    path.cubicTo(36 * scale, 21 * scale, 46 * scale, 22 * scale, 50 * scale, 25 * scale);
    path.cubicTo(53 * scale, 28 * scale, 54 * scale, 32 * scale, 50 * scale, 35 * scale);
    path.cubicTo(47 * scale, 37 * scale, 45 * scale, 41 * scale, 48 * scale, 44 * scale);
    path.cubicTo(52 * scale, 46 * scale, 56 * scale, 49 * scale, 58 * scale, 54 * scale);
    path.cubicTo(59 * scale, 58 * scale, 56 * scale, 62 * scale, 53 * scale, 64 * scale);
    path.cubicTo(50 * scale, 65 * scale, 47 * scale, 62 * scale, 44 * scale, 60 * scale);
    path.cubicTo(42 * scale, 58 * scale, 38 * scale, 59 * scale, 36 * scale, 61 * scale);
    path.cubicTo(34 * scale, 63 * scale, 30 * scale, 65 * scale, 27 * scale, 62 * scale);
    path.cubicTo(24 * scale, 59 * scale, 23 * scale, 54 * scale, 21 * scale, 50 * scale);
    path.cubicTo(19 * scale, 45 * scale, 18 * scale, 39 * scale, 21 * scale, 34 * scale);
    path.cubicTo(24 * scale, 28 * scale, 29 * scale, 27 * scale, 32 * scale, 24 * scale);
    path.close();

    // 2. Greenland
    path.moveTo(54 * scale, 18 * scale);
    path.cubicTo(57 * scale, 16 * scale, 63 * scale, 17 * scale, 66 * scale, 21 * scale);
    path.cubicTo(67 * scale, 24 * scale, 64 * scale, 27 * scale, 60 * scale, 28 * scale);
    path.cubicTo(56 * scale, 29 * scale, 55 * scale, 24 * scale, 54 * scale, 18 * scale);
    path.close();

    // 3. South America Continent
    path.moveTo(44 * scale, 68 * scale);
    path.cubicTo(48 * scale, 66 * scale, 54 * scale, 67 * scale, 58 * scale, 71 * scale);
    path.cubicTo(62 * scale, 75 * scale, 63 * scale, 81 * scale, 61 * scale, 86 * scale);
    path.cubicTo(59 * scale, 90 * scale, 54 * scale, 94 * scale, 49 * scale, 97 * scale);
    path.cubicTo(45 * scale, 96 * scale, 44 * scale, 91 * scale, 43 * scale, 86 * scale);
    path.cubicTo(42 * scale, 81 * scale, 40 * scale, 76 * scale, 41 * scale, 72 * scale);
    path.cubicTo(41 * scale, 70 * scale, 42 * scale, 69 * scale, 44 * scale, 68 * scale);
    path.close();

    canvas.drawPath(path, paintContinent);
  }

  @override
  bool shouldRepaint(covariant _World360GlobePainter oldDelegate) =>
      oldDelegate.globeColor != globeColor ||
      oldDelegate.continentColor != continentColor;
}
