import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/providers/home_provider.dart';
import 'package:mobile/theme.dart';
import 'package:mobile/widgets/events/category_chips.dart';
import 'package:mobile/widgets/events/events_search_header.dart';
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

  testWidgets('EventsSearchHeader shows the hint and reports typed queries', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? query;
    await tester.pumpWidget(
      _wrap(
        EventsSearchHeader(
          controller: controller,
          onChanged: (value) => query = value,
          onClear: () {},
        ),
      ),
    );

    expect(find.text('Discover events'), findsOneWidget);
    expect(find.text(EventsSearchHeader.hint), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'jazz');
    expect(query, 'jazz');
  });

  testWidgets('EventsSearchHeader exposes a clear affordance with text', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'jazz');
    addTearDown(controller.dispose);
    var cleared = false;
    await tester.pumpWidget(
      _wrap(
        EventsSearchHeader(
          controller: controller,
          onChanged: (_) {},
          onClear: () => cleared = true,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.clear));
    expect(cleared, isTrue);
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
