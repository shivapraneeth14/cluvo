import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import '../providers/wishlist_provider.dart';
import '../utils.dart';
import '../widgets/list_page_scaffold.dart';

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  String _tab = wishlistEvent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(wishlistProvider).loaded) {
        ref.read(wishlistProvider.notifier).load();
      }
    });
  }

  Future<void> _refresh() async {
    final notifier = ref.read(wishlistProvider.notifier);
    if (notifier.isLoaded) {
      await notifier.load();
    }
    ref.invalidate(wishlistEventsProvider);
    ref.invalidate(wishlistCommunitiesProvider);
    await ref.read(
      _tab == wishlistEvent
          ? wishlistEventsProvider.future
          : wishlistCommunitiesProvider.future,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wishlist = ref.watch(wishlistProvider);

    return ListPageScaffold(
      title: 'Wishlist',
      onRefresh: _refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _tabButton('Communities', wishlistCommunity),
              const SizedBox(width: 28),
              _tabButton('Events', wishlistEvent),
            ],
          ),
          const SizedBox(height: 16),
          if (!wishlist.loaded)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_tab == wishlistCommunity)
            _buildCommunities()
          else
            _buildEvents(),
        ],
      ),
    );
  }

  Widget _tabButton(String label, String tab) {
    final selected = _tab == tab;
    return GestureDetector(
      onTap: () => setState(() => _tab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? CluvoTheme.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color:
                selected ? context.cluvoTextPrimary : context.cluvoTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEvents() {
    final events = ref.watch(wishlistEventsProvider);
    return events.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => EmptyState(
        icon: Icons.bookmark_outline,
        message: 'Could not load saved events.\n$e',
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.bookmark_outline,
            message:
                'No saved events yet — tap the bookmark icon on any event.',
          );
        }
        return Column(
          children: [
            for (final e in items)
              ActivityCard(
                leading: _thumb(e.imageUrl, Icons.event_outlined),
                title: e.title,
                subtitle:
                    '${e.communityName ?? 'Event'} · ${formatDate(e.startDate.toIso8601String())}',
                onTap: () => context.push('/events/${e.id}'),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCommunities() {
    final communities = ref.watch(wishlistCommunitiesProvider);
    return communities.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => EmptyState(
        icon: Icons.bookmark_outline,
        message: 'Could not load saved communities.\n$e',
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.bookmark_outline,
            message:
                'No saved communities yet — tap the bookmark icon on any community.',
          );
        }
        return Column(
          children: [
            for (final c in items)
              ActivityCard(
                leading: _thumb(c.bannerUrl, Icons.groups_outlined),
                title: c.name,
                subtitle:
                    '${c.memberCount} members${c.city != null ? ' · ${c.city}' : ''}',
                onTap: () => context.push('/communities/${c.id}'),
              ),
          ],
        );
      },
    );
  }

  Widget _thumb(String? url, IconData fallbackIcon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 44,
        height: 44,
        child: url != null && url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _thumbFallback(fallbackIcon),
              )
            : _thumbFallback(fallbackIcon),
      ),
    );
  }

  Widget _thumbFallback(IconData icon) {
    return Container(
      color: CluvoTheme.primary.withValues(alpha: 0.1),
      child: Icon(icon, color: CluvoTheme.primary, size: 22),
    );
  }
}
