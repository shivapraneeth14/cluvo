import 'package:flutter/material.dart';
import '../../theme.dart';

/// Full-width promo banner pointing at genuinely free upcoming events.
class FreeEventsBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const FreeEventsBanner({super.key, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CluvoTheme.screenPadding),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(CluvoTheme.radiusCard),
            border: Border.all(
              color: CluvoTheme.borderLavender,
              width: CluvoTheme.hairline,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CluvoTheme.borderLavender,
                    width: CluvoTheme.hairline,
                  ),
                ),
                child: const Icon(
                  Icons.celebration_outlined,
                  color: CluvoTheme.textPrimaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Free events near you',
                      style: TextStyle(
                        color: CluvoTheme.textPrimaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      count == 1
                          ? '1 free event to explore'
                          : '$count free events to explore',
                      style: const TextStyle(
                        color: CluvoTheme.textSecondaryColor,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CluvoTheme.borderLavender,
                    width: CluvoTheme.hairline,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: CluvoTheme.textPrimaryColor,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
