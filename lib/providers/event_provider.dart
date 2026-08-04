import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';
import '../models/models.dart';
import 'paginated_provider.dart';

const _pageSize = 20;

final eventsProvider = StateNotifierProvider<EventsNotifier, PaginatedList<Event>>((ref) {
  return EventsNotifier();
});

class EventsNotifier extends StateNotifier<PaginatedList<Event>> {
  int _page = 0;
  bool _freeOnly = false;
  String? _priceSort;
  DateTime? _date;

  EventsNotifier() : super(const PaginatedList(loading: true)) {
    fetchFirstPage();
  }

  void setFilters({bool freeOnly = false, String? priceSort, DateTime? date}) {
    if (_freeOnly == freeOnly && _priceSort == priceSort && _date == date) {
      return;
    }
    _freeOnly = freeOnly;
    _priceSort = priceSort;
    _date = date;
    _page = 0;
    fetchFirstPage(showLoading: true);
  }

  Future<void> fetchFirstPage({bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(loading: true, clearError: true);
    }
    try {
      final res = await _buildQuery().range(0, _pageSize - 1);
      _page = 0;
      final items = (res as List).cast<Map<String, dynamic>>().map((e) => Event.fromMap(e)).toList();
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
      final res = await _buildQuery().range(from, to);
      _page++;
      final newItems = (res as List).cast<Map<String, dynamic>>().map((e) => Event.fromMap(e)).toList();
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

  PostgrestTransformBuilder<PostgrestList> _buildQuery() {
    var query = supabase
        .from('events')
        .select('*, communities!inner(name)')
        .isFilter('deleted_at', null)
        .eq('communities.is_hidden', false)
        .inFilter('status', ['published', 'completed']);
    if (_freeOnly) {
      query = query.eq('price', 0);
    }
    if (_date != null) {
      final dayStart = DateTime(_date!.year, _date!.month, _date!.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      query = query
          .gte('start_date', dayStart.toIso8601String())
          .lt('start_date', dayEnd.toIso8601String());
    }
    if (_priceSort != null) {
      return query.order('price', ascending: _priceSort == 'low');
    }
    return query.order('start_date', ascending: false);
  }

  Future<void> refresh() async {
    _page = 0;
    await fetchFirstPage(showLoading: false);
  }
}
