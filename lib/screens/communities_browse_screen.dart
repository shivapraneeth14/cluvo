import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../models/models.dart';
import '../providers/community_provider.dart';
import '../providers/location_provider.dart';
import '../providers/paginated_provider.dart';
import '../services/location_matching.dart';
import '../widgets/communities/community_category_chips.dart';
import '../widgets/communities/community_discovery_card.dart';
import '../widgets/communities/community_location_button.dart';

/// The full, paginated community catalogue reached from "See all". Filters and
/// pagination are driven by the shared [communitiesProvider]; text search is
/// delegated to the server-backed Search screen.
class CommunitiesBrowseScreen extends ConsumerStatefulWidget {
  const CommunitiesBrowseScreen({super.key});

  @override
  ConsumerState<CommunitiesBrowseScreen> createState() =>
      _CommunitiesBrowseScreenState();
}

class _CommunitiesBrowseScreenState
    extends ConsumerState<CommunitiesBrowseScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 400) {
      return;
    }
    ref.read(communitiesProvider.notifier).fetchNextPage();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communitiesProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final notifier = ref.read(communitiesProvider.notifier);

    return Scaffold(
      backgroundColor: context.cluvoBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/communities');
            }
          },
        ),
        title: const Text('All communities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search communities',
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          if (categories.isNotEmpty) ...[
            CommunityCategoryChips(
              categories: categories,
              selected: notifier.category,
              onSelected: notifier.setCategory,
            ),
            const SizedBox(height: 10),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CluvoTheme.screenPadding,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: const CommunityLocationButton(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _body(state, notifier)),
        ],
      ),
    );
  }

  Widget _body(PaginatedList<Community> state, CommunitiesNotifier notifier) {
    if (state.loading && state.items.isEmpty) {
      return _buildSkeleton();
    }
    if (state.error != null && state.items.isEmpty) {
      return _buildError(notifier);
    }
    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.groups_outlined,
                  size: 48,
                  color: context.cluvoTextSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  'No communities match your filters.',
                  style: TextStyle(
                    color: context.cluvoTextSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final city = ref.watch(locationControllerProvider.select((s) => s.city));
    final items = partitionLocalFirst(
      state.items,
      (c) => isCommunityLocal(c, city),
    );

    return RefreshIndicator(
      color: CluvoTheme.primary,
      onRefresh: notifier.refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          CluvoTheme.screenPadding,
          4,
          CluvoTheme.screenPadding,
          32,
        ),
        itemCount: items.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i >= items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return CommunityResultCard(community: items[i]);
        },
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: CluvoTheme.screenPadding),
      children: List.generate(
        6,
        (_) => Container(
          height: 84,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: context.cluvoChipFill,
            borderRadius: BorderRadius.circular(CluvoTheme.radiusCard),
          ),
        ),
      ),
    );
  }

  Widget _buildError(CommunitiesNotifier notifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: context.cluvoTextSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load communities.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.cluvoTextSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: notifier.refresh,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Tap to Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: CluvoTheme.primary,
                side: const BorderSide(color: CluvoTheme.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
