import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/event_message.dart';

void main() {
  group('EventMessage & Discussion Hydration (BUG-008)', () {
    test('raw Realtime payload fromMap has null sender profile attributes', () {
      final rawRealtimeRecord = {
        'id': 'msg-123',
        'event_id': 'evt-456',
        'user_id': 'usr-789',
        'content': 'Hello from realtime!',
        'created_at': '2026-11-01T10:00:00.000Z',
        'updated_at': '2026-11-01T10:00:00.000Z',
        // In PostgreSQL WAL replication, joined tables (profiles:user_id) are NOT present
      };

      final msg = EventMessage.fromMap(rawRealtimeRecord);

      expect(msg.id, 'msg-123');
      expect(msg.eventId, 'evt-456');
      expect(msg.userId, 'usr-789');
      expect(msg.content, 'Hello from realtime!');
      expect(msg.senderName, isNull);
      expect(msg.senderAvatarUrl, isNull);
    });

    test('profile join from initial REST load populates senderName and senderAvatarUrl', () {
      final restJoinedRecord = {
        'id': 'msg-123',
        'event_id': 'evt-456',
        'user_id': 'usr-789',
        'content': 'Initial message',
        'created_at': '2026-11-01T10:00:00.000Z',
        'updated_at': '2026-11-01T10:00:00.000Z',
        'profiles': {
          'first_name': 'Ada',
          'last_name': 'Lovelace',
          'avatar_url': 'https://res.cloudinary.com/demo/image/upload/v1/avatar.jpg',
        },
      };

      final msg = EventMessage.fromMap(restJoinedRecord);

      expect(msg.senderName, 'Ada Lovelace');
      expect(msg.senderAvatarUrl, 'https://res.cloudinary.com/demo/image/upload/v1/avatar.jpg');
    });

    test('cache-based hydration attaches profile to incoming Realtime message', () {
      final profileCache = <String, ({String name, String? avatarUrl})>{
        'usr-789': (
          name: 'Ada Lovelace',
          avatarUrl: 'https://res.cloudinary.com/demo/image/upload/v1/avatar.jpg',
        ),
      };

      final rawMsg = EventMessage.fromMap({
        'id': 'msg-999',
        'event_id': 'evt-456',
        'user_id': 'usr-789',
        'content': 'Second message from Ada',
        'created_at': '2026-11-01T10:05:00.000Z',
        'updated_at': '2026-11-01T10:05:00.000Z',
      });

      expect(rawMsg.senderName, isNull);

      final cached = profileCache[rawMsg.userId];
      expect(cached, isNotNull);
      rawMsg.senderName = cached!.name;
      rawMsg.senderAvatarUrl = cached.avatarUrl;

      expect(rawMsg.senderName, 'Ada Lovelace');
      expect(rawMsg.senderAvatarUrl, 'https://res.cloudinary.com/demo/image/upload/v1/avatar.jpg');
    });

    test('async profile fetch hydration formats partial names correctly', () {
      final Map<String, dynamic> rawProfile1 = {'first_name': 'Grace', 'last_name': null, 'avatar_url': null};
      final first1 = (rawProfile1['first_name'] as String?) ?? '';
      final last1 = (rawProfile1['last_name'] as String?) ?? '';
      final name1 = '$first1 $last1'.trim();

      expect(name1, 'Grace');

      final Map<String, dynamic> rawProfile2 = {'first_name': null, 'last_name': null, 'avatar_url': null};
      final first2 = (rawProfile2['first_name'] as String?) ?? '';
      final last2 = (rawProfile2['last_name'] as String?) ?? '';
      final name2 = '$first2 $last2'.trim();
      final displayName2 = name2.isNotEmpty ? name2 : 'Member';

      expect(displayName2, 'Member');
    });

    test('message edit updates content and updatedAt in place', () {
      final msg = EventMessage(
        id: 'msg-1',
        eventId: 'evt-1',
        userId: 'usr-1',
        content: 'Original text',
        createdAt: DateTime.parse('2026-11-01T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-11-01T10:00:00.000Z'),
        senderName: 'Test User',
      );

      expect(msg.content, 'Original text');

      msg.content = 'Updated text';
      msg.updatedAt = DateTime.parse('2026-11-01T10:15:00.000Z');

      expect(msg.content, 'Updated text');
      expect(msg.updatedAt, DateTime.parse('2026-11-01T10:15:00.000Z'));
    });
  });
}

