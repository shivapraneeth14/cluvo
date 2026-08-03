import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModePrefsKey = 'theme_mode';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier({ThemeMode initial = ThemeMode.light}) : super(initial);

  Future<void> toggle() async {
    final next =
        state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModePrefsKey, next.name);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

Future<ThemeMode> loadSavedThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_themeModePrefsKey);
    if (saved == ThemeMode.dark.name) return ThemeMode.dark;
  } catch (_) {
    // Preference read failed — default to light theme
  }
  return ThemeMode.light;
}
