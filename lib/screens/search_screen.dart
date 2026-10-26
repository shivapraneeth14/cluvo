import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import '../supabase_client.dart';
import '../models/models.dart';
import '../utils.dart';
import '../utils/category_icons.dart';
import '../providers/home_provider.dart';
import '../providers/community_provider.dart';
import '../widgets/search/search_bar_pill.dart';
import '../widgets/search/search_segmented_tabs.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchEventsProvider = FutureProvider.autoDispose<List<Event>>((
  ref,
) async {
  final q = sanitizeSearchQuery(ref.watch(searchQueryProvider));
  if (q.isEmpty) return [];
  final pattern = '%$q%';
  final res = await supabase
      .from('events')
      .select('*, communities!inner(name)')
      .isFilter('deleted_at', null)
      .eq('communities.is_hidden', false)
      .eq('status', 'published')
      .or(
        'title.ilike.$pattern,'
        'description.ilike.$pattern,'
        'location.ilike.$pattern,'
        'category.ilike.$pattern',
      )
      .order('start_date', ascending: true)
      .limit(30);
  return (res as List)
      .cast<Map<String, dynamic>>()
      .map((e) => Event.fromMap(e))
      .toList();
});

class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final TabController _tabController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery ?? '');
    _tabController = TabController(length: 2, vsync: this);
    if ((widget.initialQuery ?? '').isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(searchQueryProvider.notifier).state = widget.initialQuery!;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(searchQueryProvider.notifier).state = value.trim();
    });
  }

  void _clear() {
    _controller.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    setState(() {});
  }

  void _applySuggestion(String value) {
    _debounce?.cancel();
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    ref.read(searchQueryProvider.notifier).state = value;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      backgroundColor: context.cluvoBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CluvoTheme.screenPadding,
              ),
              child: SearchSegmentedTabs(
                controller: _tabController,
                segments: const [
                  SearchSegment(label: 'Events', icon: Icons.event_outlined),
                  SearchSegment(
                    label: 'Communities',
                    icon: Icons.groups_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: query.isEmpty
                  ? _emptyState(context)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _EventsResults(query: query),
                        _CommunitiesResults(query: query),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
            icon: Icon(Icons.arrow_back, color: context.cluvoTextPrimary),
          ),
          Expanded(
            child: Hero(
              tag: kSearchHeroTag,
              flightShuttleBuilder: searchPillShuttle,
              child: Material(
                type: MaterialType.transparency,
                child: SearchBarPill(
                  height: 54,
                  trailing: _controller.text.isEmpty
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: IconButton(
                            onPressed: _clear,
                            icon: const Icon(Icons.close, size: 18),
                            color: context.cluvoTextSecondary,
                            splashRadius: 20,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                          ),
                        ),
                  child: TextField(
                    controller: _controller,
                    autofocus: widget.initialQuery == null,
                    textInputAction: TextInputAction.search,
                    onChanged: _onChanged,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.cluvoTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: kSearchHint,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintStyle: TextStyle(
                        color: context.cluvoTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final trending = ref.watch(trendingProvider).valueOrNull ?? const [];
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CluvoTheme.screenPadding,
        28,
        CluvoTheme.screenPadding,
        24,
      ),
      children: [
        Column(
          children: [
            Icon(
              Icons.travel_explore,
              size: 44,
              color: context.cluvoTextSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              'Search events, communities and more',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.cluvoTextSecondary, fontSize: 14),
            ),
          ],
        ),
        if (trending.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text(
            'Popular right now',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.cluvoTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in trending) _suggestionChip(context, item),
            ],
          ),
        ],
      ],
    );
  }

  Widget _suggestionChip(BuildContext context, String label) {
    return GestureDetector(
      onTap: () => _applySuggestion(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: context.cluvoSurface,
          borderRadius: BorderRadius.circular(CluvoTheme.radiusPill),
          border: Border.all(color: context.cluvoBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.trending_up, size: 15, color: CluvoTheme.primary),
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
  }
}

class _EventsResults extends ConsumerWidget {
  final String query;

  const _EventsResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(searchEventsProvider);
    return async.when(
      loading: () => const _ResultsSkeleton(),
      error: (e, _) => _ResultsError(
        message: e.toString(),
        onRetry: () => ref.invalidate(searchEventsProvider),
      ),
      data: (events) {
        if (events.isEmpty) return const _NoResults();
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _EventRow(event: events[i]),
        );
      },
    );
  }
}

class _CommunitiesResults extends ConsumerWidget {
  final String query;

  const _CommunitiesResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(searchCommunitiesProvider(query));
    return async.when(
      loading: () => const _ResultsSkeleton(),
      error: (e, _) => _ResultsError(
        message: e.toString(),
        onRetry: () => ref.invalidate(searchCommunitiesProvider(query)),
      ),
      data: (communities) {
        if (communities.isEmpty) return const _NoResults();
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: communities.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _CommunityRow(community: communities[i]),
        );
      },
    );
  }
}

class _EventRow extends StatelessWidget {
  final Event event;

  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(CluvoTheme.radiusCard),
      onTap: () => context.push('/events/${event.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: context.cluvoSurface,
          borderRadius: BorderRadius.circular(CluvoTheme.radiusCard),
          border: Border.all(color: context.cluvoBorder),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            _Thumb(url: event.imageUrl, label: event.title),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.cluvoTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (event.category != null &&
                          event.category!.isNotEmpty) ...[
                        Icon(
                          categoryIcon(event.category!),
                          size: 12,
                          color: context.cluvoTextSecondary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          [
                            if (event.category != null) event.category!,
                            if (event.communityName != null)
                              event.communityName!,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.cluvoTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: context.cluvoTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatDayDate(
                          event.startDate.toIso8601String(),
                        ).split(' · ').first,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.cluvoTextSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        event.price > 0 ? formatRupees(event.price) : 'Free',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: event.price > 0
                              ? CluvoTheme.primary
                              : CluvoTheme.successGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityRow extends StatelessWidget {
  final Community community;

  const _CommunityRow({required this.community});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(CluvoTheme.radiusCard),
      onTap: () => context.push('/communities/${community.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: context.cluvoSurface,
          borderRadius: BorderRadius.circular(CluvoTheme.radiusCard),
          border: Border.all(color: context.cluvoBorder),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            _Thumb(url: community.bannerUrl, label: community.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    community.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.cluvoTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (community.category != null &&
                          community.category!.isNotEmpty) ...[
                        Icon(
                          categoryIcon(community.category!),
                          size: 12,
                          color: context.cluvoTextSecondary,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          [
                            if (community.category != null)
                              community.category!,
                            if (community.city != null) community.city!,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.cluvoTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 13,
                        color: context.cluvoTextSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${community.memberCount} members',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.cluvoTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? url;
  final String label;

  const _Thumb({required this.url, required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 72,
        height: 72,
        child: url != null && url!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: context.cluvoChipFill),
                errorWidget: (_, _, _) => _fallback(context),
              )
            : _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: CluvoTheme.borderLavender,
          width: CluvoTheme.hairline,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label.isNotEmpty ? label[0].toUpperCase() : '?',
        style: const TextStyle(
          color: CluvoTheme.textPrimaryColor,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 40, color: context.cluvoTextSecondary),
          const SizedBox(height: 12),
          Text(
            'No results found',
            style: TextStyle(color: context.cluvoTextSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ResultsError extends StatelessWidget {
  final VoidCallback onRetry;
  final String? message;

  const _ResultsError({required this.onRetry, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 40, color: context.cluvoTextSecondary),
            const SizedBox(height: 12),
            Text(
              'Could not load results.',
              style: TextStyle(color: context.cluvoTextSecondary, fontSize: 14),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.cluvoTextSecondary,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: CluvoTheme.primary,
                side: const BorderSide(color: CluvoTheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsSkeleton extends StatelessWidget {
  const _ResultsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Container(
        height: 92,
        decoration: BoxDecoration(
          color: context.cluvoSurface,
          borderRadius: BorderRadius.circular(CluvoTheme.radiusCard),
          border: Border.all(color: context.cluvoBorder),
        ),
      ),
    );
  }
}
