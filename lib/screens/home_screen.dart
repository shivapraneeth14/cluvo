import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../providers/home_provider.dart';
import '../providers/event_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/home/home_hero.dart';
import '../widgets/home/section_header.dart';
import '../widgets/home/trending_pills.dart';
import '../widgets/home/category_cards.dart';
import '../widgets/home/mood_cards.dart';
import '../widgets/home/quick_filters.dart';
import '../widgets/home/free_events_banner.dart';
import '../widgets/location_feedback.dart';

class _LocResult {
  final String? value;
  final bool useGps;
  const _LocResult(this.value, {this.useGps = false});
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime? _date;
  String? _priceOption; // 'free' | 'low' | 'high'
  String? _distanceOption; // 'nearToFar' | 'farToNear'

  Future<void> _refresh() async {
    ref.invalidate(featuredEventProvider);
    ref.invalidate(freeEventsProvider);
    ref.invalidate(categoryCountsProvider);
    ref.invalidate(categoryImagesProvider);
    ref.invalidate(trendingProvider);
    ref.invalidate(locationOptionsProvider);
    await ref.read(featuredEventProvider.future).catchError((_) => null);
  }

  void _openSearch([String? query]) {
    if (query == null || query.trim().isEmpty) {
      context.push('/search');
    } else {
      context.push('/search?q=${Uri.encodeComponent(query.trim())}');
    }
  }

  // Applies the quick filters chosen on Home and opens the full catalogue so
  // the user lands on the exact filtered list they configured.
  void _goToEvents() {
    final priceSortActive = _priceOption == 'low' || _priceOption == 'high';
    final useDistance = _distanceOption != null;
    ref
        .read(eventsProvider.notifier)
        .setFilters(
          freeOnly: _priceOption == 'free',
          paidOnly: false,
          priceSort: useDistance
              ? null
              : (priceSortActive ? _priceOption : null),
          clearPriceSort: useDistance || !priceSortActive,
          distanceSort: useDistance ? _distanceOption : null,
          clearDistanceSort: !useDistance,
          date: _date,
          clearDate: _date == null,
          category: null,
        );
    context.go('/events/all');
  }

  void _openEventsWithCategory(String category) {
    ref.read(eventsProvider.notifier).setFilters(category: category);
    context.go('/events/all');
  }

  void _openCategory(String category) {
    ref.read(eventsProvider.notifier).setFilters(category: category);
    context.go('/events');
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: CluvoTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
    _goToEvents();
  }

  Future<void> _pickPrice() async {
    final labels = <String, String>{
      'any': 'Any price',
      'free': 'Free only',
      'low': 'Price: Low to High',
      'high': 'Price: High to Low',
    };
    final selected = await _optionSheet(_priceOption ?? 'any', labels, 'Price');
    if (selected == null || !mounted) return;
    setState(() {
      _priceOption = selected == 'any' ? null : selected;
      // Price sorting and distance sorting are mutually exclusive.
      if (_priceOption == 'low' || _priceOption == 'high') {
        _distanceOption = null;
      }
    });
    _goToEvents();
  }

  Future<void> _pickDistance() async {
    final labels = <String, String>{
      'any': 'Any distance',
      'nearToFar': 'Near to Far',
      'farToNear': 'Far to Near',
    };
    final selected = await _optionSheet(
      _distanceOption ?? 'any',
      labels,
      'Distance',
    );
    if (selected == null || !mounted) return;
    setState(() {
      _distanceOption = selected == 'any' ? null : selected;
      // Distance sorting overrides price sorting.
      if (_distanceOption != null &&
          (_priceOption == 'low' || _priceOption == 'high')) {
        _priceOption = null;
      }
    });
    _goToEvents();
  }

  Future<String?> _optionSheet(
    String current,
    Map<String, String> labels,
    String title,
  ) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.cluvoSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.cluvoTextPrimary,
                  ),
                ),
              ),
            ),
            for (final entry in labels.entries)
              ListTile(
                title: Text(
                  entry.value,
                  style: TextStyle(
                    fontSize: 15,
                    color: context.cluvoTextPrimary,
                  ),
                ),
                trailing: entry.key == current
                    ? const Icon(Icons.check, color: CluvoTheme.primary)
                    : null,
                onTap: () => Navigator.pop(context, entry.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLocation() async {
    final options = await ref
        .read(locationOptionsProvider.future)
        .catchError((_) => <String>[]);
    if (!mounted) return;
    final current = ref.read(locationControllerProvider).city;
    final result = await showModalBottomSheet<_LocResult>(
      context: context,
      backgroundColor: context.cluvoSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.cluvoTextPrimary,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.my_location,
                        color: CluvoTheme.primary,
                      ),
                      title: Text(
                        'Use my location',
                        style: TextStyle(color: context.cluvoTextPrimary),
                      ),
                      onTap: () => Navigator.pop(
                        context,
                        const _LocResult(null, useGps: true),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.public,
                        color: CluvoTheme.primary,
                      ),
                      title: Text(
                        'Any location',
                        style: TextStyle(color: context.cluvoTextPrimary),
                      ),
                      trailing: current == null
                          ? const Icon(Icons.check, color: CluvoTheme.primary)
                          : null,
                      onTap: () =>
                          Navigator.pop(context, const _LocResult(null)),
                    ),
                    for (final option in options)
                      ListTile(
                        leading: const Icon(
                          Icons.location_city_outlined,
                          color: CluvoTheme.primary,
                        ),
                        title: Text(
                          option,
                          style: TextStyle(color: context.cluvoTextPrimary),
                        ),
                        trailing: current == option
                            ? const Icon(Icons.check, color: CluvoTheme.primary)
                            : null,
                        onTap: () => Navigator.pop(context, _LocResult(option)),
                      ),
                    if (options.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'No cities available yet.',
                          style: TextStyle(color: context.cluvoTextSecondary),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (result.useGps) {
      await ref.read(locationControllerProvider.notifier).useMyLocation();
      if (!mounted) return;
      showLocationOutcome(
        context,
        ref,
        ref.read(locationControllerProvider).status,
      );
      return;
    }
    ref.read(locationControllerProvider.notifier).select(result.value);
  }

  @override
  Widget build(BuildContext context) {
    final featured = ref.watch(featuredEventProvider).valueOrNull;
    final trending = ref.watch(trendingProvider).valueOrNull ?? const [];
    final counts = ref.watch(categoryCountsProvider).valueOrNull;
    final images = ref.watch(categoryImagesProvider).valueOrNull ?? const {};
    final freeEvents = ref.watch(freeEventsProvider).valueOrNull;
    final locState = ref.watch(locationControllerProvider);
    final location = locState.city;
    final locationLabel =
        (locState.status == LocationStatus.detecting && !locState.hasCity)
        ? 'Locating…'
        : (location ?? 'Near you');

    final categories = (counts != null && counts.isNotEmpty)
        ? counts
        : trending.map((c) => CategoryCount(c, 0)).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.cluvoBackground,
        body: RefreshIndicator(
          color: CluvoTheme.primary,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              HomeHero(
                featured: featured,
                locationLabel: locationLabel,
                onLocationTap: _pickLocation,
                onSearchTap: () => _openSearch(),
              ),
              const SizedBox(height: 24),
              const SectionHeader(
                icon: Icons.local_fire_department_outlined,
                title: 'Popular right now',
                fresh: true,
              ),
              const SizedBox(height: 12),
              TrendingPills(
                items: List<String>.from(trending),
                onTap: _openEventsWithCategory,
              ),
              const SizedBox(height: CluvoTheme.sectionSpacing),
              SectionHeader(
                icon: Icons.grid_view_rounded,
                title: 'Explore events',
                actionLabel: 'View',
                onAction: () => context.go('/events'),
                fresh: true,
              ),
              const SizedBox(height: 12),
              CategoryCards(
                categories: categories,
                images: Map<String, String>.from(images),
                onTap: _openCategory,
              ),
              const SizedBox(height: CluvoTheme.sectionSpacing),
              const SectionHeader(
                icon: Icons.auto_awesome_outlined,
                title: 'Discover by your mood',
                fresh: true,
              ),
              const SizedBox(height: 12),
              MoodCards(
                images: Map<String, String>.from(images),
                onTap: _openSearch,
              ),
              const SizedBox(height: CluvoTheme.sectionSpacing),
              QuickFilters(
                dateLabel: _date == null
                    ? 'Date'
                    : '${_date!.day}/${_date!.month}/${_date!.year}',
                distanceLabel: _distanceOption == null
                    ? 'Distance'
                    : _distanceOption == 'nearToFar'
                    ? 'Near → Far'
                    : 'Far → Near',
                priceLabel: _priceOption == null
                    ? 'Price'
                    : _priceOption == 'free'
                    ? 'Free'
                    : _priceOption == 'low'
                    ? 'Low → High'
                    : 'High → Low',
                dateActive: _date != null,
                distanceActive: _distanceOption != null,
                priceActive: _priceOption != null,
                onDateTap: _pickDate,
                onDistanceTap: _pickDistance,
                onPriceTap: _pickPrice,
              ),
              if (freeEvents != null && freeEvents.count > 0) ...[
                const SizedBox(height: CluvoTheme.sectionSpacing),
                FreeEventsBanner(
                  count: freeEvents.count,
                  onTap: () {
                    ref
                        .read(eventsProvider.notifier)
                        .setFilters(
                          freeOnly: true,
                          clearPriceSort: true,
                          clearDistanceSort: true,
                          clearDate: true,
                          category: null,
                        );
                    context.go('/events/all');
                  },
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
