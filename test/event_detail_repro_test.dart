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
  'start_date': '2026-08-06T10:00:00.000Z',
  'end_date': '2026-08-06T12:00:00.000Z',
  'capacity': 10,
  'booked_count': 0,
  'discussion_enabled': true,
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
    return _FakeHttpResponse(utf8.encode(_bodyFor(url)));
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
  if (path.contains('/rest/v1/registrations')) {
    return 'null';
  }
  if (path.contains('/rest/v1/community_members')) {
    return 'null';
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

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('event detail renders in $mode', (tester) async {
      final errors = <FlutterErrorDetails>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.toString().contains('No HTTP') &&
            !details.toString().contains('ClientException')) {
          errors.add(details);
        }
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: CluvoTheme.lightTheme,
          darkTheme: CluvoTheme.darkTheme,
          themeMode: mode,
          home: EventDetailScreen(id: 'evt-1'),
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = oldOnError;
      expect(tester.widgetList(find.byType(ErrorWidget)), isEmpty,
          reason: 'no ErrorWidget in $mode');
      expect(errors, isEmpty, reason: 'no FlutterError in $mode');
      expect(find.text('Test Event'), findsOneWidget,
          reason: 'title rendered in $mode');
      expect(find.text('Coming Soon'), findsOneWidget,
          reason: 'action button rendered in $mode');
    });
  }
}
