import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../theme.dart';
import '../../utils.dart';
import 'event_cover_image.dart';

/// Large editorial card highlighting a single eligible event.
class SpotlightEventCard extends StatefulWidget {
  final Event event;

  const SpotlightEventCard({super.key, required this.event});

  @override
  State<SpotlightEventCard> createState() => _SpotlightEventCardState();
}

class _SpotlightEventCardState extends State<SpotlightEventCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final hasLocation = event.location != null && event.location!.isNotEmpty;
    final lifecycle = event.lifecycle();
    final closedLike =
        lifecycle == EventLifecycle.closed ||
        lifecycle == EventLifecycle.cancelled;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => context.push('/events/${event.id}'),
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AnimatedScale(
                scale: _pressed ? 1.06 : 1.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: EventCoverImage(
                  imageUrl: event.imageUrl,
                  title: event.title,
                  width: double.infinity,
                  height: 280,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        CluvoTheme.deepNavy.withValues(alpha: 0.85),
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            if (event.category != null && event.category!.isNotEmpty)
              Positioned(
                left: 16,
                top: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: CluvoTheme.electricViolet,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    event.category!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _meta(
                    context,
                    Icons.calendar_today_outlined,
                    formatDayDate(event.startDate.toIso8601String()),
                  ),
                  if (hasLocation) ...[
                    const SizedBox(height: 6),
                    _meta(context, Icons.place_outlined, event.location!),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        event.price > 0
                            ? formatRupees(event.price)
                            : 'Free entry',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: event.price > 0
                              ? Colors.white
                              : CluvoTheme.successGreen,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: closedLike
                            ? null
                            : () => context.push('/events/${event.id}'),
                        style: FilledButton.styleFrom(
                          backgroundColor: CluvoTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_forward, size: 17),
                        label: const Text(
                          'Explore event',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
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

  Widget _meta(BuildContext context, IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: context.cluvoTextSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: context.cluvoTextSecondary),
          ),
        ),
      ],
    );
  }
}
