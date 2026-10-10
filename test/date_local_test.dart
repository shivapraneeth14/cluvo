import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/event.dart';
import 'package:mobile/utils.dart';

void main() {
  group('safeParseDate', () {
    test('converts offset/UTC timestamps to local wall-clock', () {
      for (final iso in [
        '2026-08-21T16:26:04+05:30',
        '2026-08-21T16:26:04+00:00',
        '2026-08-21T16:26:04Z',
      ]) {
        final dt = safeParseDate(iso);
        expect(dt, isNotNull);
        expect(dt!.isUtc, isFalse, reason: '$iso must parse to local time');
        expect(
          dt.toUtc(),
          DateTime.parse(iso).toUtc(),
          reason: '$iso must preserve its instant',
        );
      }
    });

    test('treats timezone-less strings as local (no shift)', () {
      final dt = safeParseDate('2026-08-21T16:26:04');
      expect(dt, isNotNull);
      expect(dt!.isUtc, isFalse);
      expect(dt.day, 21);
      expect(dt.hour, 16);
    });

    test('returns null for garbage and empty input', () {
      expect(safeParseDate(null), isNull);
      expect(safeParseDate(''), isNull);
      expect(safeParseDate('not-a-date'), isNull);
    });
  });

  group('Event.fromMap', () {
    final event = Event.fromMap({
      'id': 'evt-1',
      'community_id': 'com-1',
      'title': 'TZ Event',
      'description': null,
      'image_url': null,
      'start_date': '2099-01-01T09:00:00Z',
      'end_date': '2099-01-01T11:00:00Z',
      'location': null,
      'latitude': null,
      'longitude': null,
      'capacity': null,
      'price': 0,
      'booked_count': 0,
      'status': 'published',
      'created_by': null,
      'created_at': '2026-08-06T00:00:00Z',
      'updated_at': '2026-08-06T00:00:00Z',
      'deleted_at': null,
      'communities': {'name': 'Guard Community'},
    });

    test('parses DB timestamps to local DateTime', () {
      expect(event.startDate.isUtc, isFalse);
      expect(event.endDate, isNotNull);
      expect(event.endDate!.isUtc, isFalse);
      expect(event.createdAt.isUtc, isFalse);
      expect(
        event.startDate.toUtc(),
        DateTime.parse('2099-01-01T09:00:00Z'),
      );
    });

    test('lifecycle uses instants, unaffected by localization', () {
      expect(event.lifecycle(DateTime.parse('2098-12-31T23:00:00Z').toLocal()),
          EventLifecycle.active);
      expect(event.lifecycle(DateTime.parse('2099-01-01T10:00:00Z').toLocal()),
          EventLifecycle.live);
      expect(event.lifecycle(DateTime.parse('2099-01-01T11:00:00Z').toLocal()),
          EventLifecycle.live);
      expect(event.lifecycle(DateTime.parse('2099-01-01T12:00:00Z').toLocal()),
          EventLifecycle.closed);
    });
  });

  group('formatDate / formatDateTime', () {
    test('formatDate renders the local calendar date', () {
      final iso = '2026-08-21T16:26:04+05:30';
      final expected = DateTime.parse(iso).toLocal();
      expect(formatDate(iso),
          '${expected.day}/${expected.month}/${expected.year}');
    });

    test('formatDateTime renders local dd/MM/yyyy HH:mm with zero-padding', () {
      expect(formatDateTime(DateTime(2026, 9, 7, 9, 5)), '7/9/2026 09:05');
      expect(formatDateTime(null), '');
      final utc = DateTime.utc(2026, 9, 7, 4, 30);
      final local = utc.toLocal();
      final pad = '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
      expect(formatDateTime(utc),
          '${local.day}/${local.month}/${local.year} $pad');
    });
  });
}