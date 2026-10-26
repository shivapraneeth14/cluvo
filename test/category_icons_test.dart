import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/category_icons.dart';

void main() {
  group('categoryIcon (unified vocabulary)', () {
    test('maps every event preset', () {
      expect(categoryIcon('Music'), Icons.music_note);
      expect(categoryIcon('Technology'), Icons.memory);
      expect(categoryIcon('Comedy'), Icons.theater_comedy);
      expect(categoryIcon('Workshops'), Icons.handyman_outlined);
      expect(categoryIcon('Wellness'), Icons.spa_outlined);
      expect(categoryIcon('Art & Culture'), Icons.palette);
      expect(categoryIcon('Sports & Fitness'), Icons.sports_basketball);
      expect(categoryIcon('Food & Drink'), Icons.restaurant);
      expect(categoryIcon('Business & Finance'), Icons.work_outline);
      expect(categoryIcon('Education'), Icons.school_outlined);
      expect(categoryIcon('Social & Community'), Icons.groups_outlined);
      expect(categoryIcon('Other'), Icons.local_activity_outlined);
    });

    test('maps every community preset', () {
      expect(categoryIcon('Music & Arts'), Icons.music_note);
      expect(categoryIcon('Health & Wellness'), Icons.spa_outlined);
      expect(categoryIcon('Travel & Outdoors'), Icons.terrain);
      expect(categoryIcon('Gaming'), Icons.sports_esports);
      expect(categoryIcon('Photography'), Icons.photo_camera_outlined);
    });

    test('is case-insensitive and tolerant of spelling', () {
      expect(categoryIcon('music'), Icons.music_note);
      expect(categoryIcon('HIKE'), Icons.terrain);
      expect(categoryIcon('photography club'), Icons.photo_camera_outlined);
    });

    test('falls back for unknown categories', () {
      expect(categoryIcon('Something Random'), Icons.local_activity_outlined);
      expect(categoryIcon(''), Icons.local_activity_outlined);
    });

    test('exposes an All icon', () {
      expect(kAllCategoriesIcon, Icons.apps);
    });
  });
}
