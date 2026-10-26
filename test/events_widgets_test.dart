import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/providers/home_provider.dart';
import 'package:mobile/theme.dart';
import 'package:mobile/widgets/events/category_chips.dart';
import 'package:mobile/widgets/events/events_skeleton.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: CluvoTheme.lightTheme,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('EventCategoryChips renders an All chip plus real categories', (
    tester,
  ) async {
    String? tapped;
    await tester.pumpWidget(
      _wrap(
        EventCategoryChips(
          categories: const [
            CategoryCount('Music', 4),
            CategoryCount('Tech', 2),
          ],
          selected: null,
          onSelected: (value) => tapped = value,
        ),
      ),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Tech'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    await tester.tap(find.text('Tech'));
    expect(tapped, 'Tech');
  });

  testWidgets('EventCategoryChips collapses when there are no categories', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        EventCategoryChips(
          categories: const [],
          selected: null,
          onSelected: (_) {},
        ),
      ),
    );

    expect(find.text('All'), findsNothing);
  });

  testWidgets('Skeletons build without error', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SingleChildScrollView(
          child: Column(
            children: [
              CategoryChipsSkeleton(),
              EventCarouselSkeleton(count: 2),
              SpotlightSkeleton(),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CategoryChipsSkeleton), findsOneWidget);
    expect(find.byType(EventCarouselSkeleton), findsOneWidget);
    expect(find.byType(SpotlightSkeleton), findsOneWidget);
  });

  testWidgets('EventListSkeleton builds without error', (tester) async {
    await tester.pumpWidget(_wrap(const EventListSkeleton(count: 3)));
    expect(find.byType(EventListSkeleton), findsOneWidget);
  });
}
