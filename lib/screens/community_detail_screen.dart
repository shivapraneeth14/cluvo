// ============================================================================
// REDESIGNED — Community Detail Screen
//
// Layout order (top → bottom):
//   1. Safe-area-aware action bar  (back · follow · share · bookmark)
//   2. Full-width community cover
//   3. Community name + tagline + social links over the cover
//   4. Community information cards (location · category · members)
//   5. About Us (full community description)
//   6. Community guidelines / tags
//   7. Existing Events / Photos tabs
//   8. Media heading, real count, All/Photos/Videos filters, Grid/List toggle
//
// All data queries, the follow-toggle logic, model classes, theme tokens,
// routes and share/social behavior are UNCHANGED — only the visual layer was
// redesigned. The Events tab content and the existing full-screen viewers
// remain intact; the media gallery reuses `CommunityMediaSection` which opens
// the view-only photo viewer and the real video player.
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/external_links.dart';
import '../utils/category_icons.dart';
import '../theme.dart';
import '../config.dart';
import '../supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/media/community_media_section.dart';
import '../widgets/events/event_grid_card.dart';
import '../widgets/lifecycle_ticker.dart';
import '../widgets/wishlist_button.dart';
import '../providers/wishlist_provider.dart';
import '../providers/community_provider.dart';
import '../models/models.dart';

const double _coverMaxHeight = 300;
const double _coverMinHeight = 220;

// Community events tab ordering: live first, active next, closed after,
// cancelled last — each by most recent start_date.
List<Event> _sortCommunityEvents(List<Event> events) {
  final sorted = List<Event>.from(events);
  int rank(Event e) {
    switch (e.lifecycle()) {
      case EventLifecycle.live:
        return 0;
      case EventLifecycle.active:
        return 1;
      case EventLifecycle.closed:
        return 2;
      case EventLifecycle.cancelled:
        return 3;
    }
  }

  sorted.sort((a, b) {
    final ra = rank(a);
    final rb = rank(b);
    if (ra != rb) return ra.compareTo(rb);
    return b.startDate.compareTo(a.startDate);
  });
  return sorted;
}

class CommunityDetailScreen extends StatefulWidget {
  final String id;
  const CommunityDetailScreen({super.key, required this.id});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen>
    with LifecycleTickerMixin<CommunityDetailScreen> {
  Map<String, dynamic>? _community;
  List<Event> _events = [];
  List<Map<String, dynamic>> _media = [];
  bool _loading = true;
  String? _error;
  bool _isMember = false;
  bool _isOwner = false;
  bool _followToggling = false;
  String? _eventFilter;
  bool _freeOnly = false;
  String? _priceSort;
  DateTime? _pickedDate;
  final _filterKey = GlobalKey();
  String _selectedSection = 'events';
  RealtimeChannel? _eventsChannel;
  Timer? _realtimeDebounce;

  // ── DATA (unchanged from original) ────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _load();
    startLifecycleTick();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _eventsChannel?.unsubscribe();
    _realtimeDebounce?.cancel();
    super.dispose();
  }

  // 60s tick: re-sort + lifecycle chips update without a refresh.
  @override
  void onLifecycleTick() {
    if (!mounted) return;
    setState(() {});
  }

  void _subscribeRealtime() {
    _eventsChannel = supabase
        .channel('community-events-${widget.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'community_id',
            value: widget.id,
          ),
          callback: (_) {
            _realtimeDebounce?.cancel();
            _realtimeDebounce = Timer(const Duration(seconds: 2), () {
              if (mounted) _load();
            });
          },
        )
        .subscribe();
  }

  Future<void> _load() async {
    try {
      final session = supabase.auth.currentSession;
      final communityFuture = supabase
          .from('communities')
          .select(communityProfileColumns)
          .eq('id', widget.id)
          .eq('is_hidden', false)
          .single();
      final eventsFuture = supabase
          .from('events')
          .select('*, communities!inner(name)')
          .eq('community_id', widget.id)
          .eq('communities.is_hidden', false)
          .isFilter('deleted_at', null)
          .inFilter('status', ['published', 'completed', 'cancelled'])
          .order('start_date', ascending: false)
          .limit(50);

      bool isMember = false;
      bool isOwner = false;

      final mediaFuture = supabase
          .from('media')
          .select('*')
          .eq('mediable_type', 'community')
          .eq('mediable_id', widget.id)
          .order('sort_order');

      if (session != null) {
        final results = await Future.wait([
          communityFuture,
          eventsFuture,
          mediaFuture,
          supabase
              .from('community_members')
              .select('role')
              .eq('community_id', widget.id)
              .eq('user_id', session.user.id)
              .maybeSingle(),
        ]).timeout(const Duration(seconds: 30));
        if (!mounted) return;
        final memberRes = results[3];
        if (memberRes != null) {
          isMember = true;
          isOwner = (memberRes as Map<String, dynamic>)['role'] == 'OWNER';
        }
        final events = _sortCommunityEvents(
          (results[1] as List)
              .map((e) => Event.fromMap(e as Map<String, dynamic>))
              .toList(),
        );
        setState(() {
          _community = results[0] as Map<String, dynamic>?;
          _events = events;
          _media = (results[2] as List).cast<Map<String, dynamic>>();
          _isMember = isMember;
          _isOwner = isOwner;
          _loading = false;
        });
      } else {
        final results = await Future.wait([
          communityFuture,
          eventsFuture,
          mediaFuture,
        ]).timeout(const Duration(seconds: 30));
        if (!mounted) return;
        final events = _sortCommunityEvents(
          (results[1] as List)
              .map((e) => Event.fromMap(e as Map<String, dynamic>))
              .toList(),
        );
        setState(() {
          _community = results[0] as Map<String, dynamic>?;
          _events = events;
          _media = (results[2] as List).cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_followToggling) return;
    final session = supabase.auth.currentSession;
    if (session == null) return;
    setState(() => _followToggling = true);

    final wasMember = _isMember;
    try {
      if (wasMember) {
        await supabase
            .from('community_members')
            .delete()
            .eq('community_id', widget.id)
            .eq('user_id', session.user.id);
      } else {
        await supabase.from('community_members').insert({
          'community_id': widget.id,
          'user_id': session.user.id,
          'role': 'MEMBER',
        });
      }
      // Re-read the row so the count comes from the database-maintained
      // column (updated by trigger), not client-side arithmetic.
      final refreshed = await supabase
          .from('communities')
          .select(communitySelectColumns)
          .eq('id', widget.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _isMember = !wasMember;
        if (refreshed != null) _community = refreshed;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasMember
                  ? 'You left this community.'
                  : 'You joined this community!',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasMember
                ? 'Could not leave community. Please try again.'
                : 'Could not join community. Please try again.',
          ),
          backgroundColor: context.cluvoErrorText,
        ),
      );
    }

    if (mounted) setState(() => _followToggling = false);
  }

  String _categorize(Event event, DateTime today) {
    final startDay = DateTime(
      event.startDate.year,
      event.startDate.month,
      event.startDate.day,
    );
    if (startDay.isBefore(today)) return 'past';
    if (startDay.isAtSameMomentAs(today)) return 'today';
    return 'upcoming';
  }

  // ── BUILD ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(body: _buildSkeleton());
    }

    if (_error != null || _community == null) {
      return _buildErrorState();
    }

    final c = _community!;
    final session = supabase.auth.currentSession;

    return Scaffold(
      backgroundColor: context.cluvoBackground,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            // ── 1. Action bar: back · follow · share · bookmark ──────────
            _buildActionBar(c, session),

            // ── 2–3. Full-width cover with name / tagline / socials ──────
            SliverToBoxAdapter(child: _buildCover(c)),

            // ── 4. Community information cards ───────────────────────────
            SliverToBoxAdapter(child: _buildInfoCards(c)),

            // ── 5. About Us (full description) ──────────────────────────
            SliverToBoxAdapter(child: _buildAbout(c)),

            // ── 6. Guidelines + tags (existing content, compact) ─────────
            SliverToBoxAdapter(child: _buildExtraInfo(c)),

            // ── 7. Existing Events / Photos tabs ─────────────────────────
            SliverToBoxAdapter(child: _buildTabs()),

            // ── 8. Section body (events or media gallery) ────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              sliver: _selectedSection == 'photos'
                  ? SliverToBoxAdapter(
                      child: CommunityMediaSection(media: _media),
                    )
                  : _buildEventsSliver(),
            ),
          ],
        ),
      ),
    );
  }

  // ── 1. ACTION BAR ───────────────────────────────────────────────────────

  SliverAppBar _buildActionBar(Map<String, dynamic> c, Session? session) {
    final canFollow = session != null && !_isOwner;

    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.white,
      foregroundColor: CluvoTheme.textPrimaryColor,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      shape: const Border(
        bottom: BorderSide(
          color: CluvoTheme.borderLavender,
          width: CluvoTheme.hairline,
        ),
      ),
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      leadingWidth: 62,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Center(
          child: _CircleIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: _goBack,
          ),
        ),
      ),
      actions: [
        if (canFollow) ...[
          Center(
            child: _FollowPillButton(
              busy: _followToggling,
              following: _isMember,
              onTap: _toggleFollow,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Center(
          child: _CircleIconButton(
            icon: Icons.ios_share,
            tooltip: 'Share',
            onTap: () => _shareCommunity(c),
          ),
        ),
        const SizedBox(width: 8),
        Center(
          child: WishlistButton(
            type: wishlistCommunity,
            id: widget.id,
            size: 44,
            variant: WishlistButtonVariant.light,
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/communities');
    }
  }

  void _shareCommunity(Map<String, dynamic> c) {
    final url = buildShareUrl('communities', widget.id);
    Share.share(
      'Join ${c['name']} on Cluvo!\n$url',
      subject: 'Join ${c['name']} on Cluvo',
    );
  }

  // ── 2–3. COVER ──────────────────────────────────────────────────────────

  Widget _buildCover(Map<String, dynamic> c) {
    final bannerUrl = c['banner_url'] as String?;
    final name = (c['name'] as String?) ?? '';
    final tagline = (c['description'] as String?)?.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxWidth / 1.5).clamp(
          _coverMinHeight,
          _coverMaxHeight,
        );
        return SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              bannerUrl != null && bannerUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: bannerUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => _heroFallback(name),
                      errorWidget: (_, _, _) => _heroFallback(name),
                    )
                  : _heroFallback(name),

              // Bottom-to-top scrim so the white overlay text stays readable
              // without hiding the cover art.
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.18),
                      Colors.black.withValues(alpha: 0.62),
                    ],
                    stops: const [0.35, 0.62, 1.0],
                  ),
                ),
              ),

              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 30,
                        height: 1.08,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    if (tagline != null && tagline.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          tagline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            height: 1.3,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black45,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    _buildSocialRow(c),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _heroFallback(String name) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [CluvoTheme.primary, CluvoTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'C',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 96,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialRow(Map<String, dynamic> c) {
    final social = <String, String>{};
    if (c['instagram_url'] case final String url when url.isNotEmpty) {
      social['instagram_url'] = url;
    }
    if (c['facebook_url'] case final String url when url.isNotEmpty) {
      social['facebook_url'] = url;
    }
    if (c['twitter_url'] case final String url when url.isNotEmpty) {
      social['twitter_url'] = url;
    }
    if (c['linkedin_url'] case final String url when url.isNotEmpty) {
      social['linkedin_url'] = url;
    }
    if (social.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          if (social.containsKey('instagram_url'))
            _socialGlassIcon(_instagramSvg, social['instagram_url']!),
          if (social.containsKey('facebook_url'))
            _socialGlassIcon(_facebookSvg, social['facebook_url']!),
          if (social.containsKey('twitter_url'))
            _socialGlassIcon(_twitterSvg, social['twitter_url']!),
          if (social.containsKey('linkedin_url'))
            _socialGlassIcon(_linkedinSvg, social['linkedin_url']!),
        ],
      ),
    );
  }

  Widget _socialGlassIcon(String svg, String url) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        label: 'Open social link in browser',
        button: true,
        onTap: () => openExternalLink(url),
        child: GestureDetector(
          onTap: () => openExternalLink(url),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            padding: const EdgeInsets.all(10),
            child: SvgPicture.string(
              svg,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 4. INFORMATION CARDS ────────────────────────────────────────────────

  Widget _buildInfoCards(Map<String, dynamic> c) {
    final city = (c['city'] as String?)?.trim();
    final country = (c['country'] as String?)?.trim();
    var location = [
      city,
      country,
    ].where((v) => v != null && v.isNotEmpty).join(', ');
    if (location.isEmpty) {
      location = (c['location'] as String?)?.trim() ?? '';
    }
    final category = (c['category'] as String?)?.trim();

    final cards = <Widget>[
      if (location.isNotEmpty)
        _infoCard(Icons.location_on_outlined, 'Location', location),
      if (category != null && category.isNotEmpty)
        _infoCard(categoryIcon(category), 'Category', category),
      _infoCard(
        Icons.people_alt_outlined,
        'Members',
        _formatCount(c['member_count']),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: cards[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cluvoLavenderFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: CluvoTheme.primary),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.cluvoTextPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: context.cluvoTextSecondary),
          ),
        ],
      ),
    );
  }

  String _formatCount(Object? value) {
    if (value is num) {
      final n = value.round();
      final digits = n.abs().toString();
      final buffer = StringBuffer();
      for (var i = 0; i < digits.length; i++) {
        if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
        buffer.write(digits[i]);
      }
      return n < 0 ? '-$buffer' : buffer.toString();
    }
    return '—';
  }

  // ── 5. ABOUT US ─────────────────────────────────────────────────────────

  Widget _buildAbout(Map<String, dynamic> c) {
    final about = (c['description'] as String?)?.trim() ?? '';
    if (about.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About Us',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: context.cluvoTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cluvoChipFill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              about,
              style: TextStyle(
                color: context.cluvoTextSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. GUIDELINES + TAGS (existing content) ─────────────────────────────

  Widget _buildExtraInfo(Map<String, dynamic> c) {
    final hasTags = c['tags'] != null && (c['tags'] as List).isNotEmpty;
    final hasRules =
        c['rules'] != null && (c['rules'] as String).trim().isNotEmpty;
    if (!hasTags && !hasRules) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTags) _buildTags(c),
          if (hasTags && hasRules) const SizedBox(height: 18),
          if (hasRules) _buildRules(c),
        ],
      ),
    );
  }

  // ── 7. TABS ─────────────────────────────────────────────────────────────

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(child: _tab('Events', 'events')),
                Expanded(child: _tab('Photos', 'photos')),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: context.cluvoBorder),
        ],
      ),
    );
  }

  Widget _tab(String label, String section) {
    final selected = _selectedSection == section;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedSection = section),
      child: Center(
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? CluvoTheme.primary
                      : context.cluvoTextSecondary,
                ),
              ),
              const SizedBox(height: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                height: 2.5,
                color: selected ? CluvoTheme.primary : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTags(Map<String, dynamic> c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: context.cluvoTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: (c['tags'] as List).map((t) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: context.cluvoBorder),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                t.toString(),
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.cluvoTextSecondary,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRules(Map<String, dynamic> c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cluvoChipFill,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: CluvoTheme.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: context.cluvoPrimaryText,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Community Guidelines',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: context.cluvoTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            c['rules'] as String,
            style: TextStyle(
              color: context.cluvoTextSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── EVENTS — bigger, image-led cards with on-image badges ───────────────

  Widget _buildEventsSliver() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip('All', null),
                      const SizedBox(width: 8),
                      _buildFilterChip('Today', 'today'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Upcoming', 'upcoming'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                key: _filterKey,
                child: IconButton(
                  onPressed: _openEventFilterMenu,
                  icon: const Icon(Icons.filter_list),
                  style: IconButton.styleFrom(
                    backgroundColor: _priceFiltersActive
                        ? CluvoTheme.primary.withValues(alpha: 0.12)
                        : context.cluvoChipFill,
                    foregroundColor: _priceFiltersActive
                        ? CluvoTheme.primary
                        : context.cluvoTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildEventsGrid(),
        ],
      ),
    );
  }

  bool get _priceFiltersActive =>
      _freeOnly || _priceSort != null || _pickedDate != null;

  Future<void> _pickEventDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _pickedDate = picked);
    }
  }

  Future<void> _openEventFilterMenu() async {
    final box = _filterKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
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
          child: _filterMenuItem('All', 'all', !_priceFiltersActive),
        ),
        PopupMenuItem<String>(
          value: 'free',
          child: _filterMenuItem('Free', 'free', _freeOnly),
        ),
        PopupMenuItem<String>(
          value: 'high',
          child: _filterMenuItem(
            'Price: High to Low',
            'high',
            _priceSort == 'high',
          ),
        ),
        PopupMenuItem<String>(
          value: 'low',
          child: _filterMenuItem(
            'Price: Low to High',
            'low',
            _priceSort == 'low',
          ),
        ),
        PopupMenuItem<String>(
          value: 'date',
          child: _filterMenuItem(
            dateLabel ?? 'Pick Date',
            'date',
            _pickedDate != null,
          ),
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
        break;
      case 'free':
        setState(() => _freeOnly = !_freeOnly);
        break;
      case 'high':
        setState(() => _priceSort = _priceSort == 'high' ? null : 'high');
        break;
      case 'low':
        setState(() => _priceSort = _priceSort == 'low' ? null : 'low');
        break;
      case 'date':
        await _pickEventDate();
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

  Widget _buildFilterChip(String label, String? category) {
    final selected = _eventFilter == category;
    return GestureDetector(
      onTap: () => setState(() => _eventFilter = selected ? null : category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
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
    );
  }

  Widget _buildEventsGrid() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var filtered = _eventFilter == null
        ? _events
        : _events.where((e) => _categorize(e, today) == _eventFilter).toList();

    if (_freeOnly) {
      filtered = filtered.where((e) => e.price == 0).toList();
    }

    if (_pickedDate != null) {
      final pickDay = DateTime(
        _pickedDate!.year,
        _pickedDate!.month,
        _pickedDate!.day,
      );
      filtered = filtered.where((e) {
        final day = DateTime(
          e.startDate.year,
          e.startDate.month,
          e.startDate.day,
        );
        return day.isAtSameMomentAs(pickDay);
      }).toList();
    }

    if (_priceSort != null) {
      final ascending = _priceSort == 'low';
      filtered = List.of(filtered)
        ..sort(
          (a, b) => ascending
              ? a.price.compareTo(b.price)
              : b.price.compareTo(a.price),
        );
    }

    if (filtered.isEmpty) {
      String message;
      if (_pickedDate != null) {
        message = 'No events on this date.';
      } else if (_freeOnly) {
        message = 'No free events in this community.';
      } else if (_eventFilter != null) {
        message = 'No ${_eventFilter!} events.';
      } else {
        message = 'No events in this community yet.';
      }
      return _EmptyState(icon: Icons.event_busy_outlined, message: message);
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filtered.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (_, i) => EventGridCard(
        event: filtered[i],
        onTap: () => context.push('/events/${filtered[i].id}'),
      ),
    );
  }

  // ── ERROR / SKELETON ─────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/communities');
            }
          },
        ),
      ),
      body: Center(
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
                _error != null ? 'Error: $_error' : 'Not found',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.cluvoTextSecondary),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
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
      ),
    );
  }

  Widget _buildSkeleton() {
    final chip = context.cluvoLavenderFill;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Action bar height + status bar
        SizedBox(height: MediaQuery.paddingOf(context).top + 64),
        // Cover
        LayoutBuilder(
          builder: (context, constraints) {
            final height = (constraints.maxWidth / 1.5).clamp(
              _coverMinHeight,
              _coverMaxHeight,
            );
            return Container(height: height, color: chip);
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                    child: Container(
                      height: 86,
                      decoration: BoxDecoration(
                        color: chip,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Tabs
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Container(
                        height: 18,
                        width: 90,
                        decoration: BoxDecoration(
                          color: chip,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Container(
                        height: 18,
                        width: 90,
                        decoration: BoxDecoration(
                          color: chip,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, thickness: 1, color: context.cluvoBorder),
            ],
          ),
        ),
        // Media heading + chips + grid placeholders
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 20,
                      width: 120,
                      decoration: BoxDecoration(
                        color: chip,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  Container(
                    height: 44,
                    width: 92,
                    decoration: BoxDecoration(
                      color: chip,
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: List.generate(
                  3,
                  (i) => Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                    child: Container(
                      height: 38,
                      width: 84,
                      decoration: BoxDecoration(
                        color: chip,
                        borderRadius: BorderRadius.circular(19),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 4,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 4 / 3,
                ),
                itemBuilder: (_, _) => Container(
                  decoration: BoxDecoration(
                    color: chip,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── inline SVGs (unchanged from original) ───────────────────────────────
  String get _instagramSvg =>
      '''<svg viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z"/></svg>''';
  String get _facebookSvg =>
      '''<svg viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/></svg>''';
  String get _twitterSvg =>
      '''<svg viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>''';
  String get _linkedinSvg =>
      '''<svg viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/></svg>''';
}

// ============================================================================
// Small, page-scoped supporting widgets
// ============================================================================

/// Circular white action-bar button (back, share) with a subtle border.
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: CluvoTheme.borderLavender),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 20, color: CluvoTheme.deepNavy),
          ),
        ),
      ),
    );
  }
}

/// Follow pill: filled purple with a plus when not following, lavender with a
/// check when following. Reflects (and reuses) the real follow state.
class _FollowPillButton extends StatelessWidget {
  final bool busy;
  final bool following;
  final VoidCallback onTap;
  const _FollowPillButton({
    required this.busy,
    required this.following,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = following ? CluvoTheme.primary : Colors.white;
    return Semantics(
      button: true,
      label: following ? 'Following' : 'Follow',
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: following ? context.cluvoLavenderFill : CluvoTheme.primary,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(
              color: following ? CluvoTheme.borderLavender : CluvoTheme.primary,
            ),
          ),
          alignment: Alignment.center,
          child: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: CluvoTheme.primary,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      following ? Icons.check : Icons.add,
                      size: 17,
                      color: foreground,
                    ),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 84),
                      child: Text(
                        following ? 'Following' : 'Follow',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: foreground,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: context.cluvoTextSecondary),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                color: context.cluvoTextSecondary,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
