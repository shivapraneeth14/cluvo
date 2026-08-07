import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/event_detail_screen.dart';
import 'package:mobile/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> _fakeEvent = {
  'id': 'evt-1',
  'title': 'Test Event',
  'description': 'A test event.',
  'price': 10000,
  'status': 'published',
  'image_url': null,
  'location': 'Bangalore',
  'start_date': '2099-01-01T10:00:00.000Z',
  'end_date': '2099-01-01T12:00:00.000Z',
  'capacity': 1,
  'booked_count': 0,
  'discussion_enabled': false,
  'discussion_restricted': false,
  'community_id': 'comm-1',
};

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
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
  Future<HttpClientResponse> close() async {
    final body = _bodyFor(url);
    return _FakeHttpResponse(utf8.encode(body));
  }

  @override
  Future addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

String _bodyFor(Uri url) {
  final path = url.path;
  if (path.contains('/rest/v1/events')) {
    return jsonEncode({
      ..._fakeEvent,
      'communities': {'name': 'Test Community'},
    });
  }
  if (path.contains('/rest/v1/media')) {
    return '[]';
  }
  return '[]';
}

class _FakeHttpResponse extends Stream<List<int>> implements HttpClientResponse {
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

Future<void> _pumpScreen(WidgetTester tester) async {
  HttpOverrides.global = _FakeHttpOverrides();
  await tester.pumpWidget(
    MaterialApp(
      theme: CluvoTheme.lightTheme,
      home: const EventDetailScreen(id: 'evt-1'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
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

  testWidgets('paid event shows a disabled "Coming Soon" button',
      (tester) async {
    _fakeEvent['price'] = 10000;

    await _pumpScreen(tester);

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Coming Soon'),
    );
    expect(button, isNotNull);
    expect(button.onPressed, isNull);
    expect(
      find.widgetWithText(ElevatedButton, 'Register & Pay'),
      findsNothing,
    );
  });

  testWidgets('free event keeps the enabled "Register" button',
      (tester) async {
    _fakeEvent['price'] = 0;

    await _pumpScreen(tester);

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Register'),
    );
    expect(button, isNotNull);
    expect(button.onPressed, isNotNull);
  });
}
