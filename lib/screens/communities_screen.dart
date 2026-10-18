import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../supabase_client.dart';
import '../providers/community_provider.dart';
import '../providers/location_provider.dart';
import '../providers/paginated_provider.dart';
import '../services/location_matching.dart';
import '../widgets/notification_bell.dart';
import '../widgets/home/section_header.dart';
import '../widgets/list_page_scaffold.dart' show ActivityCard;
import '../widgets/communities/communities_search_header.dart';
import '../widgets/communities/community_location_button.dart';
import '../widgets/communities/community_category_chips.dart';
import '../widgets/communities/community_discovery_card.dart';
import '../widgets/communities/community_image.dart';
import '../models/models.dart';

/// Communities discovery page:
/// compact header → title + search → category chips → Popular carousel →
/// Your communities. The full catalogue lives at "/communities/all".
class CommunitiesScreen extends ConsumerStatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  ConsumerState<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends ConsumerState<CommunitiesScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _query = '');
  }

  void _selectCategory(String? category) {
    if (_selectedCategory == category) return;
    setState(() => _selectedCategory = category);
    ref.read(communitiesProvider.notifier).setCategory(category);
  }

  Future<void> _refresh() async {
    ref.invalidate(categoriesProvider);
    ref.invalidate(locationOptionsProvider);
    ref.invalidate(myMembershipsProvider);
    await ref.read(communitiesProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = supabase.auth.currentSession != null;
    final searchLoading =
        _query.trim().isNotEmpty &&
        ref.watch(searchCommunitiesProvider(_query)).isLoading;

    return Scaffold(
      backgroundColor: context.cluvoBackground,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: CluvoTheme.primary,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(context)),
              SliverToBoxAdapter(
                child: CommunitiesSearchHeader(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onClear: _clearSearch,
                  searching: searchLoading,
                ),
              ),
              ...(_query.trim().isNotEmpty
                  ? _searchSlivers()
                  : [
                      ..._categoriesSliver(),
                      ..._popularSlivers(context),
                      ..._yourCommunitiesSlivers(context, signedIn),
                    ]),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(CluvoTheme.screenPadding, 10, 8, 0),
      child: Row(
        children: [
          Row(
            children: [
              Text(
                'Cluvo',
                style: TextStyle(
                  color: CluvoTheme.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 3),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: CluvoTheme.electricViolet,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const Spacer(),
          const CommunityLocationButton(),
          const NotificationBell(),
        ],
      ),
    );
  }

  // ── Categories ─────────────────────────────────────────────────────────

  List<Widget> _categoriesSliver() {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    if (categories.isEmpty) return const [];
    return [
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
      SliverToBoxAdapter(
        child: CommunityCategoryChips(
          categories: categories,
          selected: _selectedCategory,
          onSelected: _selectCategory,
        ),
      ),
    ];
  }

  // ── Popular ────────────────────────────────────────────────────────────

  List<Widget> _popularSlivers(BuildContext context) {
    final state = ref.watch(communitiesProvider);
    return [
      const SliverToBoxAdapter(
        child: SizedBox(height: CluvoTheme.sectionSpacing),
      ),
      SliverToBoxAdapter(
        child: SectionHeader(
          icon: Icons.local_fire_department_outlined,
          title: 'Popular communities',
          actionLabel: 'See all',
          onAction: () => context.push('/communities/all'),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      SliverToBoxAdapter(child: _popular(context, state)),
    ];
  }

  Widget _popular(BuildContext context, PaginatedList<Community> state) {
    if (state.loading && state.items.isEmpty) {
      return const _CarouselSkeleton();
    }
    if (state.error != null && state.items.isEmpty) {
      return _InlineCard(
        message: 'Could not load communities.',
        onRetry: () => ref.read(communitiesProvider.notifier).refresh(),
        retryLabel: 'Tap to retry',
      );
    }
    if (state.items.isEmpty) {
      return _InlineCard(
        icon: Icons.groups_outlined,
        message: _selectedCategory == null
            ? 'No communities to show yet.'
            : 'No communities in $_selectedCategory yet.',
      );
    }
    final city = ref.watch(locationControllerProvider.select((s) => s.city));
    final items = partitionLocalFirst(
      state.items,
      (c) => isCommunityLocal(c, city),
    ).take(12).toList();
    return SizedBox(
      height: kCommunityCardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: CluvoTheme.screenPadding,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) =>
            CommunityDiscoveryCard(community: items[i]),
      ),
    );
  }

  // ── Your communities ───────────────────────────────────────────────────

  List<Widget> _yourCommunitiesSlivers(BuildContext context, bool signedIn) {
    return [
      const SliverToBoxAdapter(
        child: SizedBox(height: CluvoTheme.sectionSpacing),
      ),
      SliverToBoxAdapter(
        child: SectionHeader(
          icon: Icons.groups_2_outlined,
          title: 'Your communities',
          actionLabel: signedIn ? 'See all' : null,
          onAction: signedIn ? () => context.go('/profile/communities') : null,
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      SliverToBoxAdapter(child: _yourCommunities(context, signedIn)),
    ];
  }

  Widget _yourCommunities(BuildContext context, bool signedIn) {
    if (!signedIn) {
      return const _InlineCard(
        message: 'Sign in to see and join communities.',
        icon: Icons.lock_outline,
      );
    }
    final async = ref.watch(myMembershipsProvider);
    return async.when(
      loading: () => const _RowSkeleton(),
      error: (_, _) => _InlineCard(
        message: 'Could not load your communities.',
        onRetry: () => ref.invalidate(myMembershipsProvider),
        retryLabel: 'Retry',
      ),
      data: (memberships) {
        if (memberships.isEmpty) {
          return const _InlineCard(
            icon: Icons.groups_outlined,
            message:
                'You have not joined any communities yet. Explore Popular '
                'and join one to get started.',
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CluvoTheme.screenPadding,
          ),
          child: Column(
            children: [
              for (final membership in memberships)
                _membershipRow(context, membership),
            ],
          ),
        );
      },
    );
  }

  Widget _membershipRow(BuildContext context, JoinedCommunity membership) {
    final community = membership.community;
    final role = membership.role.toUpperCase() == 'OWNER' ? 'Owner' : 'Member';
    final subtitle = [
      role,
      if (community.city != null && community.city!.isNotEmpty) community.city!,
    ].join(' · ');

    return ActivityCard(
      leading: SizedBox(
        width: 44,
        height: 44,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CommunityImage(community: community, width: 44, height: 44),
        ),
      ),
      title: community.name,
      subtitle: subtitle,
      trailing: Text(
        '${community.memberCount} members',
        style: TextStyle(fontSize: 11, color: context.cluvoTextSecondary),
      ),
      onTap: () => context.push('/communities/${community.id}'),
    );
  }

  // ── Search results ─────────────────────────────────────────────────────

  List<Widget> _searchSlivers() {
    final async = ref.watch(searchCommunitiesProvider(_query));
    final city = ref.watch(locationControllerProvider.select((s) => s.city));
    final Widget content = async.when(
      loading: () => const _RowSkeleton(),
      error: (e, _) => _InlineCard(
        message: 'Could not search communities. Please try again.',
        onRetry: () => ref.invalidate(searchCommunitiesProvider(_query)),
        retryLabel: 'Retry',
      ),
      data: (communities) {
        if (communities.isEmpty) {
          return const _InlineCard(
            icon: Icons.search_off,
            message: 'No communities match your search.',
          );
        }
        final ordered = partitionLocalFirst(
          communities,
          (c) => isCommunityLocal(c, city),
        );
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CluvoTheme.screenPadding,
          ),
          child: Column(
            children: [
              for (final community in ordered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CommunityResultCard(community: community),
                ),
            ],
          ),
        );
      },
    );

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CluvoTheme.screenPadding,
            20,
            CluvoTheme.screenPadding,
            12,
          ),
          child: Text(
            'Results for "$_query"',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.cluvoTextPrimary,
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(child: content),
    ];
  }
}

/// A centred, bordered message card that keeps one section's failure from
/// breaking the rest of the page. Optionally shows a retry action.
class _InlineCard extends StatelessWidget {
  final String message;
  final IconData? icon;
  final VoidCallback? onRetry;
  final String retryLabel;

  const _InlineCard({
    required this.message,
    this.icon,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CluvoTheme.screenPadding),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.cluvoSurface,
          borderRadius: BorderRadius.circular(CluvoTheme.radiusCard),
          border: Border.all(color: context.cluvoBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: context.cluvoTextSecondary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.cluvoTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  foregroundColor: CluvoTheme.primary,
                ),
                child: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton for the Popular carousel.
class _CarouselSkeleton extends StatelessWidget {
  const _CarouselSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kCommunityCardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: CluvoTheme.screenPadding,
        ),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, _) => Container(
          width: kCommunityCardWidth,
          decoration: BoxDecoration(
            color: context.cluvoChipFill,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

/// Skeleton for the "Your communities" rows.
class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CluvoTheme.screenPadding),
      child: Column(
        children: List.generate(
          3,
          (_) => Container(
            height: 72,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: context.cluvoChipFill,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton for the search results.
