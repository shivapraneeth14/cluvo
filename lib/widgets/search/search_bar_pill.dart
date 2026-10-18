import 'package:flutter/material.dart';
import '../../theme.dart';

/// Shared Hero tag linking the Home search capsule to the Search screen's
/// field. Flutter's Hero supports flying across nested navigators as long as
/// the source route is a current `PageRoute`, so this works with the shell's
/// branch navigator even though `/search` is pushed on the root navigator.
const String kSearchHeroTag = 'cluvo-search-bar';

const String kSearchHint = 'Search events, artists, venues...';

/// A white, pill-shaped search surface used both as the Home capsule and as
/// the Search screen's header field so the Hero morph is seamless.
class SearchBarPill extends StatelessWidget {
  final Widget child;
  final Widget? trailing;
  final double height;
  final double leadingPadding;

  const SearchBarPill({
    super.key,
    required this.child,
    this.trailing,
    this.height = 56,
    this.leadingPadding = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: [
          BoxShadow(
            color: CluvoTheme.deepNavy.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(width: leadingPadding),
          const Icon(Icons.search, size: 22, color: CluvoTheme.primary),
          const SizedBox(width: 12),
          Expanded(child: child),
          if (trailing != null) trailing! else SizedBox(width: leadingPadding),
        ],
      ),
    );
  }
}

/// Shuttle rendered mid-flight by both [Hero]s. It intentionally matches the
/// Search screen's empty field (plain white pill + hint) so nothing "pops"
/// when the real text field settles.
Widget searchPillShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  return Material(
    type: MaterialType.transparency,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(CluvoTheme.radiusPill),
        boxShadow: [
          BoxShadow(
            color: CluvoTheme.deepNavy.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: const Row(
        children: [
          Icon(Icons.search, size: 22, color: CluvoTheme.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              kSearchHint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: CluvoTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
