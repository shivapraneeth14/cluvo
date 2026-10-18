import 'package:flutter/material.dart';
import '../../theme.dart';

/// White outlined card grouping the primary discovery filters (date, distance,
/// price) so they read as one intentional module.
class QuickFilters extends StatelessWidget {
  final String dateLabel;
  final String distanceLabel;
  final String priceLabel;
  final bool dateActive;
  final bool distanceActive;
  final bool priceActive;
  final VoidCallback onDateTap;
  final VoidCallback onDistanceTap;
  final VoidCallback onPriceTap;

  const QuickFilters({
    super.key,
    required this.dateLabel,
    required this.distanceLabel,
    required this.priceLabel,
    required this.dateActive,
    required this.distanceActive,
    required this.priceActive,
    required this.onDateTap,
    required this.onDistanceTap,
    required this.onPriceTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: CluvoTheme.screenPadding),
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
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: CluvoTheme.borderLavender,
                    width: CluvoTheme.hairline,
                  ),
                ),
                child: const Icon(
                  Icons.tune,
                  color: CluvoTheme.textPrimaryColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Quick filters',
                style: TextStyle(
                  color: CluvoTheme.textPrimaryColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(left: 40),
            child: Text(
              'Narrow down by date, distance and price',
              style: TextStyle(
                color: CluvoTheme.textSecondaryColor,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FilterPill(
                icon: Icons.calendar_today,
                label: dateLabel,
                active: dateActive,
                onTap: onDateTap,
              ),
              _FilterPill(
                icon: Icons.near_me_outlined,
                label: distanceLabel,
                active: distanceActive,
                onTap: onDistanceTap,
              ),
              _FilterPill(
                icon: Icons.local_offer_outlined,
                label: priceLabel,
                active: priceActive,
                onTap: onPriceTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: active ? CluvoTheme.textPrimaryColor : Colors.white,
          borderRadius: BorderRadius.circular(CluvoTheme.radiusPill),
          border: Border.all(
            color: CluvoTheme.borderLavender,
            width: active ? 1 : CluvoTheme.hairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: active ? Colors.white : CluvoTheme.textPrimaryColor,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : CluvoTheme.textPrimaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: active
                  ? Colors.white.withValues(alpha: 0.7)
                  : CluvoTheme.textSecondaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
