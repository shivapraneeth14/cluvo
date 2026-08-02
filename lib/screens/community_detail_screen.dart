import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../supabase_client.dart';
import '../widgets/media_gallery.dart';
import '../models/models.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

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
  String _selectedSection = 'events';

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
        final events = (results[1] as List).map((e) => Event.fromMap(e as Map<String, dynamic>)).toList();
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
        final events = (results[1] as List).map((e) => Event.fromMap(e as Map<String, dynamic>)).toList();
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
          _community!['member_count'] = ((_community!['member_count'] as num?) ?? 1) - 1;
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
          _community!['member_count'] = ((_community!['member_count'] as num?) ?? 0) + 1;
        });
      }
    } catch (_) {}

    if (mounted) setState(() => _followToggling = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: _buildSkeleton(),
      );
    }

    if (_error != null || _community == null) {
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
                const Icon(Icons.error_outline, size: 40, color: Colors.grey),
                const SizedBox(height: 12),
                Text(_error != null ? 'Error: $_error' : 'Not found',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    _loading = true;
                    _load();
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Tap to Retry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC2185B),
                    side: const BorderSide(color: Color(0xFFC2185B)),
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

    final c = _community!;
    final bannerUrl = c['banner_url'] as String?;
    final name = c['name'] as String;
    final session = supabase.auth.currentSession;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await _load();
        },
        child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: false,
            stretch: true,
            backgroundColor: const Color(0xFFC2185B),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/communities');
                  }
                },
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: bannerUrl != null && bannerUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: bannerUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorWidget: (_, _, _) => _buildBannerFallback(name),
                    )
                  : _buildBannerFallback(name),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (session != null && !_isOwner)
                        _buildFollowButton(),
                      _buildShareButton(),
                    ],
                  ),
                  _buildSocialRow(c),
                  if (c['description'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      c['description'] as String,
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _infoRow('Category', c['category'] as String? ?? '—'),
                  _infoRow(
                      'Members', '${c['member_count'] ?? 0}'),
                  _infoRow(
                      'Location',
                      '${c['city'] ?? ''}${c['city'] != null && c['country'] != null ? ', ' : ''}${c['country'] ?? '—'}'),
                  if (c['contact_email'] != null)
                    _infoRow('Contact', c['contact_email'] as String),
                  if (c['tags'] != null &&
                      (c['tags'] as List).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Tags',
                        style: TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: (c['tags'] as List).map((t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(t.toString(),
                                style: const TextStyle(fontSize: 12)),
                          )).toList(),
                    ),
                  ],
                  if (c['rules'] != null &&
                      (c['rules'] as String).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text('Rules',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(c['rules'] as String,
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildSectionToggle('Events', 'events'),
                      const SizedBox(width: 8),
                      _buildSectionToggle('Photos', 'photos'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_selectedSection == 'photos')
                    MediaGallery(
                      media: _media,
                      label: 'Community Photos',
                    )
                  else ...[
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _buildFilterChip('All', null),
                          const SizedBox(width: 6),
                          _buildFilterChip('Today', 'today'),
                          const SizedBox(width: 6),
                          _buildFilterChip('Upcoming', 'upcoming'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_events.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No events in this community.',
                              style: TextStyle(color: Colors.grey[500])),
                        ),
                      )
                    else
                      ..._buildEventGrid(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
        ),
    );
  }

  Widget _buildFollowButton() {
    return SizedBox(
      height: 32,
      child: _isMember
          ? OutlinedButton.icon(
              onPressed: _followToggling ? null : _toggleFollow,
              icon: _followToggling
                  ? const SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, size: 14),
              label: const Text('Following', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC2185B),
                side: const BorderSide(color: Color(0xFFC2185B)),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: _followToggling ? null : _toggleFollow,
              icon: _followToggling
                  ? const SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add, size: 14),
              label: const Text('Follow', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC2185B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
    );
  }

  Widget _buildShareButton() {
    final name = _community?['name'] as String? ?? 'Community';
    final id = widget.id;
    return SizedBox(
      height: 32,
      child: IconButton(
        icon: const Icon(Icons.share, size: 18),
        style: IconButton.styleFrom(
          foregroundColor: const Color(0xFFC2185B),
          backgroundColor: const Color(0xFFC2185B).withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: () {
          final url = buildShareUrl('communities', id);
          Share.share('Join $name on Cluvo!\n$url',
              subject: 'Join $name on Cluvo');
        },
      ),
    );
  }

  Widget _buildBannerFallback(String name) {
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
            fontSize: 56,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _categorize(Event event, DateTime today) {
    final startDay = DateTime(event.startDate.year, event.startDate.month, event.startDate.day);
    if (startDay.isBefore(today)) return 'past';
    if (startDay.isAtSameMomentAs(today)) return 'today';
    return 'upcoming';
  }

  Widget _buildFilterChip(String label, String? category) {
    final selected = _eventFilter == category;
    return GestureDetector(
      onTap: () => setState(() => _eventFilter = selected ? null : category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFC2185B) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionToggle(String label, String section) {
    final selected = _selectedSection == section;
    return GestureDetector(
      onTap: () => setState(() => _selectedSection = section),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFC2185B) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEventGrid() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final filtered = _eventFilter == null
        ? _events
        : _events.where((e) => _categorize(e, today) == _eventFilter).toList();

    if (filtered.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'No ${_eventFilter ?? ""} events.',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ),
        ),
      ];
    }

    final rows = <Widget>[];
    for (var i = 0; i < filtered.length; i += 3) {
      final rowEvents = filtered.sublist(i, i + 3 > filtered.length ? filtered.length : i + 3);
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: rowEvents.map((e) => Expanded(child: _buildGridCard(e))).toList(),
          ),
        ),
      );
    }
    return rows;
  }

  Widget _buildGridCard(Event e) {
    final title = e.title;
    final imageUrl = e.imageUrl;
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final eventDay = DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
    final isPast = eventDay.isBefore(todayDay);
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          onTap: () => context.push('/events/${e.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorWidget: (_, _, _) =>
                                _buildGridFallback(title),
                          )
                        : _buildGridFallback(title),
                    if (isPast)
                      Container(
                        color: Colors.black45,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Closed',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
                child: Opacity(
                  opacity: isPast ? 0.5 : 1.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatShortDate(e),
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      e.price > 0
                          ? '₹${(e.price / 100).toStringAsFixed(0)}'
                          : 'Free',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: e.price > 0
                            ? const Color(0xFFC2185B)
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildGridFallback(String title) {
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Container(
          height: 220,
          color: Colors.grey[200],
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 20, width: 200, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 12),
              Container(height: 14, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 8),
              Container(height: 14, width: 160, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 20),
              ...List.generate(4, (_) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(height: 14, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
              )),
              const SizedBox(height: 20),
              Row(
                children: List.generate(3, (_) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        children: [
                          AspectRatio(aspectRatio: 1, child: Container(color: Colors.grey[200])),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
                            child: Column(
                              children: [
                                Container(height: 8, width: 50, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
                                const SizedBox(height: 4),
                                Container(height: 6, width: 30, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatShortDate(Event event) {
    return '${event.startDate.day} ${_months[event.startDate.month - 1]}';
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
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          if (social.containsKey('instagram_url'))
            _socialSvg(_instagramSvg, social['instagram_url']!),
          if (social.containsKey('facebook_url'))
            _socialSvg(_facebookSvg, social['facebook_url']!),
          if (social.containsKey('twitter_url'))
            _socialSvg(_twitterSvg, social['twitter_url']!),
          if (social.containsKey('linkedin_url'))
            _socialSvg(_linkedinSvg, social['linkedin_url']!),
        ],
      ),
    );
  }

  Widget _socialSvg(String svg, String url) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: SvgPicture.string(
          svg,
          width: 20,
          height: 20,
          colorFilter: ColorFilter.mode(Colors.grey[600]!, BlendMode.srcIn),
        ),
      ),
    );
  }

  String get _instagramSvg => '''<svg viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z"/></svg>''';

  String get _facebookSvg => '''<svg viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/></svg>''';

  String get _twitterSvg => '''<svg viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>''';

  String get _linkedinSvg => '''<svg viewBox="0 0 24 24" fill="currentColor" xmlns="http://www.w3.org/2000/svg"><path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/></svg>''';
}
