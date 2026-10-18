import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/wishlist_provider.dart';
import '../../theme.dart';
import '../../utils.dart';
import '../event_status_chip.dart';
import '../wishlist_button.dart';
import 'event_cover_image.dart';

const double kEventCardWidth = 248;
const double kEventCardHeight = 296;

/// Vertical discovery card used across the Events carousels. Every field is
/// optional and rendered only when the event record actually carries it.
class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;
  final double width;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.width = kEventCardWidth,
  });

  @override
  Widget build(BuildContext context) {
    final lifecycle = event.lifecycle();
    final showStatus = lifecycle != EventLifecycle.active;
    final hasImage = event.imageUrl != null && event.imageUrl!.isNotEmpty;
    final foreground = hasImage ? Colors.white : context.cluvoTextPrimary;
    final muted = hasImage
        ? Colors.white.withValues(alpha: 0.82)
        : context.cluvoTextSecondary;
    final paidColor = hasImage ? Colors.white : CluvoTheme.primary;
    final freeColor = hasImage
        ? const Color(0xFF34D399)
        : CluvoTheme.successGreen;

    return SizedBox(
      width: width,
      height: kEventCardHeight,
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
            onTap: onTap ?? () => context.push('/events/${event.id}'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  EventCoverImage(
                    imageUrl: event.imageUrl,
                    title: event.title,
                    width: width,
                    height: kEventCardHeight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  if (hasImage)
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x73000000),
                            Color(0x00000000),
                            Color(0xB3000000),
                          ],
                          stops: [0, 0.35, 1],
                        ),
                      ),
                    ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (event.category != null &&
                            event.category!.isNotEmpty)
                          Container(
                            constraints: BoxConstraints(maxWidth: width - 60),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: CluvoTheme.deepNavy.withValues(
                                alpha: 0.72,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              event.category!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (showStatus) ...[
                          const SizedBox(height: 6),
                          EventStatusChip(lifecycle: lifecycle),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: WishlistButton(type: wishlistEvent, id: event.id),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          event.title,
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
                        const SizedBox(height: 6),
                        _metaRow(
                          Icons.calendar_today_outlined,
                          formatDayDate(event.startDate.toIso8601String()),
                          muted,
                        ),
                        if (event.location != null &&
                            event.location!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _metaRow(
                            Icons.place_outlined,
                            event.location!,
                            muted,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          event.price > 0 ? formatRupees(event.price) : 'Free',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: event.price > 0 ? paidColor : freeColor,
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

  Widget _metaRow(IconData icon, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: color),
          ),
        ),
        const SizedBox(width: 5),
        Icon(icon, size: 13, color: color),
      ],
    );
  }
}

/// Compact horizontal card used for search results and dense lists.
class EventListCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;

  const EventListCard({super.key, required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (event.category != null && event.category!.isNotEmpty) event.category!,
      if (event.communityName != null) event.communityName!,
    ].join(' · ');

    return InkWell(
      borderRadius: BorderRadius.circular(CluvoTheme.radiusCard),
      onTap: onTap ?? () => context.push('/events/${event.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: context.cluvoSurface,
          borderRadius: BorderRadius.circular(CluvoTheme.radiusCard),
          border: Border.all(color: context.cluvoBorder),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            EventCoverImage(
              imageUrl: event.imageUrl,
              title: event.title,
              width: 72,
              height: 72,
              borderRadius: BorderRadius.circular(14),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.cluvoTextPrimary,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.cluvoTextSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: context.cluvoTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          formatDayDate(
                            event.startDate.toIso8601String(),
                          ).split(' · ').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.cluvoTextSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        event.price > 0 ? formatRupees(event.price) : 'Free',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: event.price > 0
                              ? CluvoTheme.primary
                              : CluvoTheme.successGreen,
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
