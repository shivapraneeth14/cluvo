import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  Future<HttpClientResponse> close() async =>
      _FakeHttpResponse(utf8.encode('[]'));

  @override
  Future addStream(Stream<List<int>> stream) async {
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

class _ThemeProbe extends StatelessWidget {
  const _ThemeProbe({required this.builder});

  final Color Function(BuildContext context) builder;

  @override
  Widget build(BuildContext context) {
    return Text('', style: TextStyle(color: builder(context)));
  }
}

Color _probeColor(WidgetTester tester, Color Function(BuildContext) builder) {
  final text = tester.widget<Text>(find.byType(Text));
  return (text.style?.color) ?? Colors.transparent;
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

  group('brand palette', () {
    test('maps every token to its value in both modes', () {
      const light = Brightness.light;
      const dark = Brightness.dark;

      // Pure white canvas in both modes.
      expect(CluvoTheme.backgroundFor(light), const Color(0xFFFFFFFF));
      expect(CluvoTheme.backgroundFor(dark), const Color(0xFFFFFFFF));
      expect(CluvoTheme.surfaceFor(light), const Color(0xFFFFFFFF));
      expect(CluvoTheme.surfaceFor(dark), const Color(0xFFFFFFFF));

      // Ink text in both modes.
      expect(CluvoTheme.textPrimaryFor(light), const Color(0xFF000000));
      expect(CluvoTheme.textPrimaryFor(dark), const Color(0xFF000000));
      expect(CluvoTheme.textSecondaryFor(light), const Color(0x99000000));
      expect(CluvoTheme.textSecondaryFor(dark), const Color(0x99000000));
      expect(CluvoTheme.borderFor(light), const Color(0xFF000000));
      expect(CluvoTheme.borderFor(dark), const Color(0xFF000000));

      expect(CluvoTheme.chipFillFor(light), const Color(0xFFFFFFFF));
      expect(CluvoTheme.chipFillFor(dark), const Color(0xFFFFFFFF));

      // Ink brand accent in both modes.
      expect(CluvoTheme.primaryTextFor(light), const Color(0xFF000000));
      expect(CluvoTheme.primaryTextFor(dark), const Color(0xFF000000));
    });

    test('dark theme uses pure white background and surface', () {
      expect(
        CluvoTheme.darkTheme.scaffoldBackgroundColor,
        const Color(0xFFFFFFFF),
      );
      expect(CluvoTheme.darkTheme.colorScheme.surface, const Color(0xFFFFFFFF));
      // Both themes are intentionally light so framework text defaults stay
      // dark on the light surfaces.
      expect(CluvoTheme.darkTheme.brightness, Brightness.light);
    });
  });

  group('context extension', () {
    testWidgets('resolves dark tokens through the theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CluvoTheme.lightTheme,
          darkTheme: CluvoTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) => Column(
              children: [
                _ThemeProbe(builder: (c) => c.cluvoChipFill),
                _ThemeProbe(builder: (c) => c.cluvoSurface),
                _ThemeProbe(builder: (c) => c.cluvoErrorFill),
                _ThemeProbe(builder: (c) => c.cluvoSuccessText),
                _ThemeProbe(builder: (c) => c.cluvoPrimaryText),
              ],
            ),
          ),
        ),
      );

      final texts = tester.widgetList<Text>(find.byType(Text)).toList();
      expect(texts[0].style?.color, const Color(0xFFFFFFFF));
      expect(texts[1].style?.color, const Color(0xFFFFFFFF));
      expect(texts[2].style?.color, const Color(0xFFFEF2F2));
      expect(texts[3].style?.color, const Color(0xFF16845B));
      expect(texts[4].style?.color, const Color(0xFF000000));
    });

    testWidgets('follows a live theme toggle from light to dark', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CluvoTheme.lightTheme,
          darkTheme: CluvoTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: _ThemeProbe(builder: (c) => c.cluvoChipFill),
        ),
      );
      expect(
        _probeColor(tester, (c) => c.cluvoChipFill),
        const Color(0xFFFFFFFF),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CluvoTheme.lightTheme,
          darkTheme: CluvoTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: _ThemeProbe(builder: (c) => c.cluvoChipFill),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        _probeColor(tester, (c) => c.cluvoChipFill),
        const Color(0xFFFFFFFF),
      );
    });
  });
}
