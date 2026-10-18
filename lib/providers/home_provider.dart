import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';
import '../models/models.dart';

String _upcomingOr() {
  final now = DateTime.now().toUtc().toIso8601String();
  // An event is discoverable while it hasn't fully ended.
  return 'start_date.gte.$now,end_date.gte.$now';
}

class CategoryCount {
  final String category;
  final int count;

  const CategoryCount(this.category, this.count);
}

/// A single hero image source for the Home hero. Prefers the soonest upcoming
/// published event that actually has artwork; returns null when none exists.
final featuredEventProvider = FutureProvider<Event?>((ref) async {
  final res = await supabase
      .from('events')
      .select('*, communities!inner(name)')
      .isFilter('deleted_at', null)
      .eq('communities.is_hidden', false)
      .eq('status', 'published')
      .not('image_url', 'is', null)
      .or(_upcomingOr())
      .order('start_date', ascending: true)
      .limit(1);
  final rows = (res as List).cast<Map<String, dynamic>>();
  if (rows.isEmpty) return null;
  return Event.fromMap(rows.first);
});

/// Genuine free (price == 0) upcoming events plus an exact total count.
/// The count respects the filters but ignores the limit, so the banner always
/// reports the real number of free events rather than the page size.
class FreeEventsResult {
  final int count;
  final List<Event> events;

  const FreeEventsResult({required this.count, required this.events});
}

final freeEventsProvider = FutureProvider<FreeEventsResult>((ref) async {
  final res = await supabase
      .from('events')
      .select('*, communities!inner(name)')
      .isFilter('deleted_at', null)
      .eq('communities.is_hidden', false)
      .eq('status', 'published')
      .eq('price', 0)
      .or(_upcomingOr())
      .order('start_date', ascending: true)
      .limit(8)
      .count(CountOption.exact);
  final events = (res.data as List)
      .cast<Map<String, dynamic>>()
      .map((e) => Event.fromMap(e))
      .toList();
  return FreeEventsResult(count: res.count, events: events);
});

/// Accurate per-category counts of discoverable events (server-side aggregate).
final categoryCountsProvider = FutureProvider<List<CategoryCount>>((ref) async {
  final res = await supabase.rpc('event_category_counts');
  final rows = (res as List).cast<Map<String, dynamic>>();
  return rows
      .map(
        (r) => CategoryCount(
          (r['category'] as String).trim(),
          (r['event_count'] as num).toInt(),
        ),
      )
      .where((c) => c.category.isNotEmpty && c.count > 0)
      .toList();
});

/// Best-effort representative artwork per category, taken from the soonest
/// upcoming published events that actually have an image. Used to render the
/// photographic "Explore by category" cards without bundled assets.
final categoryImagesProvider = FutureProvider<Map<String, String>>((ref) async {
  final res = await supabase
      .from('events')
      .select('category, image_url')
      .isFilter('deleted_at', null)
      .eq('status', 'published')
      .not('category', 'is', null)
      .not('image_url', 'is', null)
      .or(_upcomingOr())
      .order('start_date', ascending: true)
      .limit(100);
  final map = <String, String>{};
  for (final row in (res as List)) {
    final r = row as Map<String, dynamic>;
    final category = (r['category'] as String?)?.trim();
    final image = r['image_url'] as String?;
    if (category != null &&
        category.isNotEmpty &&
        image != null &&
        image.isNotEmpty) {
      map.putIfAbsent(category, () => image);
    }
  }
  return map;
});

/// Trending categories for the "Popular right now" pills, with a graceful
/// fallback to real community categories when the aggregate is unavailable
/// (e.g. migration not yet applied).
final trendingProvider = FutureProvider<List<String>>((ref) async {
  try {
    final counts = await ref.watch(categoryCountsProvider.future);
    if (counts.isNotEmpty) {
      return counts.map((c) => c.category).take(8).toList();
    }
  } catch (_) {
    // fall through to community categories
  }
  try {
    final categories = await ref.watch(_communityCategories.future);
    return categories.take(8).toList();
  } catch (_) {
    return const [];
  }
});

final _communityCategories = FutureProvider<List<String>>((ref) async {
  final res = await supabase
      .from('communities')
      .select('category')
      .eq('is_hidden', false)
      .isFilter('deleted_at', null)
      .not('category', 'is', null);
  final set = <String>{};
  for (final row in (res as List)) {
    final cat = (row as Map<String, dynamic>)['category'] as String?;
    if (cat != null && cat.trim().isNotEmpty) set.add(cat.trim());
  }
  return set.toList()..sort();
});
