import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme.dart';
import '../../models/models.dart';
import '../notification_bell.dart';
import '../search/search_bar_pill.dart';

/// Immersive milky-white hero: brand + location + notifications on top, a
/// gradient headline, and a floating white search capsule that overlaps the
/// hero's bottom edge. Shows the featured image when one exists, otherwise the
/// solid milky fill.
class HomeHero extends StatelessWidget {
  final Event? featured;
  final String locationLabel;
  final VoidCallback onLocationTap;
  final VoidCallback onSearchTap;

  static const double _heroHeight = 312;
  static const double _overlap = 34;
  static const double _capsuleHeight = 60;

  const HomeHero({
    super.key,
    required this.featured,
    required this.locationLabel,
    required this.onLocationTap,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: _heroHeight + _overlap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _heroHeight,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
              child: _background(),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _heroHeight,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                CluvoTheme.screenPadding,
                topPadding + 10,
                CluvoTheme.screenPadding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topBar(context),
                  const Spacer(),
                  const Text(
                    'TONIGHT & THIS WEEK',
                    style: TextStyle(
                      color: CluvoTheme.textSecondaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _Headline(),
                  const SizedBox(height: _overlap + 26),
                ],
              ),
            ),
          ),
          Positioned(
            left: CluvoTheme.screenPadding,
            right: CluvoTheme.screenPadding,
            bottom: 0,
            child: _searchCapsule(context),
          ),
        ],
      ),
    );
  }

  Widget _background() {
    final image = featured?.imageUrl;
    final hasImage = image != null && image.isNotEmpty;
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: CluvoTheme.heroGradient),
        ),
        if (hasImage)
          CachedNetworkImage(
            imageUrl: image,
            fit: BoxFit.cover,
            placeholder: (_, _) => const SizedBox.shrink(),
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
        if (hasImage)
          // Milky wash so the ink text stays readable over any photo while
          // the image still reads through the middle band.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xE6F5F5F7),
                  Color(0x73F5F5F7),
                  Color(0xD9F5F5F7),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Cluvo',
                  style: TextStyle(
                    color: CluvoTheme.textPrimaryColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 3),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: CluvoTheme.primaryLight,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Find your vibe',
              style: TextStyle(
                color: CluvoTheme.textSecondaryColor,
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const Spacer(),
        _locationChip(context),
        const SizedBox(width: 8),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: CluvoTheme.borderLavender,
              width: CluvoTheme.hairline,
            ),
          ),
          alignment: Alignment.center,
          child: const IconTheme(
            data: IconThemeData(color: CluvoTheme.textPrimaryColor, size: 22),
            child: NotificationBell(),
          ),
        ),
      ],
    );
  }

  Widget _locationChip(BuildContext context) {
    return GestureDetector(
      onTap: onLocationTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(CluvoTheme.radiusPill),
          border: Border.all(
            color: CluvoTheme.borderLavender,
            width: CluvoTheme.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 15,
              color: CluvoTheme.primary,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                locationLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CluvoTheme.textPrimaryColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.expand_more,
              size: 16,
              color: CluvoTheme.textSecondaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchCapsule(BuildContext context) {
    return Hero(
      tag: kSearchHeroTag,
      flightShuttleBuilder: searchPillShuttle,
      child: Material(
        type: MaterialType.transparency,
        child: SearchBarPill(
          height: _capsuleHeight,
          child: GestureDetector(
            onTap: onSearchTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              alignment: Alignment.centerLeft,
              child: Text(
                kSearchHint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.cluvoTextSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Find your next',
          style: TextStyle(
            color: CluvoTheme.textPrimaryColor,
            fontSize: 30,
            height: 1.12,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        ShaderMask(
          shaderCallback: (bounds) =>
              CluvoTheme.headlineGradient.createShader(bounds),
          child: const Text(
            'great experience',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              height: 1.12,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }
}
