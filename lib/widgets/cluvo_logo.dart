import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Aspect ratio of the cropped chigzo wordmark (1063 x 401).
const double kCluvoLogoAspect = 1063 / 401;

enum CluvoLogoVariant {
  /// Black wordmark for light surfaces.
  dark,

  /// White wordmark for pink/dark surfaces.
  light,
}

/// The chigzo wordmark, used everywhere the product name appears.
class CluvoLogo extends StatelessWidget {
  final CluvoLogoVariant variant;

  /// Rendered height; width follows the wordmark's aspect ratio.
  final double height;

  const CluvoLogo({
    super.key,
    this.variant = CluvoLogoVariant.dark,
    this.height = 24,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      variant == CluvoLogoVariant.light
          ? 'assets/images/logo_white.svg'
          : 'assets/images/logo.svg',
      height: height,
      width: height * kCluvoLogoAspect,
      fit: BoxFit.contain,
      semanticsLabel: 'chigzo',
      excludeFromSemantics: false,
    );
  }
}

/// App bar title that keeps the screen name and prefixes the chigzo wordmark,
/// so pushed screens still carry the brand.
class CluvoLogoTitle extends StatelessWidget {
  final String title;
  final double logoHeight;
  final TextStyle? style;

  const CluvoLogoTitle(
    this.title, {
    super.key,
    this.logoHeight = 15,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CluvoLogo(height: logoHeight),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}
