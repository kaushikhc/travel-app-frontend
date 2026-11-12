import 'package:flutter/material.dart';

/// Single source for the app's name and logo, so screens never hard-code them.
/// The name is a working name (trademark check pending).
class AppBrand {
  const AppBrand._();

  static const String name = 'Trailmark';
  static const String logoAsset = 'assets/images/trailmark_logo.png';
}

/// The Trailmark logo (the same artwork as the launcher icon).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.225),
      child: Image.asset(
        AppBrand.logoAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: '${AppBrand.name} logo',
      ),
    );
  }
}
