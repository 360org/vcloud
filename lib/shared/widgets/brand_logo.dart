import 'package:flutter/material.dart';

/// App Brand Logo rendering the exact logo image asset from assets/branding/world360-logo.png
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 56,
    this.fit = BoxFit.contain,
    this.showCompanyText = false,
    this.semanticLabel = '360 CORP',
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
      filterQuality: FilterQuality.high,
    );
  }
}

/// Standalone icon representation if needed.
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
