import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/wishlist_provider.dart';
import '../supabase_client.dart';

/// Small glass save toggle: filled grey when saved, filled white when not.
/// Hidden entirely when the user is not logged in (share-link views).
class WishlistButton extends ConsumerWidget {
  final String type;
  final String id;
  final double size;

  const WishlistButton({
    super.key,
    required this.type,
    required this.id,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (supabase.auth.currentSession == null) return const SizedBox.shrink();

    final wishlist = ref.watch(wishlistProvider);
    final saved = type == wishlistEvent
        ? wishlist.savedEvents.containsKey(id)
        : wishlist.savedCommunities.containsKey(id);

    return GestureDetector(
      onTap: () => ref.read(wishlistProvider.notifier).toggle(type, id),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Icon(
          saved ? Icons.bookmark : Icons.bookmark_outline,
          size: size * 0.58,
          color: saved ? Colors.grey.shade300 : Colors.white,
        ),
      ),
    );
  }
}