// ============================================================================
// CommunityPhotoGrid
// A two-column photo/video grid used ONLY on the redesigned community detail
// page's "Photos" tab. Tapping any tile opens the unified, view-only
// MediaGalleryScreen (which also handles videos), so photos and videos share a
// single full-screen experience.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import 'media/media_gallery_screen.dart';

class CommunityPhotoGrid extends StatelessWidget {
  final List<Map<String, dynamic>> media;
  const CommunityPhotoGrid({super.key, required this.media});

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 36,
                color: context.cluvoTextSecondary,
              ),
              const SizedBox(height: 10),
              Text(
                'No photos yet.',
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

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: media.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, index) {
        final item = media[index];
        final url = item['url'] as String;
        final isVideo = item['type'] == 'video';
        final thumb = isVideo ? (item['thumbnail_url'] as String?) : url;

        return GestureDetector(
          onTap: () => _openMedia(context, index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (thumb != null && thumb.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: thumb,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => _placeholder(context, isVideo),
                    errorWidget: (_, _, _) => _placeholder(context, isVideo),
                  )
                else
                  _placeholder(context, isVideo),
                if (isVideo)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder(BuildContext context, bool isVideo) {
    return Container(
      color: isVideo
          ? Colors.black87
          : CluvoTheme.primary.withValues(alpha: 0.1),
      child: Icon(
        isVideo ? Icons.play_circle_fill : Icons.broken_image,
        color: isVideo ? Colors.white : CluvoTheme.primary,
        size: 24,
      ),
    );
  }

  void _openMedia(BuildContext context, int index) {
    if (index < 0 || index >= media.length) return;
    final url = (media[index]['url'] as String?)?.trim();
    if (url == null || url.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaGalleryScreen(items: media, initialIndex: index),
      ),
    );
  }
}
