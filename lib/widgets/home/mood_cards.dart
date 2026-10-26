import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme.dart';

class Mood {
  final String label;
  final String subtitle;
  final String query;
  final IconData icon;
  final List<String> matchKeys;

  const Mood({
    required this.label,
    required this.subtitle,
    required this.query,
    required this.icon,
    required this.matchKeys,
  });
}

const List<Mood> kMoods = [
  Mood(
    label: 'Chill evenings',
    subtitle: 'Music & easy hangs',
    query: 'music',
    icon: Icons.nightlife_outlined,
    matchKeys: ['music', 'concert'],
  ),
  Mood(
    label: 'Learn something',
    subtitle: 'Talks, classes & workshops',
    query: 'workshop',
    icon: Icons.school_outlined,
    matchKeys: ['workshop', 'education', 'tech', 'learn', 'business'],
  ),
  Mood(
    label: 'Meet people',
    subtitle: 'Mixers & community nights',
    query: 'meetup',
    icon: Icons.groups_outlined,
    matchKeys: ['social', 'community', 'network', 'business'],
  ),
  Mood(
    label: 'Get active',
    subtitle: 'Sports, fitness & outdoors',
    query: 'sports',
    icon: Icons.directions_run,
    matchKeys: ['sport', 'fitness', 'health', 'outdoor'],
  ),
  Mood(
    label: 'Try something new',
    subtitle: 'Food, art & adventure',
    query: 'experience',
    icon: Icons.explore_outlined,
    matchKeys: ['food', 'art', 'culture', 'travel', 'game'],
  ),
];

class MoodCards extends StatelessWidget {
  final Map<String, String> images;
  final void Function(String query) onTap;
  final List<Mood>? moods;

  const MoodCards({
    super.key,
    required this.images,
    required this.onTap,
    this.moods,
  });

  String? _imageFor(Mood mood) {
    for (final entry in images.entries) {
      final key = entry.key.toLowerCase();
      if (mood.matchKeys.any((mk) => key.contains(mk.toLowerCase()))) {
        return entry.value;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final list = moods ?? kMoods;
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: CluvoTheme.screenPadding,
        ),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final mood = list[i];
          return _MoodCard(
            mood: mood,
            imageUrl: _imageFor(mood),
            onTap: () => onTap(mood.query),
          );
        },
      ),
    );
  }
}

class _MoodCard extends StatelessWidget {
  final Mood mood;
  final String? imageUrl;
  final VoidCallback onTap;

  const _MoodCard({
    required this.mood,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 236,
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
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        CluvoTheme.deepNavy.withValues(alpha: 0.85),
                        CluvoTheme.nightPurple.withValues(alpha: 0.45),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            mood.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasImage
                                  ? Colors.white
                                  : CluvoTheme.textPrimaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            mood.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasImage
                                  ? Colors.white.withValues(alpha: 0.72)
                                  : CluvoTheme.textSecondaryColor,
                              fontSize: 12,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: hasImage
                            ? Colors.white.withValues(alpha: 0.14)
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: hasImage
                            ? null
                            : Border.all(
                                color: CluvoTheme.borderLavender,
                                width: CluvoTheme.hairline,
                              ),
                      ),
                      child: Icon(
                        mood.icon,
                        color: hasImage
                            ? Colors.white
                            : CluvoTheme.textPrimaryColor,
                        size: 20,
                      ),
                    ),
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
    return Container(color: CluvoTheme.milkyFill);
  }
}
