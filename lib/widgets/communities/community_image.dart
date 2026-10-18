import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/models.dart';
import '../../theme.dart';

/// Renders a real community image (banner, else avatar) with a white outlined
/// initials fallback. Never fabricates imagery.
class CommunityImage extends StatelessWidget {
  final Community community;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final BoxFit fit;

  const CommunityImage({
    super.key,
    required this.community,
    this.width = double.infinity,
    this.height = double.infinity,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final url = community.bannerUrl?.isNotEmpty == true
        ? community.bannerUrl
        : (community.communityAvatarUrl?.isNotEmpty == true
              ? community.communityAvatarUrl
              : null);

    if (url == null) return _fallback();

    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        errorWidget: (_, _, _) => _fallback(),
      ),
    );
  }

  Widget _fallback() {
    final initial = community.name.isNotEmpty
        ? community.name[0].toUpperCase()
        : 'C';
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
        border: Border.all(
          color: CluvoTheme.borderLavender,
          width: CluvoTheme.hairline,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: CluvoTheme.textPrimaryColor,
          fontSize: 40,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
