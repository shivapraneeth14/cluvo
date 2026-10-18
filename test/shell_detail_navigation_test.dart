// Regression guard for a go_router + StatefulShellRoute constraint:
//
// Detail screens (events/:id, communities/:id) must be declared as TOP-LEVEL
// routes, outside the StatefulShellRoute. If they are nested inside a shell
// branch, pushing one from a root-level route (e.g. `/search`) while another
// shell is still mounted triggers a Navigator key-collision assertion
// ("!keyReservation.contains(key)" / duplicate GlobalKey), which surfaces to
// users as the global "Something went wrong. Please restart the app." screen.
//
// The router below mirrors the app's real structure (a shell with home /
// communities / events branches plus a root-level `/search`) so that any future
// restructuring back to nested detail routes fails these tests.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/search',
        builder: (_, _) => const Scaffold(body: Text('search')),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => Scaffold(body: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, _) => const Scaffold(body: Text('home')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/communities',
                builder: (_, _) => const Scaffold(body: Text('communities')),
              ),
              GoRoute(
                path: '/communities/all',
                builder: (_, _) =>
                    const Scaffold(body: Text('communities all')),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/events',
                builder: (_, _) => const Scaffold(body: Text('events')),
              ),
              GoRoute(
                path: '/events/all',
                builder: (_, _) => const Scaffold(body: Text('events all')),
              ),
            ],
          ),
        ],
      ),
      // Detail routes at TOP LEVEL (outside the shell) and declared AFTER it.
      // go_router matches in declaration order, so these must follow the shell
      // or they would shadow the literal `/events/all` / `/communities/all`
      // listing routes.
      GoRoute(
        path: '/events/:id',
        builder: (_, _) => const Scaffold(body: Text('event')),
      ),
      GoRoute(
        path: '/communities/:id',
        builder: (_, _) => const Scaffold(body: Text('community')),
      ),
    ],
  );
}

Future<Object?> _run(
  WidgetTester tester,
  List<void Function(GoRouter)> steps,
) async {
  final router = buildRouter();
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  for (final step in steps) {
    step(router);
    await tester.pumpAndSettle();
  }
  return tester.takeException();
}

void main() {
  testWidgets('opening an event from a shell branch works', (tester) async {
    final ex = await _run(tester, [(r) => r.push('/events/1')]);
    expect(ex, isNull, reason: 'home -> event: $ex');
  });

  testWidgets('opening an event from search works and back returns', (
    tester,
  ) async {
    final ex = await _run(tester, [
      (r) => r.push('/search'),
      (r) => r.push('/events/1'),
      (r) => r.pop(),
    ]);
    expect(ex, isNull, reason: 'search -> event -> back: $ex');
    expect(find.text('search'), findsOneWidget);
  });

  testWidgets('opening a community from search works and back returns', (
    tester,
  ) async {
    final ex = await _run(tester, [
      (r) => r.push('/search'),
      (r) => r.push('/communities/1'),
      (r) => r.pop(),
    ]);
    expect(ex, isNull, reason: 'search -> community -> back: $ex');
    expect(find.text('search'), findsOneWidget);
  });

  testWidgets('events/all resolves to the listing, not the detail route', (
    tester,
  ) async {
    final ex = await _run(tester, [(r) => r.go('/events/all')]);
    expect(ex, isNull, reason: 'events all: $ex');
    expect(find.text('events all'), findsOneWidget);
    expect(find.text('event'), findsNothing);
  });

  testWidgets('communities/all resolves to the listing, not the detail route', (
    tester,
  ) async {
    final ex = await _run(tester, [(r) => r.go('/communities/all')]);
    expect(ex, isNull, reason: 'communities all: $ex');
    expect(find.text('communities all'), findsOneWidget);
    expect(find.text('community'), findsNothing);
  });
}
