import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/providers/activity_provider.dart';
import 'package:mobile/screens/my_registrations_screen.dart';
import 'package:mobile/theme.dart';

Map<String, dynamic> _row({
  required String title,
  String status = 'cancelled',
  bool deleted = true,
  num price = 50000,
  Map<String, dynamic>? payment,
}) {
  return {
    'id': 'reg-$title',
    'event_id': 'evt-$title',
    'status': status,
    'deleted_at': deleted ? '2026-10-20T10:00:00Z' : null,
    'qr_code': null,
    'events': {
      'id': 'evt-$title',
      'title': title,
      'status': 'published',
      'price': price,
      'start_date': '2026-10-01T10:00:00Z',
    },
    'payments': payment,
  };
}

Widget _app(List<Map<String, dynamic>> rows) {
  return ProviderScope(
    overrides: [
      myRegistrationsProvider.overrideWith((ref) async => rows),
    ],
    child: MaterialApp(
      theme: CluvoTheme.lightTheme,
      home: const MyRegistrationsScreen(),
    ),
  );
}

void main() {
  testWidgets('a cancelled booking with a refund stays on the list', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
        _row(
          title: 'Refunded Fest',
          payment: {
            'status': 'refunded',
            'refund_status': 'processed',
            'amount': 50000,
            'refunded_amount': 50000,
          },
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Refunded Fest'), findsOneWidget);
    expect(find.textContaining('Cancelled · refunded ₹500'), findsOneWidget);
  });

  testWidgets('an abandoned checkout stays hidden', (tester) async {
    await tester.pumpWidget(
      _app([
        _row(
          title: 'Abandoned Fest',
          payment: {'status': 'failed', 'refund_status': null},
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Abandoned Fest'), findsNothing);
    expect(find.text('No registrations yet.'), findsOneWidget);
  });

  testWidgets('only the abandoned row is filtered from a mixed list', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app([
        _row(title: 'Live Fest', status: 'confirmed', deleted: false),
        _row(
          title: 'Abandoned Fest',
          payment: {'status': 'pending', 'refund_status': null},
        ),
        _row(
          title: 'Refunded Fest',
          payment: {
            'status': 'refunded',
            'refund_status': 'processed',
            'amount': 50000,
            'refunded_amount': 50000,
          },
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Live Fest'), findsOneWidget);
    expect(find.text('Refunded Fest'), findsOneWidget);
    expect(find.text('Abandoned Fest'), findsNothing);
  });
}
