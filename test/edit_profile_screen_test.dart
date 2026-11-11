import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/models.dart';
import 'package:mobile/providers/profile_provider.dart';
import 'package:mobile/screens/edit_profile_screen.dart';
import 'package:mobile/theme.dart';

const List<int> _kTransparentImage = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
];

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpRequest(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpRequest(url);

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
      _FakeHttpResponse(_kTransparentImage);

  @override
  Future addStream(Stream<List<int>> stream) async => await stream.drain<void>();

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

void main() {
  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
  });
  final testProfile = Profile(
    id: 'user_123',
    email: 'test@cluvo.com',
    firstName: 'Praneeth',
    lastName: 'Ch',
    username: 'praneeth',
    avatarUrl: 'https://res.cloudinary.com/demo/image/upload/v1/avatar.jpg',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        profileProvider.overrideWith((ref) async => testProfile),
      ],
      child: MaterialApp(
        theme: CluvoTheme.lightTheme,
        home: const EditProfileScreen(),
      ),
    );
  }

  testWidgets('EditProfileScreen renders initial profile values correctly', (
    tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Praneeth'), findsOneWidget);
    expect(find.text('Ch'), findsOneWidget);
    expect(find.text('praneeth'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Tap to change photo'), findsOneWidget);
  });

  testWidgets('Validation errors appear when required fields are empty', (
    tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Clear first name
    await tester.enterText(find.widgetWithText(TextField, 'Praneeth'), '');
    await tester.pumpAndSettle();

    // Tap Save Changes
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(find.text('First name is required.'), findsOneWidget);
  });

  testWidgets('Two-Tier Deferral: Back button pops without modifying DB when unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Tap Back with no changes - should pop cleanly without dialog
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // Zero dialogs presented
    expect(find.text('Discard changes?'), findsNothing);
  });

  testWidgets('Two-Tier Deferral: Back button prompts confirmation when edits are pending', (
    tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Edit Last Name
    await tester.enterText(find.widgetWithText(TextField, 'Ch'), 'UpdatedLastName');
    await tester.pumpAndSettle();

    // Tap Back with changes - should prompt discard confirmation
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('You have unsaved changes that will be lost.'), findsOneWidget);

    // Cancel discard dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Profile'), findsOneWidget);
  });
}
