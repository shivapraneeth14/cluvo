import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/wishlist_provider.dart';
import '../supabase_client.dart';
import '../theme.dart';

/// Visual treatment for [WishlistButton].
///
/// [WishlistButtonVariant.glass] is the original translucent dark disc used on
/// top of photography (event cards, hero overlays).
/// [WishlistButtonVariant.light] is the solid white disc required by the
/// Community Detail action bar, where controls sit on the page background.
enum WishlistButtonVariant { glass, light }

/// Small save toggle. Filled bookmark when saved, outline when not. Hidden
/// entirely when the user is not logged in (share-link views).
class WishlistButton extends ConsumerWidget {
  final String type;
  final String id;
  final double size;
  final WishlistButtonVariant variant;

  const WishlistButton({
    super.key,
    required this.type,
    required this.id,
    this.size = 32,
    this.variant = WishlistButtonVariant.glass,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (supabase.auth.currentSession == null) return const SizedBox.shrink();

    final wishlist = ref.watch(wishlistProvider);
    final saved = type == wishlistEvent
        ? wishlist.savedEvents.containsKey(id)
        : wishlist.savedCommunities.containsKey(id);

    final light = variant == WishlistButtonVariant.light;

    return Semantics(
      label: saved ? 'Remove from saved' : 'Save',
      button: true,
      child: GestureDetector(
        onTap: () => ref.read(wishlistProvider.notifier).toggle(type, id),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: light ? Colors.white : Colors.black.withValues(alpha: 0.35),
            shape: BoxShape.circle,
            border: Border.all(
              color: light
                  ? CluvoTheme.borderLavender
                  : Colors.white.withValues(alpha: 0.4),
              width: 1,
            ),
            boxShadow: light
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            saved ? Icons.bookmark : Icons.bookmark_outline,
            size: light ? size * 0.5 : size * 0.58,
            color: light
                ? (saved ? CluvoTheme.primary : CluvoTheme.textPrimaryColor)
                : (saved ? Colors.grey.shade300 : Colors.white),
          ),
        ),
      ),
    );
  }
}
