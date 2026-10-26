import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../utils/category_icons.dart';

/// Horizontal row of search pills for popular categories / searches.
class TrendingPills extends StatelessWidget {
  final List<String> items;
  final void Function(String value) onTap;

  const TrendingPills({super.key, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: CluvoTheme.screenPadding,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final label = items[i];
          return GestureDetector(
            onTap: () => onTap(label),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.cluvoSurface,
                borderRadius: BorderRadius.circular(CluvoTheme.radiusPill),
                border: Border.all(color: context.cluvoBorder),
              ),
              child: Row(
                children: [
                  Icon(
                    categoryIcon(label),
                    size: 15,
                    color: CluvoTheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.cluvoTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
