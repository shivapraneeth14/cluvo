import 'package:flutter/material.dart';
import '../../theme.dart';

/// Horizontally scrolling category filter chips derived from real category
/// data. Includes an "All" option that clears the filter.
class CommunityCategoryChips extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const CommunityCategoryChips({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: CluvoTheme.screenPadding,
        ),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _chip(context, label: 'All', value: null, isAll: true);
          }
          final category = categories[index - 1];
          return _chip(context, label: category, value: category);
        },
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required String? value,
    bool isAll = false,
  }) {
    final active = isAll ? selected == null : selected == value;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? CluvoTheme.primary : context.cluvoSurface,
          borderRadius: BorderRadius.circular(CluvoTheme.radiusPill),
          border: Border.all(
            color: active ? CluvoTheme.primary : context.cluvoBorder,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? Colors.white : context.cluvoTextPrimary,
          ),
        ),
      ),
    );
  }
}
