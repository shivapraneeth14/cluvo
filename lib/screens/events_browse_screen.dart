import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../models/models.dart';
import '../providers/event_provider.dart';
import '../providers/home_provider.dart';
import '../providers/location_provider.dart';
import '../providers/paginated_provider.dart';
import '../supabase_client.dart';
import '../services/location_matching.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/events/category_chips.dart';
import '../widgets/events/event_grid_card.dart';
import '../widgets/events/events_skeleton.dart';
import '../widgets/list_page_scaffold.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

// Maps a concrete date to a quick-segment id, or null when it is neither today
// nor tomorrow (an explicitly picked date).
String? _segmentForDate(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  if (day == today) return 'today';
  if (day == today.add(const Duration(days: 1))) return 'tomorrow';
  return null;
}

/// The full, paginated event catalogue reached from "See all" on the Events
/// page. Filters and pagination are driven by the shared [eventsProvider]; the
/// grid mirrors the two-column layout used on community detail pages.
class EventsBrowseScreen extends ConsumerStatefulWidget {
  const EventsBrowseScreen({super.key});

  @override
  ConsumerState<EventsBrowseScreen> createState() => _EventsBrowseScreenState();
}

class _EventsBrowseScreenState extends ConsumerState<EventsBrowseScreen> {
  final _scrollController = ScrollController();
  Timer? _realtimeDebounce;
  RealtimeChannel? _eventsChannel;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _eventsChannel?.unsubscribe();
    _scrollController.dispose();
    _realtimeDebounce?.cancel();
    super.dispose();
  }

  void _subscribeRealtime() {
    _eventsChannel = supabase
        .channel('events-browse-list')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'events',
          callback: (_) {
            _realtimeDebounce?.cancel();
            _realtimeDebounce = Timer(const Duration(seconds: 2), () {
              if (mounted) ref.read(eventsProvider.notifier).refresh();
            });
          },
        )
        .subscribe();
  }

  void _onScroll() {
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 200) {
      return;
    }
    ref.read(eventsProvider.notifier).fetchNextPage();
  }

  // Number of active filters that are NOT visible as a chip (price, sort and an
  // explicit date) — shown as a badge on the Filters button.
  int _advancedCount(EventsNotifier n) {
    var count = 0;
    if (n.freeOnly || n.paidOnly) count++;
    if (n.priceSort != null || n.distanceSort != null) count++;
    if (n.date != null || n.dateFrom != null) count++;
    return count;
  }

  void _selectCategory(String? category) {
    final n = ref.read(eventsProvider.notifier);
    n.setFilters(
      freeOnly: n.freeOnly,
      paidOnly: n.paidOnly,
      priceSort: n.priceSort,
      distanceSort: n.distanceSort,
      date: n.date,
      dateFrom: n.dateFrom,
      category: category,
    );
  }

  Future<void> _openFiltersSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cluvoBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _FilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventsProvider);

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
              context.go('/events');
            }
          },
        ),
        title: const Text('All events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search events',
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: state.loading && state.items.isEmpty
          ? _buildSkeleton()
          : state.error != null && state.items.isEmpty
          ? _buildError(state.error!)
          : _buildContent(state),
    );
  }

  Widget _buildContent(PaginatedList<Event> state) {
    final city = ref.watch(locationControllerProvider.select((s) => s.city));
    final items = partitionLocalFirst(
      state.items,
      (e) => isEventLocal(e, city),
    );
    final notifier = ref.read(eventsProvider.notifier);
    final categoriesAsync = ref.watch(categoryCountsProvider);
    final activeCount = _advancedCount(notifier);

    return Column(
      children: [
        _buildFiltersBar(categoriesAsync, notifier, activeCount),
        Expanded(
          child: RefreshIndicator(
            onRefresh: notifier.refresh,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.event_busy_outlined,
                      message: _emptyMessage(),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.68,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final event = items[index];
                        return EventGridCard(
                          event: event,
                          showCommunity: true,
                          onTap: () => context.push('/events/${event.id}'),
                        );
                      }, childCount: items.length),
                    ),
                  ),
                if (state.hasMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFiltersBar(
    AsyncValue<List<CategoryCount>> categoriesAsync,
    EventsNotifier notifier,
    int activeCount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: categoriesAsync.when(
                  data: (categories) => EventCategoryChips(
                    categories: categories,
                    selected: notifier.category,
                    onSelected: _selectCategory,
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                  ),
                  loading: () => const CategoryChipsSkeleton(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 6),
              Badge.count(
                count: activeCount,
                isLabelVisible: activeCount > 0,
                child: IconButton(
                  onPressed: _openFiltersSheet,
                  icon: const Icon(Icons.tune),
                  tooltip: 'Filters',
                  style: IconButton.styleFrom(
                    backgroundColor: activeCount > 0
                        ? CluvoTheme.primary.withValues(alpha: 0.12)
                        : context.cluvoChipFill,
                    foregroundColor: activeCount > 0
                        ? CluvoTheme.primary
                        : context.cluvoTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  String _emptyMessage() {
    final n = ref.read(eventsProvider.notifier);
    final d = n.date;
    if (d != null) {
      final segment = _segmentForDate(d);
      if (segment == 'today') return 'No events today.';
      if (segment == 'tomorrow') return 'No events tomorrow.';
      return 'No events on this date.';
    }
    if (n.freeOnly) return 'No free events.';
    if (n.paidOnly) return 'No paid events.';
    if (n.category != null) return 'No ${n.category} events.';
    return 'No events to show.';
  }

  Widget _buildError(String errorMsg) {
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
              'Could not load events.\n$errorMsg',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.cluvoTextSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.read(eventsProvider.notifier).refresh(),
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

  Widget _buildSkeleton() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 8),
        CategoryChipsSkeleton(),
        SizedBox(height: 6),
        EventGridSkeleton(count: 6),
      ],
    );
  }
}

/// Bottom-sheet panel holding the long-tail filters: price, sort and an exact
/// date. Reads and writes [eventsProvider] directly, so it stays in sync with
/// the quick chips above the grid.
class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  void _apply(
    WidgetRef ref, {
    bool? freeOnly,
    bool? paidOnly,
    String? priceSort,
    String? distanceSort,
    bool clearPriceSort = false,
    bool clearDistanceSort = false,
    DateTime? date,
    DateTime? dateFrom,
    bool clearDate = false,
  }) {
    final n = ref.read(eventsProvider.notifier);
    n.setFilters(
      freeOnly: freeOnly ?? n.freeOnly,
      paidOnly: paidOnly ?? n.paidOnly,
      priceSort: priceSort,
      distanceSort: distanceSort,
      clearPriceSort: clearPriceSort,
      clearDistanceSort: clearDistanceSort,
      date: date,
      dateFrom: dateFrom,
      clearDate: clearDate,
      clearDateFrom: clearDate,
      category: n.category,
    );
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final n = ref.read(eventsProvider.notifier);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: n.date ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      _apply(ref, date: picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Subscribe so the sheet reflects filter changes as they happen.
    ref.watch(eventsProvider);
    final n = ref.read(eventsProvider.notifier);

    final priceValue = n.freeOnly
        ? 'free'
        : n.paidOnly
        ? 'paid'
        : 'any';
    String sortValue;
    if (n.distanceSort == 'nearToFar') {
      sortValue = 'nearToFar';
    } else if (n.distanceSort == 'farToNear') {
      sortValue = 'farToNear';
    } else if (n.priceSort == 'low') {
      sortValue = 'low';
    } else if (n.priceSort == 'high') {
      sortValue = 'high';
    } else if (n.priceSort == 'soonest') {
      sortValue = 'soonest';
    } else {
      sortValue = 'none';
    }
    final explicitDate = (n.date != null && _segmentForDate(n.date!) == null)
        ? n.date
        : null;
    final d = n.date;
    String dateChoice;
    if (n.dateFrom != null) {
      dateChoice = 'upcoming';
    } else if (d == null) {
      dateChoice = 'all';
    } else {
      final seg = _segmentForDate(d);
      if (seg == 'today') {
        dateChoice = 'today';
      } else if (seg == 'tomorrow') {
        dateChoice = 'tomorrow';
      } else {
        dateChoice = 'custom';
      }
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.cluvoTextSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => n.clearFilters(),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _sectionLabel(context, 'Price'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _sheetChip(
                  'Any',
                  priceValue == 'any',
                  () => _apply(ref, freeOnly: false, paidOnly: false),
                ),
                _sheetChip(
                  'Free',
                  priceValue == 'free',
                  () => _apply(ref, freeOnly: true, paidOnly: false),
                ),
                _sheetChip(
                  'Paid',
                  priceValue == 'paid',
                  () => _apply(ref, freeOnly: false, paidOnly: true),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionLabel(context, 'Sort'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _sheetChip(
                  'None',
                  sortValue == 'none',
                  () => _apply(
                    ref,
                    clearPriceSort: true,
                    clearDistanceSort: true,
                  ),
                ),
                _sheetChip(
                  'Soonest',
                  sortValue == 'soonest',
                  () => _apply(
                    ref,
                    priceSort: 'soonest',
                    clearDistanceSort: true,
                  ),
                ),
                _sheetChip(
                  'Price: Low to High',
                  sortValue == 'low',
                  () => _apply(ref, priceSort: 'low', clearDistanceSort: true),
                ),
                _sheetChip(
                  'Price: High to Low',
                  sortValue == 'high',
                  () => _apply(ref, priceSort: 'high', clearDistanceSort: true),
                ),
                _sheetChip(
                  'Distance: Near to Far',
                  sortValue == 'nearToFar',
                  () => _apply(
                    ref,
                    distanceSort: 'nearToFar',
                    clearPriceSort: true,
                  ),
                ),
                _sheetChip(
                  'Distance: Far to Near',
                  sortValue == 'farToNear',
                  () => _apply(
                    ref,
                    distanceSort: 'farToNear',
                    clearPriceSort: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionLabel(context, 'Date'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _sheetChip(
                  'All',
                  dateChoice == 'all',
                  () => _apply(ref, clearDate: true),
                ),
                _sheetChip('Today', dateChoice == 'today', () {
                  final now = DateTime.now();
                  _apply(ref, date: now);
                }),
                _sheetChip('Tomorrow', dateChoice == 'tomorrow', () {
                  final now = DateTime.now().add(const Duration(days: 1));
                  _apply(ref, date: now);
                }),
                _sheetChip('Upcoming', dateChoice == 'upcoming', () {
                  final tomorrow = DateTime.now().add(const Duration(days: 1));
                  _apply(ref, dateFrom: tomorrow);
                }),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(context, ref),
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      explicitDate != null
                          ? _formatShortDate(explicitDate)
                          : 'Pick a specific date',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: context.cluvoTextPrimary,
                      side: BorderSide(color: context.cluvoBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (explicitDate != null)
                  IconButton(
                    onPressed: () => _apply(ref, clearDate: true),
                    icon: const Icon(Icons.close),
                    tooltip: 'Clear date',
                  ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: CluvoTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 50),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Show events'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: context.cluvoTextSecondary,
        ),
      ),
    );
  }

  Widget _sheetChip(String label, bool selected, VoidCallback onTap) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? CluvoTheme.primary : context.cluvoChipFill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : context.cluvoTextPrimary,
            ),
          ),
        ),
      ),
    );
  }

  String _formatShortDate(DateTime d) {
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }
}
