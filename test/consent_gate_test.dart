import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/providers/consent_provider.dart';
import 'package:mobile/screens/consent_gate.dart';
import 'package:mobile/theme.dart';

/// Fake notifiers used to drive ConsentGate with deterministic state.
class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(super.ref, AuthState initial) : super() {
    state = initial;
  }
}

class _FakeConsentNotifier extends ConsentNotifier {
  _FakeConsentNotifier(ConsentState initial) : super() {
    state = initial;
  }
}

Session _session({required int accountAgeSeconds, required int lastActiveSeconds}) {
  final now = DateTime.now().toUtc();
  final createdAt = now.subtract(Duration(seconds: accountAgeSeconds));
  final lastSignInAt = now.subtract(Duration(seconds: lastActiveSeconds));
  return Session(
    accessToken: 'at',
    refreshToken: 'rt',
    tokenType: 'bearer',
    user: User(
      id: 'user-1',
      aud: 'authenticated',
      appMetadata: const {},
      userMetadata: const {},
      createdAt: createdAt.toIso8601String(),
      lastSignInAt: lastSignInAt.toIso8601String(),
    ),
  );
}

/// A brand-new account (created within the 120s heuristic window).
Session newAccount() => _session(accountAgeSeconds: 30, lastActiveSeconds: 30);

/// A returning account (well outside the 120s heuristic window).
Session returningAccount() =>
    _session(accountAgeSeconds: 5 * 86400, lastActiveSeconds: 3600);

Future<void> pumpGate(
  WidgetTester tester, {
  required AuthState auth,
  required ConsentState consent,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) => _FakeAuthNotifier(ref, auth)),
        consentProvider.overrideWith((ref) => _FakeConsentNotifier(consent)),
      ],
      child: MaterialApp(
        theme: CluvoTheme.lightTheme,
        home: ConsentGate(child: const Scaffold(body: Text('APP_CONTENT'))),
      ),
    ),
  );
}

void main() {
  testWidgets('gate hidden when logged out', (tester) async {
    await pumpGate(tester, auth: const AuthState(), consent: const ConsentState());
    expect(find.text('APP_CONTENT'), findsOneWidget);
    expect(find.text('I Agree & Continue'), findsNothing);
  });

  testWidgets('gate hidden when consent confirmed true', (tester) async {
    await pumpGate(
      tester,
      auth: AuthState(session: newAccount()),
      consent: const ConsentState(consented: true),
    );
    expect(find.text('APP_CONTENT'), findsOneWidget);
  });

  testWidgets('gate hidden for returning account with unknown consent',
      (tester) async {
    await pumpGate(
      tester,
      auth: AuthState(session: returningAccount()),
      consent: const ConsentState(),
    );
    expect(find.text('APP_CONTENT'), findsOneWidget);
    expect(find.text('I Agree & Continue'), findsNothing);
  });

  testWidgets('gate hidden while a check is in flight', (tester) async {
    await pumpGate(
      tester,
      auth: AuthState(session: newAccount()),
      consent: const ConsentState(checking: true),
    );
    expect(find.text('APP_CONTENT'), findsOneWidget);
  });

  testWidgets('gate shown for new account with unknown consent (fail closed)',
      (tester) async {
    await pumpGate(
      tester,
      auth: AuthState(session: newAccount()),
      consent: const ConsentState(),
    );
    expect(find.text('APP_CONTENT'), findsNothing);
    expect(find.text('I Agree & Continue'), findsOneWidget);
  });

  testWidgets('gate shown for returning account when server confirms no consent',
      (tester) async {
    await pumpGate(
      tester,
      auth: AuthState(session: returningAccount()),
      consent: const ConsentState(consented: false),
    );
    expect(find.text('I Agree & Continue'), findsOneWidget);
  });

  testWidgets('gate shows error and retry for new account when check failed',
      (tester) async {
    await pumpGate(
      tester,
      auth: AuthState(session: newAccount()),
      consent: const ConsentState(
          error: 'Could not verify consent status. Check your connection.'),
    );
    expect(find.textContaining('Could not verify consent status'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}