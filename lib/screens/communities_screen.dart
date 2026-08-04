import 'dart:async';
import '../theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/community_provider.dart';
import '../providers/paginated_provider.dart';
import '../widgets/notification_bell.dart';
import '../widgets/theme_toggle_button.dart';
import '../models/models.dart';

class CommunitiesScreen extends ConsumerStatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  ConsumerState<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends ConsumerState<CommunitiesScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _filterKey = GlobalKey();
  Timer? _debounce;
  String _query = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels < _scrollController.position.maxScrollExtent - 200) return;
    ref.read(communitiesProvider.notifier).fetchNextPage();
  }

  List<Community> _filter(List<Community> data) {
    if (_query.isEmpty) return data;
    final q = _query.toLowerCase();
    return data.where((c) {
      return c.name.toLowerCase().contains(q)
          || (c.description ?? '').toLowerCase().contains(q)
          || (c.city ?? '').toLowerCase().contains(q)
          || (c.country ?? '').toLowerCase().contains(q)
          || (c.category ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openFilterMenu() async {
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

    List<String> categories;
    try {
      categories = await ref.read(categoriesProvider.future);
    } catch (_) {
      categories = const [];
    }
    if (!mounted) return;

    final result = await showMenu<String>(
      context: context,
      position: position,
      elevation: 8,
      color: context.cluvoSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        PopupMenuItem<String>(
          value: '',
          child: _filterMenuItem('All', _selectedCategory == null),
        ),
        ...categories.map(
          (c) => PopupMenuItem<String>(
            value: c,
            child: _filterMenuItem(c, _selectedCategory == c),
          ),
        ),
      ],
    );
    if (result == null || !mounted) return;
    final next = result.isEmpty ? null : result;
    if (next == _selectedCategory) return;
    setState(() => _selectedCategory = next);
    ref.read(communitiesProvider.notifier).setCategory(next);
  }

  Widget _filterMenuItem(String label, bool selected) {
    return Row(
      children: [
        Icon(
          selected ? Icons.check : Icons.category_outlined,
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

  String _emptyMessage() {
    if (_query.isEmpty && _selectedCategory == null) return 'No communities yet.';
    if (_query.isEmpty) return 'No communities in "$_selectedCategory".';
    return 'No communities match "$_query".';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communitiesProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'CLUVO',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: const Color(0xFFC2185B),
          ),
        ),
        actions: const [ThemeToggleButton(), NotificationBell()],
      ),
      body: state.loading
          ? _buildSkeleton()
          : state.error != null && state.items.isEmpty
              ? _buildError(state.error!)
              : _buildContent(state),
    );
  }

  Widget _buildContent(PaginatedList<Community> state) {
    final filtered = _filter(state.items);
    final notifier = ref.read(communitiesProvider.notifier);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 300), () {
                      setState(() => _query = v.trim());
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search communities...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: context.cluvoChipFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                key: _filterKey,
                child: IconButton(
                  onPressed: _openFilterMenu,
                  icon: const Icon(Icons.filter_list),
                  style: IconButton.styleFrom(
                    backgroundColor: _selectedCategory != null
                        ? CluvoTheme.primary.withValues(alpha: 0.12)
                        : context.cluvoChipFill,
                    foregroundColor: _selectedCategory != null
                        ? CluvoTheme.primary
                        : context.cluvoTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(categoriesProvider);
                await notifier.refresh();
              },
              child: filtered.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 200),
                        Center(
                          child: Text(
                            _emptyMessage(),
                            style: TextStyle(color: context.cluvoTextSecondary),
                          ),
                        ),
                      ],
                    )
                : ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == filtered.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final c = filtered[index];
                      final bannerUrl = c.bannerUrl;
                      final name = c.name;

                      return RepaintBoundary(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: InkWell(
                            onTap: () => context.push('/communities/${c.id}'),
                            borderRadius: BorderRadius.circular(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: AspectRatio(
                                      aspectRatio: 16 / 9,
                                      child:
                                          bannerUrl != null &&
                                                  bannerUrl.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: bannerUrl,
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  errorWidget: (_, _, _) =>
                                                      _buildBannerFallback(
                                                        name,
                                                      ),
                                                )
                                              : _buildBannerFallback(name),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      12, 12, 12, 0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (c.category != null) ...[
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFC2185B)
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                c.category!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: context.cluvoPrimaryText,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Icon(Icons.people,
                                              size: 14, color: context.cluvoTextSecondary),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${c.memberCount}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: context.cluvoTextSecondary,
                                            ),
                                          ),
                                          if (c.country != null) ...[
                                            const Spacer(),
                                            Icon(Icons.location_on,
                                                size: 14, color: context.cluvoTextSecondary),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${c.city ?? ''}${c.city != null ? ', ' : ''}${c.country ?? ''}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: context.cluvoTextSecondary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String errorMsg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: context.cluvoTextSecondary),
            const SizedBox(height: 12),
            Text('Could not load communities.\n$errorMsg',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.cluvoTextSecondary)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.read(communitiesProvider.notifier).refresh(),
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
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(3, (_) => _buildSkeletonCard()),
    );
  }

  Widget _buildSkeletonCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(color: context.cluvoChipFill),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: 180, decoration: BoxDecoration(color: context.cluvoChipFill, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(height: 12, width: 240, decoration: BoxDecoration(color: context.cluvoChipFill, borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
        ],
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
            fontSize: 48,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
