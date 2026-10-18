import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/models.dart';
import 'package:mobile/providers/community_provider.dart';
import 'package:mobile/theme.dart';
import 'package:mobile/utils.dart';
import 'package:mobile/widgets/communities/community_category_chips.dart';
import 'package:mobile/widgets/communities/community_discovery_card.dart';
import 'package:mobile/widgets/communities/community_image.dart';
import 'package:mobile/widgets/communities/community_join_button.dart';

Community _community({
  String id = 'c1',
  String name = 'Runners Club',
  String? description = 'A community for weekend runners.',
  String? category = 'Sports',
  int memberCount = 42,
  String? bannerUrl,
  String? avatarUrl,
}) {
  final now = DateTime(2026, 1, 1);
  return Community(
    id: id,
    name: name,
    description: description,
    category: category,
    memberCount: memberCount,
    bannerUrl: bannerUrl,
    communityAvatarUrl: avatarUrl,
    ownerId: 'owner-1',
    createdAt: now,
    updatedAt: now,
  );
}

Widget _wrap(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: CluvoTheme.lightTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

Override _emptyMemberships() =>
    myMembershipsProvider.overrideWith((ref) async => <JoinedCommunity>[]);

Override _membershipsWith(Community c) => myMembershipsProvider.overrideWith(
  (ref) async => [JoinedCommunity(community: c, role: 'MEMBER')],
);

void main() {
  group('sanitizeSearchQuery', () {
    test('strips characters that break PostgREST or() filters', () {
      expect(sanitizeSearchQuery('  a,b(c)%\\d  '), 'a b c d');
    });

    test('leaves ordinary text intact', () {
      expect(sanitizeSearchQuery('yoga in berlin'), 'yoga in berlin');
    });
  });

  group('CommunityCategoryChips', () {
    testWidgets('renders All + categories and reports selection', (
      tester,
    ) async {
      String? selected;
      await tester.pumpWidget(
        _wrap(
          CommunityCategoryChips(
            categories: const ['Sports', 'Music'],
            selected: null,
            onSelected: (v) => selected = v,
          ),
        ),
      );

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Sports'), findsOneWidget);

      await tester.tap(find.text('Music'));
      expect(selected, 'Music');

      await tester.tap(find.text('All'));
      expect(selected, isNull);
    });

    testWidgets('renders nothing when there are no categories', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CommunityCategoryChips(
            categories: const [],
            selected: null,
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.text('All'), findsNothing);
    });
  });

  group('CommunityImage', () {
    testWidgets('falls back to a gradient initial when no artwork exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 120,
            width: 200,
            child: CommunityImage(community: _community(name: 'Yoga')),
          ),
        ),
      );
      expect(find.text('Y'), findsOneWidget);
    });
  });

  group('CommunityResultCard', () {
    testWidgets('renders name and member count', (tester) async {
      await tester.pumpWidget(
        _wrap(CommunityResultCard(community: _community(memberCount: 7))),
      );
      expect(find.text('Runners Club'), findsOneWidget);
      expect(find.text('7 members'), findsOneWidget);
    });
  });

  group('CommunityJoinButton', () {
    testWidgets('shows Join when the user is not a member', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CommunityJoinButton(community: _community()),
          overrides: [_emptyMemberships()],
        ),
      );
      await tester.pump();
      expect(find.text('Join'), findsOneWidget);
      expect(find.text('Joined'), findsNothing);
    });

    testWidgets('shows Joined when the user is already a member', (
      tester,
    ) async {
      final c = _community();
      await tester.pumpWidget(
        _wrap(
          CommunityJoinButton(community: c),
          overrides: [_membershipsWith(c)],
        ),
      );
      await tester.pump();
      expect(find.text('Joined'), findsOneWidget);
      expect(find.text('Join'), findsNothing);
    });
  });

  group('CommunityDiscoveryCard', () {
    testWidgets('renders name, member count and a join action', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CommunityDiscoveryCard(community: _community(memberCount: 12)),
          overrides: [_emptyMemberships()],
        ),
      );
      await tester.pump();

      expect(find.text('Runners Club'), findsOneWidget);
      expect(find.text('12 members'), findsOneWidget);
      expect(find.text('Join'), findsOneWidget);
    });
  });
}
