import 'package:flutter/material.dart';

/// Official world360 Vua hệ thống logo matching https://vuahethong.net
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 48,
    this.fit = BoxFit.contain,
    this.showCompanyText = true,
    this.semanticLabel = 'world360 Vua hệ thống',
  });

  static const assetPath = 'assets/branding/world360-logo.png';

  final double height;
  final BoxFit fit;
  final bool showCompanyText;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: height,
      fit: fit,
      semanticLabel: semanticLabel,
      errorBuilder: (context, error, stackTrace) => _World360VectorLogo(height: height),
    );
  }
}

/// Vector fallback matching the exact branding of https://vuahethong.net
class _World360VectorLogo extends StatelessWidget {
  const _World360VectorLogo({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Green & Blue Globe Icon with Orbital Ring
        Container(
          width: height * 0.82,
          height: height * 0.82,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF00A859), Color(0xFF0066CC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.language,
              color: Colors.white,
              size: height * 0.52,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'world',
                    style: TextStyle(
                      color: const Color(0xFF0066CC),
                      fontSize: height * 0.42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  TextSpan(
                    text: '360',
                    style: TextStyle(
                      color: const Color(0xFF00A859),
                      fontSize: height * 0.42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Vua hệ thống',
              style: TextStyle(
                color: const Color(0xFF00A859),
                fontSize: height * 0.22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
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
