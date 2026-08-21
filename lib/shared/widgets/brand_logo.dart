import 'package:flutter/material.dart';

/// Official world360 / Vua hệ thống brand logo widget.
///
/// ## Asset Rule (Project Standard)
/// - **Primary**: `assets/branding/brand_logo.png`
///   → 800×258 px, RGBA, 39 KB
///   → Source: Odoo API `/web/image/res.company/1/logo` (SVG) converted to PNG
///   → Updated by running: `python3 tools/sync_brand_logo.py`
/// - **Fallback**: `assets/branding/brand_logo_fallback.png`
///   → 1289×393 px, RGBA, 301 KB
///   → Hand-crafted transparent PNG — used when primary is unavailable
///
/// Usage:
/// ```dart
/// const BrandLogo(height: 85)           // login / signup
/// const BrandLogo(height: 60)           // app bar / profile
/// const BrandIcon(size: 48)             // icon-only contexts
/// ```
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 80,
    this.width,
    this.fit = BoxFit.contain,
    this.semanticLabel = 'Vcloud',
  });

  /// ★ SINGLE SOURCE OF TRUTH — only this constant references the logo asset.
  static const String assetPath = 'branding/brand_logo.png';
  static const String fallbackAssetPath = 'branding/brand_logo_fallback.png';

  final double height;
  final double? width;
  final BoxFit fit;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: Image.asset(
        assetPath,
        height: height,
        width: width,
        fit: fit,
        semanticLabel: semanticLabel,
        errorBuilder: (_, e, st) => Image.asset(
          fallbackAssetPath,
          height: height,
          width: width,
          fit: fit,
          semanticLabel: semanticLabel,
        ),
      ),
    );
  }
}

/// Convenience wrapper — renders BrandLogo as a square icon.
class BrandIcon extends StatelessWidget {
  const BrandIcon({
    super.key,
    this.size = 64,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return BrandLogo(height: size);
  }
}
