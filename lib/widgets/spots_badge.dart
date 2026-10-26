import 'package:flutter/material.dart';
import '../theme.dart';

class SpotsBadge extends StatelessWidget {
  final int booked;
  final int capacity;

  const SpotsBadge({
    super.key,
    required this.booked,
    required this.capacity,
  });

  @override
  Widget build(BuildContext context) {
    final full = booked >= capacity;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.groups_outlined,
            size: 16,
            color: context.cluvoTextPrimary,
          ),
          const SizedBox(width: 6),
          if (full)
            Text(
              'Event full',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: context.cluvoTextPrimary,
              ),
            )
          else
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.cluvoTextPrimary,
                ),
                children: [
                  TextSpan(
                    text: '$booked/$capacity',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: ' spots',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: context.cluvoTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
