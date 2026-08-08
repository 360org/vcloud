import 'package:flutter/material.dart';

/// Official world360 services logo matching company logo specifications:
/// Green globe with blue orbital ring + "world" (green) "360°" (blue) "services" (green).
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 54,
    this.fit = BoxFit.contain,
    this.showCompanyText = true,
    this.semanticLabel = 'world360 services',
  });

  static const assetPath = 'assets/branding/world360-logo.png';

  final double height;
  final BoxFit fit;
  final bool showCompanyText;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return _World360VectorLogo(height: height);
  }
}

class _World360VectorLogo extends StatelessWidget {
  const _World360VectorLogo({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    const greenColor = Color(0xFF00D054);
    const blueColor = Color(0xFF0072CE);

    final textScale = height / 54.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Globe with 45-degree blue orbital ring
        SizedBox(
          width: height * 1.1,
          height: height,
          child: CustomPaint(
            painter: _GlobeOrbitalPainter(),
          ),
        ),
        SizedBox(width: 4 * textScale),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'world',
                  style: TextStyle(
                    color: greenColor,
                    fontSize: 28 * textScale,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1.0,
                  ),
                ),
                Text(
                  '360',
                  style: TextStyle(
                    color: blueColor,
                    fontSize: 28 * textScale,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1.0,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 14 * textScale),
                  child: Container(
                    width: 6 * textScale,
                    height: 6 * textScale,
                    decoration: BoxDecoration(
                      color: blueColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: greenColor,
                        width: 1.5 * textScale,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(left: 42 * textScale),
                child: Text(
                  'services',
                  style: TextStyle(
                    color: greenColor,
                    fontSize: 14 * textScale,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GlobeOrbitalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const greenColor = Color(0xFF00D054);
    const blueColor = Color(0xFF0072CE);

    final center = Offset(size.width * 0.46, size.height * 0.5);
    final radius = size.height * 0.38;

    // Green Globe Background
    final globePaint = Paint()
      ..color = greenColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, globePaint);

    // Simple continent landmarks inside globe
    final landPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // North America outline
    final northPath = Path()
      ..moveTo(center.dx - radius * 0.4, center.dy - radius * 0.3)
      ..cubicTo(
        center.dx - radius * 0.1, center.dy - radius * 0.6,
        center.dx + radius * 0.3, center.dy - radius * 0.4,
        center.dx + radius * 0.2, center.dy - radius * 0.1,
      )
      ..cubicTo(
        center.dx - radius * 0.1, center.dy + radius * 0.1,
        center.dx - radius * 0.3, center.dy - radius * 0.1,
        center.dx - radius * 0.4, center.dy - radius * 0.3,
      );
    canvas.drawPath(northPath, landPaint);

    // South America outline
    final southPath = Path()
      ..moveTo(center.dx - radius * 0.1, center.dy + radius * 0.15)
      ..cubicTo(
        center.dx + radius * 0.3, center.dy + radius * 0.25,
        center.dx + radius * 0.1, center.dy + radius * 0.65,
        center.dx - radius * 0.1, center.dy + radius * 0.45,
      )
      ..close();
    canvas.drawPath(southPath, landPaint);

    // Blue Orbital Ring (Tilted Oval)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.78); // -45 degrees

    final ringPaint = Paint()
      ..color = blueColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.11;

    final ringRect = Rect.fromCenter(
      center: Offset.zero,
      width: radius * 2.7,
      height: radius * 0.75,
    );

    canvas.drawOval(ringRect, ringPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BrandIcon extends StatelessWidget {
  const BrandIcon({
    super.key,
    this.size = 64,
    this.borderRadius,
  });

  final double size;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return BrandLogo(height: size);
  }
}
