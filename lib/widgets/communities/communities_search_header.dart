import 'package:flutter/material.dart';
import '../../theme.dart';

/// Compact title + subtitle + search field for the Communities page. Replaces
/// the decorative hero with a plain, reachable section as per the final layout.
class CommunitiesSearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool searching;

  const CommunitiesSearchHeader({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.searching = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CluvoTheme.screenPadding,
        12,
        CluvoTheme.screenPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find your people',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: context.cluvoTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Discover communities and connect around what you love.',
            style: TextStyle(fontSize: 13.5, color: context.cluvoTextSecondary),
          ),
          const SizedBox(height: 14),
          _searchField(context),
        ],
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(
        fontSize: 14.5,
        color: CluvoTheme.textPrimaryColor,
      ),
      decoration: InputDecoration(
        hintText: 'Search communities, interests, or cities',
        hintStyle: TextStyle(
          color: CluvoTheme.textSecondaryColor.withValues(alpha: 0.8),
          fontSize: 14,
        ),
        prefixIcon: const Icon(
          Icons.search,
          size: 20,
          color: CluvoTheme.primary,
        ),
        suffixIcon: searching
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : (controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      color: CluvoTheme.textSecondaryColor,
                      onPressed: onClear,
                    )
                  : null),
        filled: true,
        fillColor: context.cluvoChipFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CluvoTheme.radiusXl),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CluvoTheme.radiusXl),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CluvoTheme.radiusXl),
          borderSide: const BorderSide(
            color: CluvoTheme.primaryLight,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
