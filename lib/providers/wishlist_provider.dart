import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase_client.dart';
import '../models/models.dart';
import 'community_provider.dart';

const wishlistEvent = 'event';
const wishlistCommunity = 'community';

final wishlistEventsProvider = FutureProvider.autoDispose<List<Event>>((
  ref,
) async {
  final saved = ref.watch(wishlistProvider).savedEvents;
  final ids = saved.keys.toList();
  if (ids.isEmpty) return [];
  final res = await supabase
      .from('events')
      .select('*, communities!inner(name)')
      .inFilter('id', ids)
      .isFilter('deleted_at', null)
      .eq('communities.is_hidden', false);
  final items =
      (res as List)
          .cast<Map<String, dynamic>>()
          .map((e) => Event.fromMap(e))
          .toList()
        ..sort(
          (a, b) => (saved[b.id] ?? DateTime(0)).compareTo(
            saved[a.id] ?? DateTime(0),
          ),
        );
  return items;
});

final wishlistCommunitiesProvider = FutureProvider.autoDispose<List<Community>>(
  (ref) async {
    final saved = ref.watch(wishlistProvider).savedCommunities;
    final ids = saved.keys.toList();
    if (ids.isEmpty) return [];
    final res = await supabase
        .from('communities')
        .select(communitySelectColumns)
        .inFilter('id', ids)
        .isFilter('deleted_at', null)
        .eq('is_hidden', false);
    final items =
        (res as List)
            .cast<Map<String, dynamic>>()
            .map((e) => Community.fromMap(e))
            .toList()
          ..sort(
            (a, b) => (saved[b.id] ?? DateTime(0)).compareTo(
              saved[a.id] ?? DateTime(0),
            ),
          );
    return items;
  },
);

final wishlistProvider = StateNotifierProvider<WishlistNotifier, WishlistState>(
  (ref) {
    return WishlistNotifier();
  },
);

class WishlistState {
  final Map<String, DateTime> savedEvents;
  final Map<String, DateTime> savedCommunities;
  final bool loaded;
  final String? userId;

  const WishlistState({
    this.savedEvents = const {},
    this.savedCommunities = const {},
    this.loaded = false,
    this.userId,
  });
}

class WishlistNotifier extends StateNotifier<WishlistState> {
  WishlistNotifier() : super(const WishlistState());

  bool isSaved(String type, String id) {
    final map = type == wishlistEvent
        ? state.savedEvents
        : state.savedCommunities;
    return map.containsKey(id);
  }

  bool get isLoaded => state.loaded;

  void reset() => state = const WishlistState();

  Future<void> load() async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      state = const WishlistState(loaded: true);
      return;
    }
    if (state.loaded && state.userId == session.user.id) return;
    try {
      final res = await supabase
          .from('wishlist')
          .select('item_type, item_id, created_at')
          .eq('user_id', session.user.id);
      final events = <String, DateTime>{};
      final communities = <String, DateTime>{};
      for (final row in (res as List).cast<Map<String, dynamic>>()) {
        final type = row['item_type'] as String;
        final id = row['item_id'] as String;
        final createdAt =
            DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0);
        if (type == wishlistEvent) {
          events[id] = createdAt;
        } else if (type == wishlistCommunity) {
          communities[id] = createdAt;
        }
      }
      state = WishlistState(
        savedEvents: events,
        savedCommunities: communities,
        loaded: true,
        userId: session.user.id,
      );
    } catch (_) {
      state = WishlistState(loaded: true, userId: session.user.id);
    }
  }

  Future<void> toggle(String type, String id) async {
    final session = supabase.auth.currentSession;
    if (session == null) return;
    if (!state.loaded) await load();
    if (session != supabase.auth.currentSession) return;

    final isSavedNow = isSaved(type, id);
    _applyLocal(type, id, !isSavedNow);

    try {
      if (isSavedNow) {
        await supabase
            .from('wishlist')
            .delete()
            .eq('user_id', session.user.id)
            .eq('item_type', type)
            .eq('item_id', id);
      } else {
        await supabase.from('wishlist').upsert({
          'user_id': session.user.id,
          'item_type': type,
          'item_id': id,
        }, onConflict: 'user_id,item_type,item_id');
      }
    } catch (_) {
      _applyLocal(type, id, isSavedNow);
    }
  }

  void _applyLocal(String type, String id, bool saved) {
    final map = type == wishlistEvent
        ? Map<String, DateTime>.of(state.savedEvents)
        : Map<String, DateTime>.of(state.savedCommunities);
    if (saved) {
      map[id] = DateTime.now();
    } else {
      map.remove(id);
    }
    if (type == wishlistEvent) {
      state = WishlistState(
        savedEvents: map,
        savedCommunities: state.savedCommunities,
        loaded: true,
        userId: state.userId,
      );
    } else {
      state = WishlistState(
        savedEvents: state.savedEvents,
        savedCommunities: map,
        loaded: true,
        userId: state.userId,
      );
    }
  }
}
