import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../utils/category_icons.dart';
import 'community_image.dart';
import 'community_join_button.dart';

const double kCommunityCardWidth = 208;
const double kCommunityCardHeight = 264;

/// Compact photographic card used in the "Communities to explore" carousel.
class CommunityDiscoveryCard extends StatelessWidget {
  final Community community;

  const CommunityDiscoveryCard({super.key, required this.community});

  @override
  Widget build(BuildContext context) {
    final hasImage =
        (community.bannerUrl?.isNotEmpty == true) ||
        (community.communityAvatarUrl?.isNotEmpty == true);
    final foreground = hasImage ? Colors.white : context.cluvoTextPrimary;
    final muted = hasImage
        ? Colors.white.withValues(alpha: 0.82)
        : context.cluvoTextSecondary;

    return SizedBox(
      width: kCommunityCardWidth,
      height: kCommunityCardHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.cluvoSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.cluvoBorder),
          boxShadow: [
            BoxShadow(
              color: CluvoTheme.deepNavy.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.push('/communities/${community.id}'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CommunityImage(community: community),
                  if (hasImage)
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x66000000),
                            Color(0x00000000),
                            Color(0xB3000000),
                          ],
                          stops: [0, 0.42, 1],
                        ),
                      ),
                    ),
                  if (community.category != null &&
                      community.category!.trim().isNotEmpty)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(
                            CluvoTheme.radiusPill,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              categoryIcon(community.category!),
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                community.category!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Icon(Icons.people_outline, size: 14, color: muted),
                        const SizedBox(width: 4),
                        Text(
                          '${community.memberCount} members',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                community.name,
                                maxLines: 2,
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                  color: foreground,
                                ),
                              ),
                              const SizedBox(height: 8),
                              CommunityJoinButton(
                                community: community,
                                onImage: hasImage,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dense row used for server search results.
class CommunityResultCard extends StatelessWidget {
  final Community community;

  const CommunityResultCard({super.key, required this.community});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (community.category != null && community.category!.isNotEmpty)
        community.category!,
      if (community.city != null && community.city!.isNotEmpty) community.city!,
    ].join(' · ');

    return InkWell(
      borderRadius: BorderRadius.circular(CluvoTheme.radiusCard),
      onTap: () => context.push('/communities/${community.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: context.cluvoSurface,
          borderRadius: BorderRadius.circular(CluvoTheme.radiusCard),
          border: Border.all(color: context.cluvoBorder),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CommunityImage(
                community: community,
                width: 64,
                height: 64,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    community.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.cluvoTextPrimary,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (community.category != null &&
                            community.category!.isNotEmpty) ...[
                          Icon(
                            categoryIcon(community.category!),
                            size: 12,
                            color: context.cluvoTextSecondary,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.cluvoTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 12,
                        color: context.cluvoTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${community.memberCount} members',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.cluvoTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
