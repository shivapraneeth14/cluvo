import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../models/models.dart';
import '../providers/event_provider.dart';
import '../providers/event_discovery_provider.dart';
import '../providers/home_provider.dart';
import '../providers/location_provider.dart';
import '../services/location_matching.dart';
import '../supabase_client.dart';
import '../widgets/events/category_chips.dart';
import '../widgets/events/event_card.dart';
import '../widgets/events/events_location_button.dart';
import '../widgets/events/events_search_header.dart';
import '../widgets/events/events_skeleton.dart';
import '../widgets/events/spotlight_event_card.dart';
import '../widgets/home/section_header.dart';
import '../widgets/notification_bell.dart';
import 'search_screen.dart' show searchEventsProvider, searchQueryProvider;

/// Events discovery page:
/// compact header → title + search → category chips → Featured Event →
/// Upcoming Events → Popular Events. The full catalogue lives at "/events/all".
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  Timer? _realtimeDebounce;
  RealtimeChannel? _eventsChannel;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _eventsChannel?.unsubscribe();
    _searchController.dispose();
    _debounce?.cancel();
    _realtimeDebounce?.cancel();
    super.dispose();
  }

  void _subscribeRealtime() {
    _eventsChannel = supabase
        .channel('events-discovery')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'events',
          callback: (_) {
            _realtimeDebounce?.cancel();
            _realtimeDebounce = Timer(const Duration(seconds: 2), () {
              if (!mounted) return;
              ref.invalidate(discoveryUpcomingProvider);
              ref.invalidate(discoveryPopularProvider);
              ref.invalidate(featuredEventProvider);
              ref.invalidate(categoryCountsProvider);
            });
          },
        )
        .subscribe();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final q = value.trim();
      setState(() => _query = q);
      ref.read(searchQueryProvider.notifier).state = q;
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    setState(() => _query = '');
  }

  Future<void> _refresh() async {
    ref.invalidate(featuredEventProvider);
    ref.invalidate(categoryCountsProvider);
    ref.invalidate(discoveryUpcomingProvider);
    ref.invalidate(discoveryPopularProvider);
    ref.invalidate(locationOptionsProvider);
    if (_query.isNotEmpty) ref.invalidate(searchEventsProvider);
    await ref
        .read(discoveryUpcomingProvider.future)
        .catchError((_) => <Event>[]);
  }

  void _onCategorySelected(String? category) {
    final current = ref.read(discoveryFiltersProvider);
    final notifier = ref.read(discoveryFiltersProvider.notifier);
    notifier.state = category == null
        ? current.copyWith(clearCategory: true)
        : current.copyWith(category: category);
  }

  void _openBrowse() {
    final current = ref.read(discoveryFiltersProvider);
    ref
        .read(eventsProvider.notifier)
        .setFilters(
          category: current.category,
          freeOnly: current.freeOnly,
          date: current.date,
          priceSort: current.priceSort,
        );
    context.push('/events/all');
  }

  @override
  Widget build(BuildContext context) {
    final searchLoading =
        _query.trim().isNotEmpty && ref.watch(searchEventsProvider).isLoading;

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
                child: EventsSearchHeader(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onClear: _clearSearch,
                  searching: searchLoading,
                ),
              ),
              ...(_query.isNotEmpty
                  ? _searchSlivers(_query)
                  : [
                      ..._categorySlivers(),
                      ..._featuredSlivers(),
                      ..._nearbyPopularSlivers(),
                      ..._popularSlivers(),
                    ]),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────

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
          const EventsLocationButton(),
          const NotificationBell(),
        ],
      ),
    );
  }

  // ── Category chips ────────────────────────────────────────────────────

  List<Widget> _categorySlivers() {
    final async = ref.watch(categoryCountsProvider);
    final cats = async.valueOrNull;
    if (async.hasError) return const [];
    if (cats != null && cats.isEmpty) return const [];
    final Widget body;
    if (cats == null) {
      body = const CategoryChipsSkeleton();
    } else {
      body = EventCategoryChips(
        categories: cats,
        selected: ref.watch(discoveryFiltersProvider).category,
        onSelected: _onCategorySelected,
      );
    }
    return [
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
      SliverToBoxAdapter(child: body),
    ];
  }

  // ── Featured event ────────────────────────────────────────────────────

  List<Widget> _featuredSlivers() {
    final async = ref.watch(featuredEventProvider);
    final event = async.valueOrNull;
    if (async is AsyncData && event == null) return const [];
    final Widget body;
    if (event == null && async.isLoading) {
      body = const SpotlightSkeleton();
    } else if (event == null && async.hasError) {
      body = _InlineCard(
        message: 'Could not load the featured event.',
        onRetry: () => ref.invalidate(featuredEventProvider),
        retryLabel: 'Retry',
      );
    } else {
      body = SpotlightEventCard(event: event!);
    }
    return [
      const SliverToBoxAdapter(
        child: SizedBox(height: CluvoTheme.sectionSpacing),
      ),
      const SliverToBoxAdapter(
        child: SectionHeader(
          icon: Icons.auto_awesome_outlined,
          title: 'Featured Event',
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      SliverToBoxAdapter(child: body),
    ];
  }

  // ── Nearby popular events ──────────────────────────────────────────────

  List<Widget> _nearbyPopularSlivers() {
    final filters = ref.watch(discoveryFiltersProvider);
    return _carouselSlivers(
      async: ref.watch(nearbyPopularProvider),
      icon: Icons.near_me_outlined,
      title: 'Popular near you',
      caption: 'Sorted by distance',
      actionLabel: 'See all',
      onAction: _openBrowse,
      onRetry: () => ref.invalidate(nearbyPopularProvider),
      emptyText: filters.isEmpty
          ? 'No events near you yet.'
          : 'No events match your filters.',
    );
  }

  // ── Popular events ────────────────────────────────────────────────────

  List<Widget> _popularSlivers() {
    return _carouselSlivers(
      async: ref.watch(discoveryPopularProvider),
      icon: Icons.local_fire_department_outlined,
      title: 'Popular Events',
      caption: 'Ranked by bookings',
      onRetry: () => ref.invalidate(discoveryPopularProvider),
      hideWhenEmpty: true,
    );
  }

  // ── Shared carousel section ───────────────────────────────────────────

  List<Widget> _carouselSlivers({
    required AsyncValue<List<Event>> async,
    required IconData icon,
    required String title,
    String? caption,
    String? actionLabel,
    VoidCallback? onAction,
    required VoidCallback onRetry,
    String? emptyText,
    bool hideWhenEmpty = false,
  }) {
    final city = ref.watch(locationControllerProvider.select((s) => s.city));
    final events = async.valueOrNull;
    final ordered = events == null
        ? null
        : partitionLocalFirst(events, (e) => isEventLocal(e, city));
    if (hideWhenEmpty &&
        async is AsyncData &&
        (events == null || events.isEmpty)) {
      return const [];
    }

    final Widget body;
    if ((events == null || events.isEmpty) && async.isLoading) {
      body = const EventCarouselSkeleton();
    } else if ((events == null || events.isEmpty) && async.hasError) {
      body = _InlineCard(
        message: 'Could not load events.',
        onRetry: onRetry,
        retryLabel: 'Retry',
      );
    } else if (events == null || events.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CluvoTheme.screenPadding,
          vertical: 8,
        ),
        child: Text(
          emptyText ?? 'Nothing to show yet.',
          style: TextStyle(color: context.cluvoTextSecondary, fontSize: 14),
        ),
      );
    } else {
      body = _carousel(ordered!);
    }

    return [
      const SliverToBoxAdapter(
        child: SizedBox(height: CluvoTheme.sectionSpacing),
      ),
      SliverToBoxAdapter(
        child: SectionHeader(
          icon: icon,
          title: title,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ),
      if (caption != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              CluvoTheme.screenPadding,
              4,
              CluvoTheme.screenPadding,
              0,
            ),
            child: Text(
              caption,
              style: TextStyle(
                fontSize: 12.5,
                color: context.cluvoTextSecondary,
              ),
            ),
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      SliverToBoxAdapter(child: body),
    ];
  }

  Widget _carousel(List<Event> events) {
    return SizedBox(
      height: kEventCardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: CluvoTheme.screenPadding,
        ),
        itemCount: events.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => EventCard(event: events[i]),
      ),
    );
  }

  // ── Search results ────────────────────────────────────────────────────

  List<Widget> _searchSlivers(String query) {
    final async = ref.watch(searchEventsProvider);
    final city = ref.watch(locationControllerProvider.select((s) => s.city));
    final Widget content = async.when(
      loading: () => const EventListSkeleton(),
      error: (e, _) => _InlineCard(
        message: 'Could not load results.',
        onRetry: () => ref.invalidate(searchEventsProvider),
        retryLabel: 'Retry',
      ),
      data: (events) {
        if (events.isEmpty) {
          return _InlineCard(
            icon: Icons.search_off,
            message: 'No events match "$query".',
          );
        }
        final ordered = partitionLocalFirst(
          events,
          (e) => isEventLocal(e, city),
        );
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CluvoTheme.screenPadding,
          ),
          child: Column(
            children: [
              for (final event in ordered)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EventListCard(event: event),
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
            'Results for "$query"',
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
