import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/theme.dart';
import 'package:mobile/widgets/search/search_bar_pill.dart';
import 'package:mobile/widgets/search/search_segmented_tabs.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: CluvoTheme.lightTheme,
  home: Scaffold(body: child),
);

class _SegmentedHost extends StatefulWidget {
  const _SegmentedHost();

  @override
  State<_SegmentedHost> createState() => _SegmentedHostState();
}

class _SegmentedHostState extends State<_SegmentedHost>
    with SingleTickerProviderStateMixin {
  late final TabController controller;

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SearchSegmentedTabs(
      controller: controller,
      segments: const [
        SearchSegment(label: 'Events', icon: Icons.event_outlined),
        SearchSegment(label: 'Communities', icon: Icons.groups_outlined),
      ],
    );
  }
}

void main() {
  testWidgets('SearchBarPill renders icon, child and trailing', (tester) async {
    var cleared = false;
    await tester.pumpWidget(
      _wrap(
        SearchBarPill(
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => cleared = true,
          ),
          child: const Text('hint'),
        ),
      ),
    );

    expect(find.text('hint'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    expect(cleared, isTrue);
  });

  testWidgets('searchPillShuttle renders the hint pill', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => searchPillShuttle(
            context,
            kAlwaysCompleteAnimation,
            HeroFlightDirection.push,
            context,
            context,
          ),
        ),
      ),
    );

    expect(find.text(kSearchHint), findsOneWidget);
  });

  testWidgets('SearchSegmentedTabs switches segments and shows no counts', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const _SegmentedHost()));

    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Communities'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d')), findsNothing);

    final segmented = tester.widget<SearchSegmentedTabs>(
      find.byType(SearchSegmentedTabs),
    );
    expect(segmented.controller.index, 0);

    await tester.tap(find.text('Communities'));
    await tester.pumpAndSettle();
    expect(segmented.controller.index, 1);
  });
}
