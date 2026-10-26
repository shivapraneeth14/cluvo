import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/event.dart';
import 'package:mobile/models/registration.dart';

Map<String, dynamic> _eventMap({String? createdBy, String? videoUrl}) => {
  'id': 'evt-1',
  'community_id': 'com-1',
  'title': 'Retention Event',
  'description': null,
  'image_url': null,
  'video_url': videoUrl,
  'start_date': '2099-01-01T09:00:00Z',
  'end_date': '2099-01-01T11:00:00Z',
  'location': null,
  'latitude': null,
  'longitude': null,
  'capacity': null,
  'price': 0,
  'booked_count': 0,
  'status': 'published',
  'created_by': createdBy,
  'created_at': '2026-08-06T00:00:00Z',
  'updated_at': '2026-08-06T00:00:00Z',
  'deleted_at': null,
  'communities': {'name': 'Guard Community'},
};

Map<String, dynamic> _registrationMap({String? userId}) => {
  'id': 'reg-1',
  'event_id': 'evt-1',
  'user_id': userId,
  'status': 'confirmed',
  'qr_code': null,
  'checked_in': false,
  'checked_in_at': null,
  'registered_at': '2026-08-06T00:00:00Z',
  'updated_at': '2026-08-06T00:00:00Z',
  'deleted_at': null,
};

void main() {
  group('Event.fromMap', () {
    test('parses event with a creator', () {
      final event = Event.fromMap(_eventMap(createdBy: 'user-1'));
      expect(event.createdBy, 'user-1');
    });

    test(
      'parses event whose creator deleted their account (created_by null)',
      () {
        final event = Event.fromMap(_eventMap(createdBy: null));
        expect(event.createdBy, isNull);
        expect(event.title, 'Retention Event');
        expect(event.communityName, 'Guard Community');
      },
    );

    test('parses video_url when present', () {
      final event = Event.fromMap(
        _eventMap(videoUrl: 'https://res.cloudinary.com/demo/video/upload/v1/e.mp4'),
      );
      expect(event.videoUrl, 'https://res.cloudinary.com/demo/video/upload/v1/e.mp4');
    });

    test('video_url defaults to null and is omitted from toMap', () {
      final event = Event.fromMap(_eventMap());
      expect(event.videoUrl, isNull);
      expect(event.toMap().containsKey('video_url'), isFalse);
    });

    test('toMap includes video_url when set', () {
      final event = Event.fromMap(_eventMap(videoUrl: 'https://x/v.mp4'));
      expect(event.toMap()['video_url'], 'https://x/v.mp4');
    });
  });

  group('Registration.fromMap', () {
    test('parses registration without a user link (user_id null)', () {
      final reg = Registration.fromMap(_registrationMap(userId: null));
      expect(reg.userId, isNull);
      expect(reg.status, 'confirmed');
    });
  });
}
