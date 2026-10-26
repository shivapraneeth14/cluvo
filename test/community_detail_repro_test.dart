import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/community_detail_screen.dart';
import 'package:mobile/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

String _eventsJson = '[]';

String _bodyFor(Uri url) {
  final path = url.path;
  if (path.contains('community_members')) return 'null';
  if (path.contains('realtime')) return '{}';
  if (path.contains('/media')) {
    return jsonEncode([
      {
        'id': 'm1',
        'mediable_type': 'community',
        'mediable_id': 'c1',
        'url': '',
        'thumbnail_url': null,
        'type': 'image',
        'sort_order': 0,
        'caption': null,
        'created_at': '2026-01-05T10:00:00Z',
      },
      {
        'id': 'm2',
        'mediable_type': 'community',
        'mediable_id': 'c1',
        'url': 'https://cdn.example.com/v.mp4',
        'thumbnail_url': null,
        'type': 'video',
        'sort_order': 1,
        'caption': null,
        'created_at': '2026-01-06T10:00:00Z',
      },
    ]);
  }
  if (path.contains('/events')) return _eventsJson;
  if (path.contains('/communities')) {
    return jsonEncode({
      'id': 'c1',
      'name': 'Sunrise Yoga Collective',
      'description': 'Morning flows for everyone.',
      'location': null,
      'banner_url': null,
      'community_avatar_url': null,
      'owner_id': 'o1',
      'visibility': 'public',
      'verification_status': 'verified',
      'is_hidden': false,
      'member_count': 1234,
      'event_count': 0,
      'category': 'Yoga',
      'country': 'Germany',
      'state': null,
      'city': 'Berlin',
      'tags': ['wellness', 'community'],
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-02T00:00:00Z',
      'deleted_at': null,
      'contact_email': null,
      'contact_phone': null,
      'instagram_url': null,
      'facebook_url': null,
      'twitter_url': null,
      'linkedin_url': null,
      'rules': 'Be kind to each other.',
    });
  }
  return '[]';
}

class _FakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpRequest(url);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpRequest(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpRequest implements HttpClientRequest {
  _FakeHttpRequest(this.url);

  final Uri url;

  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async =>
      _FakeHttpResponse(utf8.encode(_bodyFor(url)));

  @override
  Future<dynamic> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpResponse(this._body);

  final List<int> _body;

  @override
  int get statusCode => 200;

  @override
  String get reasonPhrase => 'OK';

  @override
  int get contentLength => _body.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  bool get persistentConnection => false;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_body]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  String? value(String name) => null;

  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _MemoryGotrueAsyncStorage implements GotrueAsyncStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> getItem({required String key}) async => _store[key];

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _store[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _store.remove(key);
}

void main() {
  setUp(() => _eventsJson = '[]');

  setUpAll(() async {
    HttpOverrides.global = _FakeHttpOverrides();
    await Supabase.initialize(
      url: 'https://fake.supabase.co',
      publishableKey: 'fake-publishable-key',
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _MemoryGotrueAsyncStorage(),
        detectSessionInUri: false,
      ),
    );
  });

  testWidgets('renders real community data and both tabs', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: CluvoTheme.lightTheme,
          home: const CommunityDetailScreen(id: 'c1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Sunrise Yoga Collective'), findsOneWidget);
    expect(find.text('Morning flows for everyone.'), findsNWidgets(2)); // cover tagline + About Us
    expect(find.text('Berlin, Germany'), findsOneWidget);
    expect(find.text('Yoga'), findsOneWidget);
    expect(find.text('1,234'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Photos'), findsWidgets);
    expect(find.text('No events in this community yet.'), findsOneWidget);

    await tester.tap(find.text('Photos').last);
    await tester.pump();
    expect(find.text('2 items'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Grid -> List toggle changes the actual layout (and keeps the filter).
    await tester.tap(find.byIcon(Icons.view_list_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Photo'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'after list toggle');

    // Videos filter, then open the real video player from the tile.
    await tester.ensureVisible(find.widgetWithText(GestureDetector, 'Videos'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(GestureDetector, 'Videos'));
    await tester.pumpAndSettle();
    expect(find.text('1 video'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'after videos filter');

    await tester.ensureVisible(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'after ensureVisible');
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.takeException(), isNull, reason: 'after opening player');

    // The player screen opens (no platform video plugin in tests, so the
    // built-in playback error + Retry state is what renders).
    expect(find.text('Could not play this video.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('1 video'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'after closing player');
  });

  testWidgets('narrow phone width does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: CluvoTheme.lightTheme,
          home: const CommunityDetailScreen(id: 'c1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Sunrise Yoga Collective'), findsOneWidget);
    expect(find.byIcon(Icons.ios_share), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('events tab renders the shared grid card', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    _eventsJson = jsonEncode([
      {
        'id': 'e1',
        'community_id': 'c1',
        'title': 'Sunrise Flow',
        'description': null,
        'image_url': null,
        'category': 'Yoga',
        'start_date': '2099-01-01T10:00:00Z',
        'end_date': null,
        'location': null,
        'latitude': null,
        'longitude': null,
        'capacity': 20,
        'price': 0,
        'booked_count': 3,
        'status': 'published',
        'created_by': 'o1',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-02T00:00:00Z',
        'deleted_at': null,
      },
    ]);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: CluvoTheme.lightTheme,
          home: const CommunityDetailScreen(id: 'c1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Sunrise Flow'), findsOneWidget);
    expect(find.text('No events in this community yet.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
