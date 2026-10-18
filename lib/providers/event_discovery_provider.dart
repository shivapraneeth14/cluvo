import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase_client.dart';
import '../models/models.dart';
import '../services/location_matching.dart';
import 'event_provider.dart';
import 'location_provider.dart';

/// An event stays discoverable while it has not fully ended. `end_date` is
/// NOT NULL in the schema, but the `start_date` branch keeps events that have
/// no end date (legacy rows) discoverable too.
String _discoverableOr() {
  final now = DateTime.now().toUtc().toIso8601String();
  return 'start_date.gte.$now,end_date.gte.$now';
}

const _select = '*, communities!inner(name)';

/// Active discovery filters, seeded from the shared [eventsProvider] so a
/// category/location chosen on the Home screen (which sets those filters and
/// then navigates to `/events`) is honoured here without duplicating state.
///
/// The Events page owns its own bounded queries rather than reusing the
/// paginated `eventsProvider`, so it never has to load the whole catalogue to
/// build a handful of carousels.
class DiscoveryFilters {
  final String? category;
  final bool freeOnly;
  final DateTime? date;
  final String? priceSort;

  const DiscoveryFilters({
    this.category,
    this.freeOnly = false,
    this.date,
    this.priceSort,
  });

  bool get isEmpty =>
      (category == null || category!.isEmpty) &&
      !freeOnly &&
      date == null &&
      priceSort == null;

  DiscoveryFilters copyWith({
    String? category,
    bool clearCategory = false,
    bool? freeOnly,
    DateTime? date,
    bool clearDate = false,
    String? priceSort,
    bool clearPriceSort = false,
  }) {
    return DiscoveryFilters(
      category: clearCategory ? null : (category ?? this.category),
      freeOnly: freeOnly ?? this.freeOnly,
      date: clearDate ? null : (date ?? this.date),
      priceSort: clearPriceSort ? null : (priceSort ?? this.priceSort),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DiscoveryFilters &&
      other.category == category &&
      other.freeOnly == freeOnly &&
      other.date == date &&
      other.priceSort == priceSort;

  @override
  int get hashCode => Object.hash(category, freeOnly, date, priceSort);
}

final discoveryFiltersProvider = StateProvider<DiscoveryFilters>((ref) {
  final notifier = ref.read(eventsProvider.notifier);
  return DiscoveryFilters(
    category: notifier.category,
    freeOnly: notifier.freeOnly,
    date: notifier.date,
    priceSort: notifier.priceSort,
  );
});

/// Soonest upcoming eligible events, applying the active discovery filters.
/// Bounded to a single page — the "Coming up next" carousel never needs more.
final discoveryUpcomingProvider = FutureProvider<List<Event>>((ref) async {
  final filters = ref.watch(discoveryFiltersProvider);
  var query = supabase
      .from('events')
      .select(_select)
      .isFilter('deleted_at', null)
      .eq('communities.is_hidden', false)
      .eq('status', 'published')
      .or(_discoverableOr());
  if (filters.freeOnly) {
    query = query.eq('price', 0);
  }
  if (filters.category != null && filters.category!.isNotEmpty) {
    query = query.eq('category', filters.category!);
  }
  if (filters.date != null) {
    final dayStart = DateTime(
      filters.date!.year,
      filters.date!.month,
      filters.date!.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    query = query
        .gte('start_date', dayStart.toUtc().toIso8601String())
        .lt('start_date', dayEnd.toUtc().toIso8601String());
  }
  final hasPriceSort =
      filters.priceSort == 'low' || filters.priceSort == 'high';
  final ordered = hasPriceSort
      ? query.order('price', ascending: filters.priceSort == 'low')
      : query.order('start_date', ascending: true);
  final res = await ordered.limit(12);
  return (res as List)
      .cast<Map<String, dynamic>>()
      .map((e) => Event.fromMap(e))
      .toList();
});

/// Popular events ranked by the real, backend-maintained `booked_count` and
/// honouring the active discovery filters (category, location, date, free).
/// Events already surfaced by "Upcoming Events" are excluded so the two
/// carousels never present the same list twice. The caption describes the
/// ranking honestly ("Ranked by bookings").
final discoveryPopularProvider = FutureProvider<List<Event>>((ref) async {
  final filters = ref.watch(discoveryFiltersProvider);
  Set<String> exclude = const {};
  try {
    final upcoming = await ref.watch(discoveryUpcomingProvider.future);
    exclude = upcoming.map((e) => e.id).toSet();
  } catch (_) {
    // Upcoming failed — fall back to an unfiltered popular list.
  }
  var query = supabase
      .from('events')
      .select(_select)
      .isFilter('deleted_at', null)
      .eq('communities.is_hidden', false)
      .eq('status', 'published')
      .or(_discoverableOr());
  if (filters.freeOnly) {
    query = query.eq('price', 0);
  }
  if (filters.category != null && filters.category!.isNotEmpty) {
    query = query.eq('category', filters.category!);
  }
  if (filters.date != null) {
    final dayStart = DateTime(
      filters.date!.year,
      filters.date!.month,
      filters.date!.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    query = query
        .gte('start_date', dayStart.toUtc().toIso8601String())
        .lt('start_date', dayEnd.toUtc().toIso8601String());
  }
  final res = await query
      .order('booked_count', ascending: false)
      .order('start_date', ascending: true)
      .limit(10 + exclude.length);
  final items = (res as List)
      .cast<Map<String, dynamic>>()
      .map((e) => Event.fromMap(e))
      .where((e) => !exclude.contains(e.id))
      .take(10)
      .toList();
  return items;
});

/// Events near the user, prioritised by distance and considering popularity.
/// Falls back gracefully if coordinates are missing.
final nearbyPopularProvider = FutureProvider<List<Event>>((ref) async {
  final filters = ref.watch(discoveryFiltersProvider);
  final loc = ref.watch(locationControllerProvider);
  var query = supabase
      .from('events')
      .select(_select)
      .isFilter('deleted_at', null)
      .eq('communities.is_hidden', false)
      .eq('status', 'published')
      .or(_discoverableOr());
  if (filters.freeOnly) {
    query = query.eq('price', 0);
  }
  if (filters.category != null && filters.category!.isNotEmpty) {
    query = query.eq('category', filters.category!);
  }
  if (filters.date != null) {
    final dayStart = DateTime(
      filters.date!.year,
      filters.date!.month,
      filters.date!.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    query = query
        .gte('start_date', dayStart.toUtc().toIso8601String())
        .lt('start_date', dayEnd.toUtc().toIso8601String());
  }
  final res = await query.limit(50);
  final items = (res as List)
      .cast<Map<String, dynamic>>()
      .map((e) => Event.fromMap(e))
      .toList();
  items.sort((a, b) {
    final da = eventDistanceKm(a, loc.latitude, loc.longitude);
    final db = eventDistanceKm(b, loc.latitude, loc.longitude);
    if (da != null && db != null) {
      final diff = da - db;
      if (diff.abs() > 0.001) return da.compareTo(db);
    } else if (da != null && db == null) {
      return -1;
    } else if (da == null && db != null) {
      return 1;
    }
    final aLocal = isEventLocal(a, loc.city);
    final bLocal = isEventLocal(b, loc.city);
    if (aLocal != bLocal) return bLocal ? -1 : 1;
    final bc = b.bookedCount.compareTo(a.bookedCount);
    if (bc != 0) return bc;
    return a.startDate.compareTo(b.startDate);
  });
  return items.take(12).toList();
});
