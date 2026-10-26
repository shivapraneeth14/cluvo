import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/home_provider.dart';
import '../../theme.dart';
import '../../utils/category_icons.dart';

export '../../utils/category_icons.dart' show categoryIcon;

class CategoryCards extends StatelessWidget {
  final List<CategoryCount> categories;
  final Map<String, String> images;
  final void Function(String category) onTap;

  const CategoryCards({
    super.key,
    required this.categories,
    required this.images,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 172,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: CluvoTheme.screenPadding,
        ),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final cat = categories[i];
          return _CategoryCard(
            category: cat.category,
            count: cat.count,
            imageUrl: images[cat.category],
            onTap: () => onTap(cat.category),
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String category;
  final int count;
  final String? imageUrl;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.count,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 152,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: hasImage
              ? null
              : Border.all(
                  color: CluvoTheme.borderLavender,
                  width: CluvoTheme.hairline,
                ),
          boxShadow: [
            BoxShadow(
              color: CluvoTheme.deepNavy.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _image(),
              if (hasImage)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        CluvoTheme.deepNavy.withValues(alpha: 0.82),
                      ],
                      stops: const [0.35, 1],
                    ),
                  ),
                ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          categoryIcon(category),
                          size: 15,
                          color: hasImage
                              ? Colors.white
                              : CluvoTheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            category,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasImage
                                  ? Colors.white
                                  : CluvoTheme.textPrimaryColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (count > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        count == 1 ? '1 event' : '$count events',
                        style: TextStyle(
                          color: hasImage
                              ? Colors.white.withValues(alpha: 0.8)
                              : CluvoTheme.textSecondaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _image() {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, _) => _fallback(),
        errorWidget: (_, _, _) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      color: CluvoTheme.milkyFill,
      alignment: Alignment.center,
      child: Icon(
        categoryIcon(category),
        color: CluvoTheme.primary.withValues(alpha: 0.3),
        size: 44,
      ),
    );
  }
}
