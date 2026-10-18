import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/theme.dart';
import 'package:mobile/widgets/media/community_media_section.dart';
import 'package:mobile/widgets/media/media_gallery_screen.dart';

/// Records shaped like real `media` rows (id, type, url, thumbnail_url,
/// caption, created_at). Empty URLs keep image loading out of the test.
Map<String, dynamic> _image(String id) => {
  'id': id,
  'type': 'image',
  'url': '',
  'thumbnail_url': null,
  'caption': null,
  'created_at': null,
};

Map<String, dynamic> _video(String id) => {
  'id': id,
  'type': 'video',
  'url': 'https://cdn.example.com/$id.mp4',
  'thumbnail_url': null,
  'caption': null,
  'created_at': '2026-01-05T10:00:00Z',
};

Widget _wrap(Widget child, {double width = 390}) {
  return MaterialApp(
    theme: CluvoTheme.lightTheme,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    ),
  );
}

Finder _chip(String label) => find.widgetWithText(GestureDetector, label);

void main() {
  group('CommunityMediaSection — filters', () {
    testWidgets('shows every accessible record under All', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CommunityMediaSection(media: [_image('1'), _video('2'), _image('3')]),
        ),
      );

      expect(find.text('3 items'), findsOneWidget);
      // One play badge for the single video tile.
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('Photos hides videos and updates the real count', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CommunityMediaSection(media: [_image('1'), _video('2'), _image('3')]),
        ),
      );

      await tester.tap(_chip('Photos'));
      await tester.pumpAndSettle();

      expect(find.text('2 photos'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('Videos shows only video records', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CommunityMediaSection(media: [_image('1'), _video('2'), _image('3')]),
        ),
      );

      await tester.tap(_chip('Videos'));
      await tester.pumpAndSettle();

      expect(find.text('1 video'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });
  });

  group('CommunityMediaSection — layout toggle', () {
    testWidgets('switches to list rows and preserves the active filter', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CommunityMediaSection(media: [_image('1'), _video('2'), _image('3')]),
        ),
      );

      await tester.tap(_chip('Videos'));
      await tester.pumpAndSettle();
      expect(find.text('1 video'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.view_list_rounded));
      await tester.pumpAndSettle();

      // Filter preserved after the layout change.
      expect(find.text('1 video'), findsOneWidget);
      // List rows render a chevron for photos / play glyph for videos.
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('list layout renders chevrons for photo rows', (tester) async {
      await tester.pumpWidget(
        _wrap(CommunityMediaSection(media: [_image('1'), _image('2')])),
      );

      await tester.tap(find.byIcon(Icons.view_list_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
      expect(find.text('Photo'), findsNWidgets(2));
    });
  });

  group('CommunityMediaSection — empty states', () {
    testWidgets('empty gallery keeps filters and toggle available', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const CommunityMediaSection(media: [])));

      expect(find.text('No media yet.'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);
    });

    testWidgets('empty Photos / Videos filters show their own message', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(CommunityMediaSection(media: [_image('1')])),
      );

      await tester.tap(_chip('Videos'));
      await tester.pumpAndSettle();
      expect(find.text('No videos yet.'), findsOneWidget);

      await tester.tap(_chip('Photos'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });
  });

  group('CommunityMediaSection — responsiveness', () {
    testWidgets('lays out without overflow on a narrow phone', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _wrap(
          CommunityMediaSection(
            media: [_image('1'), _video('2'), _image('3'), _image('4')],
          ),
          width: 320,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('4 items'), findsOneWidget);
    });
  });

  group('MediaGalleryScreen — view only', () {
    testWidgets('exposes no download / save / delete / edit / share actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CluvoTheme.lightTheme,
          home: MediaGalleryScreen(items: [_image('1'), _image('2')]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);

      for (final icon in [
        Icons.download,
        Icons.download_outlined,
        Icons.save_alt,
        Icons.delete,
        Icons.delete_outline,
        Icons.edit,
        Icons.share,
        Icons.share_outlined,
        Icons.more_vert,
      ]) {
        expect(
          find.byIcon(icon),
          findsNothing,
          reason: '$icon must never appear in the view-only photo viewer',
        );
      }
    });
  });
}
