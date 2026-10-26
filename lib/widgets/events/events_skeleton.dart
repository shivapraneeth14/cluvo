import 'package:flutter/material.dart';
import '../../theme.dart';
import 'event_card.dart';

/// Placeholder shapes that mirror the real card layout. Deliberately contain
/// no text or imagery so no fabricated content is ever shown while loading.
class EventCarouselSkeleton extends StatelessWidget {
  final int count;

  const EventCarouselSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kEventCardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: CluvoTheme.screenPadding,
        ),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => _card(context),
      ),
    );
  }

  Widget _card(BuildContext context) {
    return Container(
      width: kEventCardWidth,
      decoration: BoxDecoration(
        color: context.cluvoSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.cluvoBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: context.cluvoChipFill,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(19),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(context, double.infinity, 12),
                const SizedBox(height: 8),
                _bar(context, 140, 12),
                const SizedBox(height: 14),
                _bar(context, 100, 10),
                const SizedBox(height: 8),
                _bar(context, 70, 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context, double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.cluvoChipFill,
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

class CategoryChipsSkeleton extends StatelessWidget {
  const CategoryChipsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: CluvoTheme.screenPadding,
        ),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Container(
          width: 84,
          height: 40,
          decoration: BoxDecoration(
            color: context.cluvoChipFill,
            borderRadius: BorderRadius.circular(CluvoTheme.radiusPill),
          ),
        ),
      ),
    );
  }
}

class SpotlightSkeleton extends StatelessWidget {
  const SpotlightSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CluvoTheme.screenPadding),
      child: AspectRatio(
        aspectRatio: 13 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: context.cluvoSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.cluvoBorder),
          ),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: context.cluvoChipFill,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(23),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: 200,
                      color: context.cluvoChipFill,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 12,
                      width: 140,
                      color: context.cluvoChipFill,
                    ),
                    const SizedBox(height: 18),
                    Container(
                      height: 40,
                      width: double.infinity,
                      color: context.cluvoChipFill,
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
}

class EventListSkeleton extends StatelessWidget {
  final int count;

  const EventListSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Container(
        height: 92,
        decoration: BoxDecoration(
          color: context.cluvoSurface,
          borderRadius: BorderRadius.circular(CluvoTheme.radiusCard),
          border: Border.all(color: context.cluvoBorder),
        ),
      ),
    );
  }
}

/// Two-column placeholder grid that mirrors the [EventGridCard] layout:
/// a rounded image block with two text bars beneath it.
class EventGridSkeleton extends StatelessWidget {
  final int count;

  const EventGridSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 14,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (_, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.cluvoChipFill,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: context.cluvoChipFill,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 12,
            width: 90,
            decoration: BoxDecoration(
              color: context.cluvoChipFill,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
