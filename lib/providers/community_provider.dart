import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../supabase_client.dart';
import '../models/models.dart';
import '../utils.dart';
import 'paginated_provider.dart';

const _pageSize = 20;

/// Explicit, safe community columns used by every discovery/search/membership
/// query. Deliberately excludes the financial/privileged columns on the
/// `communities` table (wallet_balance, cashfree_beneficiary_id,
/// razorpay_account_*, commission_percent, commission_on, platform_fee_amount,
/// bank_*, pan, kyc_status). Those are guarded from client writes by migration
/// 202610140002 and were only revoked from `anon` SELECT by 202607300002 — see
/// the audit note about authenticated SELECT exposure. Never select('*') here.
const communitySelectColumns =
    'id,name,description,location,banner_url,'
    'community_avatar_url,owner_id,visibility,verification_status,is_hidden,'
    'member_count,event_count,category,country,state,city,tags,'
    'created_at,updated_at,deleted_at';

/// Safe columns for the community profile screen: the same non-financial set
/// plus the public contact/social fields the profile renders. Still excludes
/// every wallet / payout / commission / bank / PAN / KYC column.
const communityProfileColumns =
    '$communitySelectColumns,contact_email,'
    'contact_phone,instagram_url,facebook_url,twitter_url,linkedin_url,rules';

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

  /// Active filters, exposed so entry points can reflect state.
  String? get category => _category;

  void setCategory(String? category) {
    if (_category == category) return;
    _category = category;
    _page = 0;
    fetchFirstPage(showLoading: true);
  }

  /// Public, eligible communities ordered by real popularity (member count),
  /// with the active category/city filters applied.
  Future<List<Community>> _fetchRange(int from, int to) async {
    var query = supabase
        .from('communities')
        .select(communitySelectColumns)
        .isFilter('deleted_at', null)
        .isFilter('deletion_grace_started_at', null)
        .eq('is_hidden', false);
    if (_category != null) {
      query = query.eq('category', _category!);
    }
    final res = await query
        .order('member_count', ascending: false)
        .order('created_at', ascending: false)
        .range(from, to);
    return (res as List)
        .cast<Map<String, dynamic>>()
        .map((e) => Community.fromMap(e))
        .toList();
  }

  Future<void> fetchFirstPage({bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(loading: true, clearError: true);
    }
    try {
      final items = await _fetchRange(0, _pageSize - 1);
      _page = 0;
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
      final newItems = await _fetchRange(from, to);
      _page++;
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

/// A joined community plus the caller's real membership role.
class JoinedCommunity {
  final Community community;
  final String role;

  const JoinedCommunity({required this.community, required this.role});
}

/// The authenticated user's real memberships. Uses an inner join so rows whose
/// embedded community is unavailable (deleted or hidden) are dropped by the
/// database rather than producing a null community record on the client.
final myMembershipsProvider = FutureProvider<List<JoinedCommunity>>((
  ref,
) async {
  final session = supabase.auth.currentSession;
  if (session == null) return [];
  final response = await supabase
      .from('community_members')
      .select('role, communities!inner($communitySelectColumns)')
      .eq('user_id', session.user.id)
      .eq('communities.is_hidden', false)
      .isFilter('communities.deleted_at', null)
      .order('joined_at', ascending: false);
  final memberships = <JoinedCommunity>[];
  for (final row in (response as List)) {
    final m = row as Map<String, dynamic>;
    final comm = m['communities'];
    if (comm is! Map<String, dynamic> || comm['id'] == null) continue;
    memberships.add(
      JoinedCommunity(
        community: Community.fromMap(comm),
        role: (m['role'] as String?) ?? 'MEMBER',
      ),
    );
  }
  return memberships;
});

final myCommunitiesProvider = FutureProvider<List<Community>>((ref) async {
  final memberships = await ref.watch(myMembershipsProvider.future);
  return memberships.map((m) => m.community).toList();
});

/// Server-side community search, keyed by query so changing the query disposes
/// the previous request — the UI can never render a stale response.
final searchCommunitiesProvider = FutureProvider.autoDispose
    .family<List<Community>, String>((ref, query) async {
      final q = sanitizeSearchQuery(query);
      if (q.isEmpty) return [];
      final pattern = '%$q%';
      final res = await supabase
          .from('communities')
          .select(communitySelectColumns)
          .isFilter('deleted_at', null)
          .isFilter('deletion_grace_started_at', null)
          .eq('is_hidden', false)
          .or(
            'name.ilike.$pattern,'
            'description.ilike.$pattern,'
            'category.ilike.$pattern,'
            'city.ilike.$pattern',
          )
          .order('member_count', ascending: false)
          .limit(30);
      return (res as List)
          .cast<Map<String, dynamic>>()
          .map((e) => Community.fromMap(e))
          .toList();
    });

/// Membership mutation service. Errors are surfaced to the caller so the UI can
/// show real feedback instead of silently swallowing failures. Member counts
/// are never computed on the client — [fetchCommunity] re-reads the
/// database-maintained column after the trigger runs.
class CommunityMembershipService {
  Future<void> join(String communityId) async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      throw StateError('You need to be signed in to join a community.');
    }
    await supabase.from('community_members').insert({
      'community_id': communityId,
      'user_id': session.user.id,
      'role': 'MEMBER',
    });
  }

  Future<void> leave(String communityId) async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      throw StateError('You are not signed in.');
    }
    await supabase
        .from('community_members')
        .delete()
        .eq('community_id', communityId)
        .eq('user_id', session.user.id);
  }

  /// Reads the database-maintained member_count for one community.
  Future<Community?> fetchCommunity(String id) async {
    final res = await supabase
        .from('communities')
        .select(communitySelectColumns)
        .eq('id', id)
        .maybeSingle();
    if (res == null) return null;
    return Community.fromMap(res);
  }
}

final communityMembershipProvider = Provider<CommunityMembershipService>(
  (ref) => CommunityMembershipService(),
);
