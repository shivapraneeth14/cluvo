import 'package:flutter/material.dart';
import '../../providers/home_provider.dart';
import '../../theme.dart';

/// Horizontally scrollable category chips sourced from the server-side
/// `event_category_counts` aggregate. When no real categories exist the widget
/// collapses to nothing so the section can be hidden cleanly.
class EventCategoryChips extends StatelessWidget {
  final List<CategoryCount> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final EdgeInsetsGeometry padding;

  const EventCategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(
      horizontal: CluvoTheme.screenPadding,
    ),
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _Chip(
              label: 'All',
              selected: selected == null,
              onTap: () => onSelected(null),
            );
          }
          final category = categories[index - 1];
          return _Chip(
            label: category.category,
            count: category.count,
            selected: selected == category.category,
            onTap: () => onSelected(
              selected == category.category ? null : category.category,
            ),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? CluvoTheme.primary : context.cluvoSurface,
          borderRadius: BorderRadius.circular(CluvoTheme.radiusPill),
          border: Border.all(
            color: selected ? CluvoTheme.primary : context.cluvoBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : context.cluvoTextPrimary,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.8)
                      : context.cluvoTextSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
