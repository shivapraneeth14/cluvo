import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase_client.dart';
import '../models/models.dart';
import 'paginated_provider.dart';

const _pageSize = 20;

final communitiesProvider =
    StateNotifierProvider<CommunitiesNotifier, PaginatedList<Community>>((ref) {
  return CommunitiesNotifier();
});

class CommunitiesNotifier extends StateNotifier<PaginatedList<Community>> {
  int _page = 0;
  String? _category;

  CommunitiesNotifier() : super(const PaginatedList(loading: true)) {
    fetchFirstPage();
  }

  void setCategory(String? category) {
    if (_category == category) return;
    _category = category;
    _page = 0;
    fetchFirstPage(showLoading: true);
  }

  Future<void> fetchFirstPage({bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(loading: true, clearError: true);
    }
    try {
      var query = supabase
          .from('communities')
          .select('*')
          .isFilter('deleted_at', null)
          .eq('is_hidden', false);
      if (_category != null) {
        query = query.eq('category', _category!);
      }
      final res = await query
          .order('created_at', ascending: false)
          .range(0, _pageSize - 1);
      _page = 0;
      final items = (res as List).cast<Map<String, dynamic>>().map((e) => Community.fromMap(e)).toList();
      state = PaginatedList(
        items: items,
        loading: false,
        hasMore: items.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> fetchNextPage() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    final from = (_page + 1) * _pageSize;
    final to = from + _pageSize - 1;
    try {
      var query = supabase
          .from('communities')
          .select('*')
          .isFilter('deleted_at', null)
          .eq('is_hidden', false);
      if (_category != null) {
        query = query.eq('category', _category!);
      }
      final res = await query
          .order('created_at', ascending: false)
          .range(from, to);
      _page++;
      final newItems = (res as List).cast<Map<String, dynamic>>().map((e) => Community.fromMap(e)).toList();
      state = PaginatedList(
        items: [...state.items, ...newItems],
        loading: false,
        loadingMore: false,
        hasMore: newItems.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    _page = 0;
    await fetchFirstPage(showLoading: false);
  }
}

final categoriesProvider = FutureProvider<List<String>>((ref) async {
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
  final list = set.toList()..sort();
  return list;
});

final myCommunitiesProvider = FutureProvider<List<Community>>((ref) async {
  final session = supabase.auth.currentSession;
  if (session == null) return [];
  final response = await supabase
      .from('community_members')
      .select('role, communities(*)')
      .eq('user_id', session.user.id)
      .eq('communities.is_hidden', false)
      .order('joined_at', ascending: false);
  return (response as List).map((row) {
    final m = row as Map<String, dynamic>;
    final comm = m['communities'] as Map<String, dynamic>?;
    return Community.fromMap(comm ?? {});
  }).toList();
});
