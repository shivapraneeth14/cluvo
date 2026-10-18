import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/community.dart';
import 'package:mobile/models/event.dart';
import 'package:mobile/services/location_matching.dart';

Event _event(String id, String? location) => Event(
  id: id,
  communityId: 'c1',
  title: id,
  location: location,
  startDate: DateTime(2026, 8, 1),
  createdAt: DateTime(2026, 7, 1),
  updatedAt: DateTime(2026, 7, 1),
);

Community _community(String id, {String? city, String? location}) => Community(
  id: id,
  name: id,
  city: city,
  location: location,
  ownerId: 'o1',
  createdAt: DateTime(2026, 7, 1),
  updatedAt: DateTime(2026, 7, 1),
);

void main() {
  group('normalizeCity', () {
    test('lower-cases, strips punctuation and collapses whitespace', () {
      expect(normalizeCity('  Bengaluru  '), 'bengaluru');
      expect(normalizeCity('New Delhi, India!'), 'new delhi india');
      expect(normalizeCity(null), '');
      expect(normalizeCity('   '), '');
    });
  });

  group('cityMatches', () {
    test('matches exact and case-insensitive values', () {
      expect(cityMatches('Bengaluru', 'bengaluru'), isTrue);
    });

    test('matches common spelling aliases', () {
      expect(cityMatches('Bangalore', 'Bengaluru'), isTrue);
      expect(cityMatches('Bombay', 'Mumbai'), isTrue);
      expect(cityMatches('Cochin', 'Kochi'), isTrue);
    });

    test('matches multi-word place strings', () {
      expect(cityMatches('Koramangala, Bengaluru', 'Bengaluru'), isTrue);
      expect(cityMatches('Indiranagar Bengaluru', 'Bengaluru'), isTrue);
    });

    test('is false for empty inputs and different cities', () {
      expect(cityMatches(null, 'Bengaluru'), isFalse);
      expect(cityMatches('', 'Bengaluru'), isFalse);
      expect(cityMatches('Mumbai', 'Bengaluru'), isFalse);
    });
  });

  group('matchCity', () {
    test('returns the stored option spelling on an exact match', () {
      expect(matchCity('bengaluru', ['Bengaluru', 'Mumbai']), 'Bengaluru');
    });

    test('resolves aliases to the stored option', () {
      expect(matchCity('Bangalore', ['Bengaluru', 'Mumbai']), 'Bengaluru');
    });

    test('returns null when nothing matches or input is empty', () {
      expect(matchCity('Chennai', ['Bengaluru', 'Mumbai']), isNull);
      expect(matchCity(null, ['Bengaluru']), isNull);
    });
  });

  group('partitionLocalFirst', () {
    test('moves local items first while preserving relative order', () {
      final a = _event('a', 'Mumbai');
      final b = _event('b', 'Bengaluru');
      final c = _event('c', 'Delhi');
      final result = partitionLocalFirst([
        a,
        b,
        c,
      ], (e) => isEventLocal(e, 'Bengaluru'));
      expect(result.map((e) => e.id), ['b', 'a', 'c']);
    });

    test('returns the original list when nothing or everything is local', () {
      final items = [_event('a', 'Mumbai'), _event('b', 'Delhi')];
      expect(
        identical(
          partitionLocalFirst(items, (e) => isEventLocal(e, 'Kanpur')),
          items,
        ),
        isTrue,
      );
      expect(identical(partitionLocalFirst(items, (e) => true), items), isTrue);
    });
  });

  group('isEventLocal / isCommunityLocal', () {
    test('events use their free-form location', () {
      expect(isEventLocal(_event('a', 'Bengaluru'), 'bangalore'), isTrue);
      expect(isEventLocal(_event('b', null), 'Bengaluru'), isFalse);
    });

    test('communities prefer structured city and fall back to location', () {
      expect(
        isCommunityLocal(_community('a', city: 'Bengaluru'), 'bangalore'),
        isTrue,
      );
      expect(
        isCommunityLocal(
          _community('b', city: null, location: 'Bengaluru'),
          'Bengaluru',
        ),
        isTrue,
      );
      expect(
        isCommunityLocal(_community('c', city: 'Mumbai'), 'Bengaluru'),
        isFalse,
      );
    });
  });
}
