import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/providers/auth_provider.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:mobile/theme.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(super.ref) : super() {
    state = const AuthState();
  }
}

Widget _app() {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith((ref) => _FakeAuthNotifier(ref)),
    ],
    child: MaterialApp(
      theme: CluvoTheme.lightTheme,
      home: const LoginScreen(),
    ),
  );
}

FilledButton _googleButton(WidgetTester tester) {
  return tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Continue with Google'),
  );
}

/// Taps the exact glyph area of a link span inside the TermsCheckbox RichText
/// ("Privacy Policy" / "Terms of Service" are spans, not standalone widgets).
Future<void> _tapLinkSpan(WidgetTester tester, String linkText) async {
  final finder = find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().contains(linkText),
  );
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final full = paragraph.text.toPlainText();
  final start = full.indexOf(linkText);
  expect(start, greaterThanOrEqualTo(0), reason: '$linkText not in checkbox text');
  final selection = TextSelection(
    baseOffset: start,
    extentOffset: start + linkText.length,
  );
  final box = paragraph.getBoxesForSelection(selection).first;
  final center = Offset(
    (box.left + box.right) / 2,
    (box.top + box.bottom) / 2,
  );
  await tester.tapAt(paragraph.localToGlobal(center));
}

void main() {
  testWidgets('Google button disabled until the terms box is ticked', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    expect(_googleButton(tester).onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(_googleButton(tester).onPressed, isNotNull);
  });

  testWidgets('tapping the checkbox again re-disables the Google button', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(_googleButton(tester).onPressed, isNotNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(_googleButton(tester).onPressed, isNull);
  });

  testWidgets('Privacy Policy link opens the policy dialog', (tester) async {
    await tester.pumpWidget(_app());

    await _tapLinkSpan(tester, 'Privacy Policy');
    // The login wallpaper animates forever, so pumpAndSettle would time out —
    // a few pumps are enough for the dialog route transition.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Privacy Policy'), findsWidgets);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('Terms of Service link opens the policy dialog', (tester) async {
    await tester.pumpWidget(_app());

    await _tapLinkSpan(tester, 'Terms of Service');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Terms of Service'), findsWidgets);
    expect(find.text('Close'), findsOneWidget);
  });
}
