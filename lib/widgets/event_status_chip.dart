import 'package:flutter/material.dart';
import '../models/models.dart';

// Lifecycle status chip shown on event cards: status above the price.
// Compact by design (icon only for Live) so it fits small grid cards.
class EventStatusChip extends StatelessWidget {
  final EventLifecycle lifecycle;
  const EventStatusChip({super.key, required this.lifecycle});

  @override
  Widget build(BuildContext context) {
    switch (lifecycle) {
      case EventLifecycle.cancelled:
        return _chip(const Color(0xFF424242), 'Cancelled');
      case EventLifecycle.closed:
        return _chip(const Color(0xFF9E9E9E), 'Closed');
      case EventLifecycle.live:
        return _chip(const Color(0xFFE53935), 'Live', withIcon: true);
      case EventLifecycle.active:
        return _chip(const Color(0xFF10B981), 'Active');
    }
  }

  Widget _chip(Color bg, String label, {bool withIcon = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (withIcon) ...[
            const Icon(Icons.circle, size: 7, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}