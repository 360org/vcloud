import 'package:flutter/material.dart';

/// App Brand Icon matching Image 2 specifications:
/// Royal blue rounded square with white cloud outline and V_Cloud text inside.
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
    final radius = borderRadius ?? (size * 0.28);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0277FA),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x280277FA),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size * 0.78,
              height: size * 0.78,
              child: CustomPaint(
                painter: _CloudLogoPainter(),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(top: size * 0.04),
              child: Text(
                'V_Cloud',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CustomPainter drawing thick white cloud outline matching Image 2.
class _CloudLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.082
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.24, h * 0.66);
    // Left arc
    path.cubicTo(w * 0.08, h * 0.66, w * 0.08, h * 0.44, w * 0.24, h * 0.44);
    // Top-left arc
    path.cubicTo(w * 0.24, h * 0.24, w * 0.48, h * 0.18, w * 0.54, h * 0.30);
    // Top-right arc
    path.cubicTo(w * 0.66, h * 0.20, w * 0.84, h * 0.32, w * 0.78, h * 0.48);
    // Right arc
    path.cubicTo(w * 0.94, h * 0.48, w * 0.94, h * 0.66, w * 0.78, h * 0.66);
    // Bottom curve
    path.cubicTo(w * 0.65, h * 0.62, w * 0.37, h * 0.62, w * 0.24, h * 0.66);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Full Brand Logo with BrandIcon and 360 CORP branding.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 56,
    this.showCompanyText = true,
    this.fit = BoxFit.contain,
    this.semanticLabel = 'V_Cloud 360 CORP',
  });

  final double height;
  final bool showCompanyText;
  final BoxFit fit;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BrandIcon(size: height, borderRadius: height * 0.28),
        if (showCompanyText) ...[
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'V_Cloud',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: height * 0.38,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                '360 CORP',
                style: TextStyle(
                  color: Color(0xFF0277FA),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
