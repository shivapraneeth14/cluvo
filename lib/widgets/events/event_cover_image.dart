import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme.dart';

/// Shared event artwork with a consistent gradient + initial fallback. Callers
/// pass explicit dimensions so cards never shift while the image loads.
class EventCoverImage extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const EventCoverImage({
    super.key,
    required this.imageUrl,
    required this.title,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final image = hasImage
        ? CachedNetworkImage(
            imageUrl: imageUrl!,
            width: width,
            height: height,
            fit: fit,
            placeholder: (_, _) => _fallback(),
            errorWidget: (_, _, _) => _fallback(),
          )
        : _fallback();

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: SizedBox(width: width, height: height, child: image),
    );
  }

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: CluvoTheme.borderLavender,
          width: CluvoTheme.hairline,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        title.isNotEmpty ? title[0].toUpperCase() : 'E',
        style: const TextStyle(
          color: CluvoTheme.textPrimaryColor,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
