import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 56,
    this.fit = BoxFit.contain,
    this.semanticLabel = 'world360 Vua hệ thống',
  });

  static const assetPath = 'assets/branding/world360-logo.png';

  final double height;
  final BoxFit fit;
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
