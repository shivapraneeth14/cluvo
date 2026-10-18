import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_client.dart';
import '../models/models.dart';
import '../services/location_matching.dart';
import 'location_provider.dart';
import 'paginated_provider.dart';

const _pageSize = 20;

final eventsProvider =
    StateNotifierProvider<EventsNotifier, PaginatedList<Event>>((ref) {
      return EventsNotifier(ref);
    });

class EventsNotifier extends StateNotifier<PaginatedList<Event>> {
  final Ref ref;
  int _page = 0;
  bool _freeOnly = false;
  bool _paidOnly = false;
  String? _priceSort;
  String? _distanceSort;
  DateTime? _date;
  DateTime? _dateFrom;
  String? _category;
  List<Event>? _sortedCache;
  int _clientPage = 0;

  EventsNotifier(this.ref) : super(const PaginatedList(loading: true)) {
    fetchFirstPage();
  }

  // Active filters, exposed so entry points (e.g. Home) can reflect state.
  bool get freeOnly => _freeOnly;
  bool get paidOnly => _paidOnly;
  String? get priceSort => _priceSort;
  String? get distanceSort => _distanceSort;
  DateTime? get date => _date;
  DateTime? get dateFrom => _dateFrom;
  String? get category => _category;
  bool get hasFilters =>
      _freeOnly ||
      _paidOnly ||
      _priceSort != null ||
      _distanceSort != null ||
      _date != null ||
      _dateFrom != null ||
      _category != null;

  void setFilters({
    bool freeOnly = false,
    bool paidOnly = false,
    String? priceSort,
    String? distanceSort,
    bool clearPriceSort = false,
    bool clearDistanceSort = false,
    DateTime? date,
    DateTime? dateFrom,
    bool clearDate = false,
    bool clearDateFrom = false,
    String? category,
  }) {
    final nextPriceSort = clearPriceSort ? null : (priceSort ?? _priceSort);
    final nextDistanceSort = clearDistanceSort
        ? null
        : (distanceSort ?? _distanceSort);
    // Date choices are mutually exclusive: an explicit `date` or `dateFrom`
    // clears the other one.
    DateTime? nextDate;
    DateTime? nextDateFrom;
    if (date != null) {
      nextDate = date;
      nextDateFrom = null;
    } else if (dateFrom != null) {
      nextDate = null;
      nextDateFrom = dateFrom;
    } else if (clearDate || clearDateFrom) {
      nextDate = null;
      nextDateFrom = null;
    } else {
      nextDate = _date;
      nextDateFrom = _dateFrom;
    }
    if (_freeOnly == freeOnly &&
        _paidOnly == paidOnly &&
        _priceSort == nextPriceSort &&
        _distanceSort == nextDistanceSort &&
        _date == nextDate &&
        _dateFrom == nextDateFrom &&
        _category == category) {
      return;
    }
    _freeOnly = freeOnly;
    _paidOnly = paidOnly;
    _priceSort = nextPriceSort;
    _distanceSort = nextDistanceSort;
    _date = nextDate;
    _dateFrom = nextDateFrom;
    _category = category;
    _page = 0;
    _clientPage = 0;
    _sortedCache = null;
    fetchFirstPage(showLoading: true);
  }

  void clearFilters() => setFilters(
    freeOnly: false,
    paidOnly: false,
    clearPriceSort: true,
    clearDistanceSort: true,
    clearDate: true,
    clearDateFrom: true,
    category: null,
  );

  Future<void> fetchFirstPage({bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(loading: true, clearError: true);
    }
    if (_distanceSort != null) {
      try {
        final res = await _buildQuery().limit(100);
        final items = (res as List)
            .cast<Map<String, dynamic>>()
            .map((e) => Event.fromMap(e))
            .toList();
        final sorted = _sortByDistance(items);
        _sortedCache = sorted;
        _clientPage = 0;
        final pageItems = sorted.take(_pageSize).toList();
        state = PaginatedList(
          items: pageItems,
          loading: false,
          hasMore: sorted.length > pageItems.length,
        );
      } catch (e) {
        state = state.copyWith(loading: false, error: e.toString());
      }
      return;
    }
    _sortedCache = null;
    try {
      final res = await _buildQuery().range(0, _pageSize - 1);
      _page = 0;
      final items = (res as List)
          .cast<Map<String, dynamic>>()
          .map((e) => Event.fromMap(e))
          .toList();
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
    if (_distanceSort != null && _sortedCache != null) {
      state = state.copyWith(loadingMore: true);
      final nextPage = _clientPage + 1;
      final start = nextPage * _pageSize;
      final end = start + _pageSize;
      final pageItems = _sortedCache!.sublist(
        start,
        end > _sortedCache!.length ? _sortedCache!.length : end,
      );
      _clientPage = nextPage;
      state = PaginatedList(
        items: [...state.items, ...pageItems],
        loading: false,
        loadingMore: false,
        hasMore: end < _sortedCache!.length,
      );
      return;
    }
    state = state.copyWith(loadingMore: true);
    final from = (_page + 1) * _pageSize;
    final to = from + _pageSize - 1;
    try {
      final res = await _buildQuery().range(from, to);
      _page++;
      final newItems = (res as List)
          .cast<Map<String, dynamic>>()
          .map((e) => Event.fromMap(e))
          .toList();
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
        .eq('status', 'published')
        .or(
          'start_date.gte.${DateTime.now().toUtc().toIso8601String()},end_date.is.null,end_date.gte.${DateTime.now().toUtc().toIso8601String()}',
        );
    if (_freeOnly) {
      query = query.eq('price', 0);
    }
    if (_paidOnly) {
      query = query.gt('price', 0);
    }
    if (_category != null && _category!.isNotEmpty) {
      query = query.eq('category', _category!);
    }
    if (_date != null) {
      final dayStart = DateTime(_date!.year, _date!.month, _date!.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      query = query
          .gte('start_date', dayStart.toUtc().toIso8601String())
          .lt('start_date', dayEnd.toUtc().toIso8601String());
    } else if (_dateFrom != null) {
      final fromStart = DateTime(
        _dateFrom!.year,
        _dateFrom!.month,
        _dateFrom!.day,
      );
      query = query.gte('start_date', fromStart.toUtc().toIso8601String());
    }
    if (_distanceSort == null &&
        (_priceSort == 'low' || _priceSort == 'high')) {
      return query.order('price', ascending: _priceSort == 'low');
    }
    if (_distanceSort == null) {
      if (_priceSort == 'soonest') {
        return query.order('start_date', ascending: true);
      }
      return query.order('start_date', ascending: false);
    }
    return query.order('start_date', ascending: true);
  }

  List<Event> _sortByDistance(List<Event> items) {
    final loc = ref.read(locationControllerProvider);
    final sorted = List<Event>.from(items);
    sorted.sort((a, b) {
      final da = eventDistanceKm(a, loc.latitude, loc.longitude);
      final db = eventDistanceKm(b, loc.latitude, loc.longitude);
      if (da != null && db != null) {
        final diff = da - db;
        if (diff.abs() > 0.001) {
          return _distanceSort == 'farToNear'
              ? db.compareTo(da)
              : da.compareTo(db);
        }
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
    return sorted;
  }

  Future<void> refresh() async {
    _page = 0;
    _clientPage = 0;
    _sortedCache = null;
    await fetchFirstPage(showLoading: false);
  }
}
