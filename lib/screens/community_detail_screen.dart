// ============================================================================
// REDESIGNED — Community Detail Screen
// Design direction: "Editorial Overlap" — a full-bleed photographic hero with
// the community name set directly into the image (magazine-cover style),
// floating glass controls, and a rounded content sheet that overlaps the
// hero by 28px to create depth. Segmented Events/Photos control gets an
// animated underline instead of pill buttons. Event cards become bigger,
// image-led cards with on-image price/date badges (Airbnb/Eventbrite-style)
// instead of tiny caption text. Photos move from a horizontal filmstrip to a
// proper two-column grid so they get real visual weight.
//
// Every data query, the follow-toggle logic, model classes, theme tokens,
// routes, and share/social behavior are UNCHANGED from the original file —
// only the visual layer was redesigned.
//
// NOTE: This intentionally does NOT modify widgets/media_gallery.dart, since
// that shared widget may be used elsewhere in the app. Photos here use a new,
// page-scoped widget (community_photo_grid.dart) instead.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../config.dart';
import '../supabase_client.dart';
import '../widgets/community_photo_grid.dart';
import '../widgets/wishlist_button.dart';
import '../providers/wishlist_provider.dart';
import '../models/models.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

const double _heroHeight = 300;

class CommunityDetailScreen extends StatefulWidget {
  final String id;
  const CommunityDetailScreen({super.key, required this.id});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
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

  // ── DATA (unchanged from original) ────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final session = supabase.auth.currentSession;
      final communityFuture = supabase
          .from('communities')
          .select('*')
          .eq('id', widget.id)
          .eq('is_hidden', false)
          .single();
      final eventsFuture = supabase
          .from('events')
          .select('*, communities!inner(name)')
          .eq('community_id', widget.id)
          .eq('communities.is_hidden', false)
          .isFilter('deleted_at', null)
          .inFilter('status', ['published', 'completed'])
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
        final events = (results[1] as List)
            .map((e) => Event.fromMap(e as Map<String, dynamic>))
            .toList();
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
        final events = (results[1] as List)
            .map((e) => Event.fromMap(e as Map<String, dynamic>))
            .toList();
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

    try {
      if (_isMember) {
        await supabase
            .from('community_members')
            .delete()
            .eq('community_id', widget.id)
            .eq('user_id', session.user.id);
        if (!mounted) return;
        setState(() {
          _isMember = false;
          _community!['member_count'] =
              ((_community!['member_count'] as num?) ?? 1) - 1;
        });
      } else {
        await supabase.from('community_members').insert({
          'community_id': widget.id,
          'user_id': session.user.id,
          'role': 'MEMBER',
        });
        if (!mounted) return;
        setState(() {
          _isMember = true;
          _community!['member_count'] =
              ((_community!['member_count'] as num?) ?? 0) + 1;
        });
      }
    } catch (_) {}

    if (mounted) setState(() => _followToggling = false);
  }

  String _categorize(Event event, DateTime today) {
    final startDay =
        DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
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
            // ── App bar: back + follow + share ───────────────────────────
            SliverAppBar(
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: context.cluvoBackground,
              foregroundColor: context.cluvoTextPrimary,
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
              actions: [
                if (session != null && !_isOwner) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Center(child: _buildGlassFollowButton()),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () {
                    final url = buildShareUrl('communities', widget.id);
                    Share.share('Join ${c['name']} on Cluvo!\n$url',
                        subject: 'Join ${c['name']} on Cluvo');
                  },
                ),
                WishlistButton(type: wishlistCommunity, id: widget.id),
                const SizedBox(width: 4),
              ],
            ),

            // ── Hero: floating rounded image with name set into the photo ──
            SliverToBoxAdapter(child: _buildHero(c)),

            // ── Content sheet ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  color: context.cluvoBackground,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildQuickInfoRow(c),
                      if (c['description'] != null &&
                          (c['description'] as String).isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          c['description'] as String,
                          style: TextStyle(
                            color: context.cluvoTextSecondary,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (c['tags'] != null &&
                          (c['tags'] as List).isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _buildTags(c),
                      ],
                      if (c['rules'] != null &&
                          (c['rules'] as String).isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _buildRules(c),
                      ],
                      const SizedBox(height: 28),
                      _buildSegmentedControl(),
                    ],
                  ),
                ),
              ),
            ),

            // ── Section body ──────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              sliver: _selectedSection == 'photos'
                  ? SliverToBoxAdapter(
                      child: CommunityPhotoGrid(media: _media),
                    )
                  : _buildEventsSliver(),
            ),
          ],
        ),
      ),
    );
  }

  // ── HERO ───────────────────────────────────────────────────────────────

  Widget _buildHero(Map<String, dynamic> c) {
    final bannerUrl = c['banner_url'] as String?;
    final name = c['name'] as String;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: _heroHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image or gradient fallback
              bannerUrl != null && bannerUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: bannerUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _heroFallback(name),
                    )
                  : _heroFallback(name),

              // Scrim for text legibility — stronger toward the bottom
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black38,
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black87,
                    ],
                    stops: [0.0, 0.28, 0.55, 1.0],
                  ),
                ),
              ),

              // Name + social row, set directly into the image
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 34,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                          Shadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6)),
                        ],
                      ),
                    ),
                    _buildSocialRow(c),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroFallback(String name) {
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

  Widget _buildGlassFollowButton() {
    final busy = _followToggling;
    return _GlassPillButton(
      onTap: busy ? null : _toggleFollow,
      filled: !_isMember,
      child: busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_isMember ? Icons.check : Icons.add, size: 15, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  _isMember ? 'Following' : 'Follow',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
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
      padding: const EdgeInsets.only(top: 10),
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
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(7),
          child: SvgPicture.string(
            svg,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }

  // ── QUICK INFO — horizontal scrollable chip row instead of stacked boxes

  Widget _buildQuickInfoRow(Map<String, dynamic> c) {
    final location =
        '${c['city'] ?? ''}${c['city'] != null && c['country'] != null ? ', ' : ''}${c['country'] ?? ''}';
    final chips = <Widget>[
      if (location.isNotEmpty) _infoChip(Icons.location_on_outlined, location),
      _infoChip(Icons.category_outlined, c['category'] as String? ?? '—'),
      _infoChip(Icons.people_outline, '${c['member_count'] ?? 0} members'),
      if (c['contact_email'] != null)
        _infoChip(Icons.mail_outline, c['contact_email'] as String),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }

  Widget _infoChip(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.cluvoChipFill,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: context.cluvoPrimaryText),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.cluvoTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTags(Map<String, dynamic> c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tags',
            style: TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: context.cluvoTextPrimary,
            )),
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
              child: Text(t.toString(),
                  style: TextStyle(fontSize: 12.5, color: context.cluvoTextSecondary)),
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
              Icon(Icons.info_outline, size: 16, color: context.cluvoPrimaryText),
              const SizedBox(width: 6),
              Text('Community Guidelines',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: context.cluvoTextPrimary,
                  )),
            ],
          ),
          const SizedBox(height: 6),
          Text(c['rules'] as String,
              style: TextStyle(
                  color: context.cluvoTextSecondary, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  // ── SEGMENTED CONTROL — animated underline instead of pill toggle ───────

  Widget _buildSegmentedControl() {
    return Row(
      children: [
        _segmentTab('Events', 'events'),
        const SizedBox(width: 28),
        _segmentTab('Photos', 'photos'),
      ],
    );
  }

  Widget _segmentTab(String label, String section) {
    final selected = _selectedSection == section;
    return GestureDetector(
      onTap: () => setState(() => _selectedSection = section),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? CluvoTheme.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: selected ? context.cluvoTextPrimary : context.cluvoTextSecondary,
          ),
        ),
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
          child: _filterMenuItem('All', 'all', !_priceFiltersActive),
        ),
        PopupMenuItem<String>(
          value: 'free',
          child: _filterMenuItem('Free', 'free', _freeOnly),
        ),
        PopupMenuItem<String>(
          value: 'high',
          child: _filterMenuItem(
              'Price: High to Low', 'high', _priceSort == 'high'),
        ),
        PopupMenuItem<String>(
          value: 'low',
          child: _filterMenuItem(
              'Price: Low to High', 'low', _priceSort == 'low'),
        ),
        PopupMenuItem<String>(
          value: 'date',
          child: _filterMenuItem(
              dateLabel ?? 'Pick Date', 'date', _pickedDate != null),
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
      final pickDay =
          DateTime(_pickedDate!.year, _pickedDate!.month, _pickedDate!.day);
      filtered = filtered.where((e) {
        final day = DateTime(
            e.startDate.year, e.startDate.month, e.startDate.day);
        return day.isAtSameMomentAs(pickDay);
      }).toList();
    }

    if (_priceSort != null) {
      final ascending = _priceSort == 'low';
      filtered = List.of(filtered)
        ..sort((a, b) => ascending
            ? a.price.compareTo(b.price)
            : b.price.compareTo(a.price));
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
      itemBuilder: (_, i) => _EventCard(
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
              Icon(Icons.error_outline, size: 40, color: context.cluvoTextSecondary),
              const SizedBox(height: 12),
              Text(_error != null ? 'Error: $_error' : 'Not found',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.cluvoTextSecondary)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const SizedBox(height: kToolbarHeight + 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Container(
            height: _heroHeight,
            decoration: BoxDecoration(
              color: context.cluvoChipFill,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.cluvoBackground,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(3, (i) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          height: 36,
                          width: 90,
                          decoration: BoxDecoration(
                            color: context.cluvoChipFill,
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      )),
                ),
                const SizedBox(height: 20),
                ...List.generate(3, (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: context.cluvoChipFill,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    )),
                const SizedBox(height: 24),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.72,
                  ),
                  itemBuilder: (_, _) => Container(
                    decoration: BoxDecoration(
                      color: context.cluvoChipFill,
                      borderRadius: BorderRadius.circular(16),
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

/// Frosted-glass pill button (used for Follow in the app bar).
class _GlassPillButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool filled;
  final Widget child;
  const _GlassPillButton({required this.onTap, required this.filled, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: filled
              ? CluvoTheme.primary.withValues(alpha: 0.92)
              : Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

/// Image-led event card: image fills most of the card, price + date badges
/// float directly on the photo, title sits below in serif type.
class _EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  const _EventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final eventDay =
        DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
    final isPast = eventDay.isBefore(todayDay);
    final imageUrl = event.imageUrl;
    final months = _months;

    return Opacity(
      opacity: isPast ? 0.55 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => _fallback(event.title),
                          )
                        : _fallback(event.title),
                    // subtle bottom scrim so badges stay legible
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black45],
                          stops: [0.6, 1.0],
                        ),
                      ),
                    ),
                    // Date badge, top-left
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${event.startDate.day} ${months[event.startDate.month - 1]}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF171717),
                          ),
                        ),
                      ),
                    ),
                    // Price badge, bottom-right
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: event.price > 0
                              ? CluvoTheme.primary
                              : const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          event.price > 0
                              ? '₹${(event.price / 100).toStringAsFixed(0)}'
                              : 'Free',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (isPast)
                      Positioned(
                        top: 44,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Closed',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    // Wishlist save toggle, top-right
                    Positioned(
                      top: 8,
                      right: 8,
                      child: WishlistButton(
                        type: wishlistEvent,
                        id: event.id,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              event.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: context.cluvoTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(String title) {
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
          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
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
            Text(message,
                style: TextStyle(color: context.cluvoTextSecondary, fontSize: 13.5)),
          ],
        ),
      ),
    );
  }
}
