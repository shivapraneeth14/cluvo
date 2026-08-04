import 'dart:async';
import '../theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/event_provider.dart';
import '../providers/paginated_provider.dart';
import '../models/models.dart';
import '../widgets/notification_bell.dart';
import '../widgets/theme_toggle_button.dart';
import '../widgets/wishlist_button.dart';
import '../providers/wishlist_provider.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String _categorize(Event event, DateTime today) {
  final eventDay = DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
  if (eventDay.isBefore(today)) return 'past';
  if (eventDay.isAtSameMomentAs(today)) return 'today';
  return 'upcoming';
}

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  String? _filter;
  DateTime? _pickedDate;
  bool _freeOnly = false;
  String? _priceSort;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _filterKey = GlobalKey();
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels < _scrollController.position.maxScrollExtent - 200) return;
    ref.read(eventsProvider.notifier).fetchNextPage();
  }

  List<Event> _applyFilter(List<Event> events) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    var result = events;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((e) {
        final communityName = e.communityName ?? '';
        return e.title.toLowerCase().contains(q)
            || communityName.toLowerCase().contains(q)
            || (e.description ?? '').toLowerCase().contains(q)
            || (e.location ?? '').toLowerCase().contains(q);
      }).toList();
    }

    return result.where((e) {
      final cat = _categorize(e, today);
      if (_filter == null) return true;
      return cat == _filter;
    }).toList();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _pickedDate = picked);
      _applyPriceFilters();
    }
  }

  bool get _panelActive => _freeOnly || _priceSort != null || _pickedDate != null;

  void _applyPriceFilters() {
    ref.read(eventsProvider.notifier).setFilters(
          freeOnly: _freeOnly,
          priceSort: _priceSort,
          date: _pickedDate,
        );
  }

  Future<void> _openFilterMenu() async {
    final box = _filterKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final dateLabel = _pickedDate != null
        ? 'Date: ${_pickedDate!.day}/${_pickedDate!.month} ✓'
        : null;

    final result = await showMenu<String>(
      context: context,
      position: position,
      elevation: 8,
      color: context.cluvoSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        PopupMenuItem<String>(
          value: 'all',
          child: _filterMenuItem('All', 'all', !_panelActive),
        ),
        PopupMenuItem<String>(
          value: 'free',
          child: _filterMenuItem('Free', 'free', _freeOnly),
        ),
        PopupMenuItem<String>(
          value: 'high',
          child: _filterMenuItem('Price: High to Low', 'high', _priceSort == 'high'),
        ),
        PopupMenuItem<String>(
          value: 'low',
          child: _filterMenuItem('Price: Low to High', 'low', _priceSort == 'low'),
        ),
        PopupMenuItem<String>(
          value: 'date',
          child: _filterMenuItem(dateLabel ?? 'Pick Date', 'date', _pickedDate != null),
        ),
      ],
    );
    if (result == null || !mounted) return;

    switch (result) {
      case 'all':
        setState(() {
          _freeOnly = false;
          _priceSort = null;
          _pickedDate = null;
        });
        _applyPriceFilters();
        break;
      case 'free':
        setState(() => _freeOnly = !_freeOnly);
        _applyPriceFilters();
        break;
      case 'high':
        setState(() => _priceSort = _priceSort == 'high' ? null : 'high');
        _applyPriceFilters();
        break;
      case 'low':
        setState(() => _priceSort = _priceSort == 'low' ? null : 'low');
        _applyPriceFilters();
        break;
      case 'date':
        await _pickDate();
        break;
    }
  }

  Widget _filterMenuItem(String label, String option, bool selected) {
    return Row(
      children: [
        Icon(
          selected
              ? Icons.check
              : option == 'date'
                  ? Icons.calendar_today_outlined
                  : option == 'free'
                      ? Icons.volunteer_activism_outlined
                      : option == 'all'
                          ? Icons.filter_list
                          : Icons.currency_rupee,
          size: 16,
          color: selected ? CluvoTheme.primary : context.cluvoTextSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: context.cluvoTextPrimary,
            ),
          ),
        ),
      ],
    );
  }

  String _emptyMessage() {
    if (_pickedDate != null) {
      return 'No events on this date.';
    }
    if (_freeOnly) {
      return 'No free events.';
    }
    if (_searchQuery.isNotEmpty) {
      return 'No events match "$_searchQuery".';
    }
    return 'No upcoming events.';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'CLUVO',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: const Color(0xFFC2185B),
          ),
        ),
        actions: const [ThemeToggleButton(), NotificationBell()],
      ),
      body: state.loading
          ? _buildSkeleton()
          : state.error != null && state.items.isEmpty
              ? _buildError(state.error!)
              : _buildContent(state),
    );
  }

  Widget _buildContent(PaginatedList<Event> state) {
    final filtered = _applyFilter(state.items);
    final notifier = ref.read(eventsProvider.notifier);

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        setState(() => _searchQuery = v.trim());
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search events...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: context.cluvoChipFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  key: _filterKey,
                  child: IconButton(
                    onPressed: _openFilterMenu,
                    icon: const Icon(Icons.filter_list),
                    style: IconButton.styleFrom(
                      backgroundColor: _panelActive
                          ? CluvoTheme.primary.withValues(alpha: 0.12)
                          : context.cluvoChipFill,
                      foregroundColor: _panelActive
                          ? CluvoTheme.primary
                          : context.cluvoTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildChip('All', null),
                  const SizedBox(width: 6),
                  _buildChip('Today', 'today'),
                  const SizedBox(width: 6),
                  _buildChip('Upcoming', 'upcoming'),
                ],
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 200),
                      Center(
                        child: Text(
                          _emptyMessage(),
                          style: TextStyle(color: context.cluvoTextSecondary),
                        ),
                      ),
                    ],
                  )
                : GridView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: filtered.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == filtered.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final e = filtered[index];
                      final communityName = e.communityName;
                      final imageUrl = e.imageUrl;
                      final price = e.price;
                      final title = e.title;

                      return RepaintBoundary(
                        child: Stack(
                          children: [
                            Card(
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () => context.push('/events/${e.id}'),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: imageUrl != null && imageUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              placeholder: (_, _) => const SizedBox(),
                                              errorWidget: (_, _, _) =>
                                                  _buildImageFallback(title),
                                            )
                                          : _buildImageFallback(title),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                height: 1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            if (communityName != null)
                                              Text(
                                                communityName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: context.cluvoTextSecondary,
                                                ),
                                              ),
                                            const Spacer(),
                                            Row(
                                              children: [
                                                Text(
                                                  _formatShortDate(e),
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    color: context.cluvoTextSecondary,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  price > 0
                                                      ? '₹${(price / 100).toStringAsFixed(0)}'
                                                      : 'Free',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: price > 0
                                                        ? context.cluvoPrimaryText
                                                        : Colors.green,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: WishlistButton(
                                type: wishlistEvent,
                                id: e.id,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String errorMsg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: context.cluvoTextSecondary),
            const SizedBox(height: 12),
            Text('Could not load events.\n$errorMsg',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.cluvoTextSecondary)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.read(eventsProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Tap to Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC2185B),
                side: const BorderSide(color: Color(0xFFC2185B)),
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

  Widget _buildChip(String label, String? category) {
    final selected = _filter == category && _pickedDate == null;
    return GestureDetector(
      onTap: () => setState(() {
        _filter = selected ? null : category;
        _pickedDate = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFC2185B) : context.cluvoChipFill,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : context.cluvoTextPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: 6,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (_, _) => Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Container(color: context.cluvoChipFill),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 8, width: 70, decoration: BoxDecoration(color: context.cluvoChipFill, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 6),
                    Container(height: 6, width: 50, decoration: BoxDecoration(color: context.cluvoChipFill, borderRadius: BorderRadius.circular(4))),
                    const Spacer(),
                    Container(height: 8, width: 30, decoration: BoxDecoration(color: context.cluvoChipFill, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageFallback(String title) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFC2185B), Color(0xFFE0407A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0].toUpperCase() : 'E',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _formatShortDate(Event event) {
    return '${event.startDate.day} ${_months[event.startDate.month - 1]}';
  }
}
