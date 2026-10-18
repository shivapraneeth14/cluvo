// ============================================================================
// Community media section — the "Photos" tab body of Community Detail.
//
// Renders the real `media` records loaded by the screen (no demo content, no
// hardcoded counts). Provides:
//   • section heading + real record count
//   • All / Photos / Videos filter chips
//   • Grid / List segmented toggle (both change the actual layout)
//   • lazy two-column grid and lightweight list rows
//   • loading-failure fallbacks, empty states and a pagination-free compact
//     layout that stays reachable above the bottom navigation
//
// Both photos and videos open the unified, view-only MediaGalleryScreen, which
// swipes through the current (filtered) list. No download / save / delete /
// edit / overflow actions.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme.dart';
import '../../utils.dart';
import 'media_gallery_screen.dart';

enum MediaFilter { all, photos, videos }

enum MediaLayout { grid, list }

bool _isVideo(Map<String, dynamic> media) => media['type'] == 'video';

String? _thumbnailOf(Map<String, dynamic> media) {
  final thumb = (media['thumbnail_url'] as String?)?.trim();
  if (thumb != null && thumb.isNotEmpty) return thumb;
  // A video has no poster when the backend stored none — never fall back to
  // the video file itself as an image.
  if (_isVideo(media)) return null;
  final url = (media['url'] as String?)?.trim();
  return (url == null || url.isEmpty) ? null : url;
}

String? _captionOf(Map<String, dynamic> media) {
  final caption = (media['caption'] as String?)?.trim();
  return (caption == null || caption.isEmpty) ? null : caption;
}

class CommunityMediaSection extends StatefulWidget {
  /// The community's real media records, already permission-filtered by RLS.
  final List<Map<String, dynamic>> media;

  const CommunityMediaSection({super.key, required this.media});

  @override
  State<CommunityMediaSection> createState() => _CommunityMediaSectionState();
}

class _CommunityMediaSectionState extends State<CommunityMediaSection> {
  MediaFilter _filter = MediaFilter.all;
  MediaLayout _layout = MediaLayout.grid;

  List<Map<String, dynamic>> get _filtered {
    switch (_filter) {
      case MediaFilter.all:
        return widget.media;
      case MediaFilter.photos:
        return widget.media.where((m) => !_isVideo(m)).toList();
      case MediaFilter.videos:
        return widget.media.where(_isVideo).toList();
    }
  }

  void _openItem(List<Map<String, dynamic>> items, int index) {
    if (index < 0 || index >= items.length) return;
    final url = (items[index]['url'] as String?)?.trim();
    if (url == null || url.isEmpty) return;

    // Pushed on the root navigator so the full-screen view covers the app
    // shell — the bottom navigation must never sit on top of media.
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => MediaGalleryScreen(items: items, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(items.length),
        const SizedBox(height: 14),
        _buildFilters(),
        const SizedBox(height: 16),
        if (items.isEmpty)
          _buildEmptyState()
        else if (_layout == MediaLayout.grid)
          _buildGrid(items)
        else
          _buildList(items),
      ],
    );
  }

  // ── Header: title + real count + Grid/List toggle ───────────────────────

  Widget _buildHeader(int count) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Photos',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: context.cluvoTextPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _countLabel(count),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.cluvoTextSecondary,
            ),
          ),
        ),
        const Spacer(),
        _buildLayoutToggle(),
      ],
    );
  }

  String _countLabel(int count) {
    switch (_filter) {
      case MediaFilter.all:
        return count == 1 ? '1 item' : '$count items';
      case MediaFilter.photos:
        return count == 1 ? '1 photo' : '$count photos';
      case MediaFilter.videos:
        return count == 1 ? '1 video' : '$count videos';
    }
  }

  Widget _buildLayoutToggle() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.cluvoLavenderFill,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _layoutSegment(MediaLayout.grid, Icons.grid_view_rounded, 'Grid'),
          _layoutSegment(MediaLayout.list, Icons.view_list_rounded, 'List'),
        ],
      ),
    );
  }

  Widget _layoutSegment(MediaLayout layout, IconData icon, String label) {
    final selected = _layout == layout;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label view',
      child: GestureDetector(
        onTap: () => setState(() => _layout = layout),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 42,
          height: 38,
          decoration: BoxDecoration(
            color: selected ? CluvoTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Icon(
            icon,
            size: 20,
            color: selected ? Colors.white : CluvoTheme.textSecondaryColor,
          ),
        ),
      ),
    );
  }

  // ── Filters ─────────────────────────────────────────────────────────────

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('All', MediaFilter.all),
          const SizedBox(width: 8),
          _filterChip('Photos', MediaFilter.photos),
          const SizedBox(width: 8),
          _filterChip('Videos', MediaFilter.videos),
        ],
      ),
    );
  }

  Widget _filterChip(String label, MediaFilter filter) {
    final selected = _filter == filter;
    return GestureDetector(
      onTap: () => setState(() => _filter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 38,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? CluvoTheme.primary : context.cluvoLavenderFill,
          borderRadius: BorderRadius.circular(19),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : context.cluvoTextPrimary,
          ),
        ),
      ),
    );
  }

  // ── Grid ────────────────────────────────────────────────────────────────

  Widget _buildGrid(List<Map<String, dynamic>> items) {
    const gap = 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - gap) / 2;
        final cacheWidth = (tileWidth * MediaQuery.devicePixelRatioOf(context))
            .round();
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: 4 / 3,
          ),
          itemBuilder: (_, i) => _MediaTile(
            media: items[i],
            cacheWidth: cacheWidth,
            onTap: () => _openItem(items, i),
          ),
        );
      },
    );
  }

  // ── List ────────────────────────────────────────────────────────────────

  Widget _buildList(List<Map<String, dynamic>> items) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) =>
          _MediaRow(media: items[i], onTap: () => _openItem(items, i)),
    );
  }

  // ── Empty ───────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final (icon, title, subtitle) = switch (_filter) {
      MediaFilter.photos => (
        Icons.photo_library_outlined,
        'No photos yet.',
        'Photos shared with this community will appear here.',
      ),
      MediaFilter.videos => (
        Icons.video_library_outlined,
        'No videos yet.',
        'Videos shared with this community will appear here.',
      ),
      MediaFilter.all => (
        Icons.photo_library_outlined,
        'No media yet.',
        'Photos and videos shared with this community will appear here.',
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.cluvoLavenderFill,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: CluvoTheme.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.cluvoTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: context.cluvoTextSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Tiles
// ============================================================================

/// Neutral, dimension-preserving placeholder for loading / failures.
class _MediaPlaceholder extends StatelessWidget {
  final bool isVideo;
  final bool failed;
  const _MediaPlaceholder({required this.isVideo, this.failed = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isVideo ? CluvoTheme.viewerBackground : context.cluvoLavenderFill,
      child: Center(
        child: Icon(
          failed
              ? Icons.broken_image_outlined
              : (isVideo ? Icons.videocam_outlined : Icons.image_outlined),
          size: 22,
          color: isVideo ? Colors.white30 : CluvoTheme.textSecondaryColor,
        ),
      ),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final Map<String, dynamic> media;
  final int cacheWidth;
  final VoidCallback onTap;

  const _MediaTile({
    required this.media,
    required this.cacheWidth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final video = _isVideo(media);
    final thumb = _thumbnailOf(media);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumb != null)
              CachedNetworkImage(
                imageUrl: thumb,
                fit: BoxFit.cover,
                memCacheWidth: cacheWidth,
                placeholder: (_, _) => _MediaPlaceholder(isVideo: video),
                errorWidget: (_, _, _) =>
                    _MediaPlaceholder(isVideo: video, failed: true),
              )
            else
              _MediaPlaceholder(isVideo: video),
            if (video) const _PlayBadge(),
          ],
        ),
      ),
    );
  }
}

class _MediaRow extends StatelessWidget {
  final Map<String, dynamic> media;
  final VoidCallback onTap;

  const _MediaRow({required this.media, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final video = _isVideo(media);
    final thumb = _thumbnailOf(media);
    final caption = _captionOf(media);
    final title = caption ?? (video ? 'Video' : 'Photo');
    final date = formatDate(media['created_at'] as String?);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.cluvoSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.cluvoBorder),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              height: 76,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumb != null)
                      CachedNetworkImage(
                        imageUrl: thumb,
                        fit: BoxFit.cover,
                        memCacheWidth: 228,
                        placeholder: (_, _) =>
                            _MediaPlaceholder(isVideo: video),
                        errorWidget: (_, _, _) =>
                            _MediaPlaceholder(isVideo: video, failed: true),
                      )
                    else
                      _MediaPlaceholder(isVideo: video),
                    if (video)
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: context.cluvoTextPrimary,
                    ),
                  ),
                  if (date.isNotEmpty || video) ...[
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (video) 'Video' else 'Photo',
                        if (date.isNotEmpty) date,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.cluvoTextSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              video ? Icons.play_arrow_rounded : Icons.chevron_right_rounded,
              size: 22,
              color: context.cluvoTextSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
