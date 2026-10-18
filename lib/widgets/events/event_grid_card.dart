import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme.dart';
import '../../models/models.dart';
import '../../providers/wishlist_provider.dart';
import '../event_status_chip.dart';
import '../wishlist_button.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Image-led event card for the two-column grids: the image fills most of the
/// card, the price and date badges float directly on the photo, and the title
/// sits below in serif type. Set [showCommunity] to add the owning community
/// name (used on catalogue grids that span many communities).
class EventGridCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  final bool showCommunity;

  const EventGridCard({
    super.key,
    required this.event,
    required this.onTap,
    this.showCommunity = false,
  });

  @override
  Widget build(BuildContext context) {
    final lifecycle = event.lifecycle();
    final dormant =
        lifecycle == EventLifecycle.closed ||
        lifecycle == EventLifecycle.cancelled;
    final imageUrl = event.imageUrl;

    return Opacity(
      opacity: dormant ? 0.55 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => _fallback(event.title),
                          )
                        : _fallback(event.title),
                    // subtle bottom scrim so badges stay legible
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black45],
                          stops: [0.6, 1.0],
                        ),
                      ),
                    ),
                    // Date badge, top-left
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${event.startDate.day} ${_months[event.startDate.month - 1]}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF171717),
                          ),
                        ),
                      ),
                    ),
                    // Status chip above the price badge, bottom-right
                    Positioned(
                      bottom: 34,
                      right: 8,
                      child: EventStatusChip(lifecycle: lifecycle),
                    ),
                    // Price badge, bottom-right
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: event.price > 0
                              ? CluvoTheme.primary
                              : const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          event.price > 0
                              ? '₹${(event.price / 100).toStringAsFixed(0)}'
                              : 'Free',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Wishlist save toggle, top-right
                    Positioned(
                      top: 8,
                      right: 8,
                      child: WishlistButton(type: wishlistEvent, id: event.id),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              event.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: context.cluvoTextPrimary,
              ),
            ),
            if (showCommunity &&
                event.communityName != null &&
                event.communityName!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                event.communityName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: context.cluvoTextSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fallback(String title) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [CluvoTheme.primary, CluvoTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0].toUpperCase() : 'E',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
