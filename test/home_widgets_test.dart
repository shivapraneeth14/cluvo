import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/theme.dart';
import 'package:mobile/providers/home_provider.dart';
import 'package:mobile/widgets/home/section_header.dart';
import 'package:mobile/widgets/home/trending_pills.dart';
import 'package:mobile/widgets/home/category_cards.dart';
import 'package:mobile/widgets/home/mood_cards.dart';
import 'package:mobile/widgets/home/quick_filters.dart';
import 'package:mobile/widgets/home/free_events_banner.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: CluvoTheme.lightTheme,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('SectionHeader shows title and fires action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(
        SectionHeader(
          icon: Icons.grid_view_rounded,
          title: 'Explore by category',
          actionLabel: 'See all',
          onAction: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Explore by category'), findsOneWidget);
    await tester.tap(find.text('see all'));
    expect(tapped, isTrue);
  });

  testWidgets('TrendingPills renders items and reports taps', (tester) async {
    String? tapped;
    await tester.pumpWidget(
      _wrap(
        TrendingPills(
          items: const ['Music', 'Tech', 'Sports'],
          onTap: (value) => tapped = value,
        ),
      ),
    );

    expect(find.text('Music'), findsOneWidget);
    await tester.tap(find.text('Tech'));
    expect(tapped, 'Tech');
  });

  testWidgets('CategoryCards shows counts', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CategoryCards(
          categories: const [CategoryCount('Music', 3)],
          images: const {},
          onTap: (_) {},
        ),
      ),
    );

    expect(find.text('Music'), findsOneWidget);
    expect(find.text('3 events'), findsOneWidget);
  });

  testWidgets('MoodCards reports the mood query', (tester) async {
    String? query;
    await tester.pumpWidget(
      _wrap(MoodCards(images: const {}, onTap: (q) => query = q)),
    );

    expect(find.text('Chill evenings'), findsOneWidget);
    await tester.tap(find.text('Chill evenings'));
    expect(query, 'music');
  });

  testWidgets('QuickFilters shows labels and fires callbacks', (tester) async {
    var dateTaps = 0;
    await tester.pumpWidget(
      _wrap(
        QuickFilters(
          dateLabel: 'Date',
          distanceLabel: 'Near to Far',
          priceLabel: 'Price',
          dateActive: false,
          distanceActive: false,
          priceActive: false,
          onDateTap: () => dateTaps++,
          onDistanceTap: () {},
          onPriceTap: () {},
        ),
      ),
    );

    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Near to Far'), findsOneWidget);
    await tester.tap(find.text('Date'));
    expect(dateTaps, 1);
  });

  testWidgets('FreeEventsBanner shows count and fires tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(FreeEventsBanner(count: 5, onTap: () => tapped = true)),
    );

    expect(find.text('Free events near you'), findsOneWidget);
    expect(find.text('5 free events to explore'), findsOneWidget);
    await tester.tap(find.text('Free events near you'));
    expect(tapped, isTrue);
  });
}
