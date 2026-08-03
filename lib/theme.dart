import 'package:flutter/material.dart';

class CluvoTheme {
  static const Color primary = Color(0xFFC2185B);
  static const Color primaryHover = Color(0xFFA0154A);
  static const Color primaryLight = Color(0xFFE0407A);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);

  static const Color _backgroundLight = Color(0xFFFAFAFA);
  static const Color _backgroundDark = Color(0xFF121212);
  static const Color _surfaceLight = Color(0xFFFFFFFF);
  static const Color _surfaceDark = Color(0xFF1E1E1E);
  static const Color _textPrimaryLight = Color(0xFF171717);
  static const Color _textPrimaryDark = Color(0xFFEDEDED);
  static const Color _textSecondaryLight = Color(0xFF737373);
  static const Color _textSecondaryDark = Color(0xFF9E9E9E);
  static const Color _borderLight = Color(0xFFE5E5E5);
  static const Color _borderDark = Color(0xFF2C2C2C);
  static const Color _chipFillLight = Color(0xFFF1F1F1);
  static const Color _chipFillDark = Color(0xFF2E2E2E);

  static Color backgroundFor(Brightness brightness) =>
      brightness == Brightness.dark ? _backgroundDark : _backgroundLight;
  static Color surfaceFor(Brightness brightness) =>
      brightness == Brightness.dark ? _surfaceDark : _surfaceLight;
  static Color textPrimaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? _textPrimaryDark : _textPrimaryLight;
  static Color textSecondaryFor(Brightness brightness) =>
      brightness == Brightness.dark ? _textSecondaryDark : _textSecondaryLight;
  static Color borderFor(Brightness brightness) =>
      brightness == Brightness.dark ? _borderDark : _borderLight;
  static Color chipFillFor(Brightness brightness) =>
      brightness == Brightness.dark ? _chipFillDark : _chipFillLight;
  static Color primaryTextFor(Brightness brightness) =>
      brightness == Brightness.dark ? primaryLight : primary;

  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;

  static ThemeData get lightTheme => _buildTheme(
        brightness: Brightness.light,
        background: _backgroundLight,
        surface: _surfaceLight,
        textPrimary: _textPrimaryLight,
        textSecondary: _textSecondaryLight,
        border: _borderLight,
      );

  static ThemeData get darkTheme => _buildTheme(
        brightness: Brightness.dark,
        background: _backgroundDark,
        surface: _surfaceDark,
        textPrimary: _textPrimaryDark,
        textSecondary: _textSecondaryDark,
        border: _borderDark,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
    required Color border,
  }) {
    final scheme = brightness == Brightness.dark
        ? const ColorScheme.dark(
            primary: primary,
            error: error,
            surface: _surfaceDark,
          )
        : const ColorScheme.light(
            primary: primary,
            error: error,
            surface: _surfaceLight,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withValues(alpha: 0.1),
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: border),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: error),
        ),
        labelStyle: TextStyle(color: textSecondary, fontSize: 14),
        hintStyle:
            TextStyle(color: textSecondary.withValues(alpha: 0.5), fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryTextFor(brightness),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

extension CluvoThemeX on BuildContext {
  Color get cluvoBackground =>
      CluvoTheme.backgroundFor(Theme.of(this).brightness);
  Color get cluvoSurface => CluvoTheme.surfaceFor(Theme.of(this).brightness);
  Color get cluvoTextPrimary =>
      CluvoTheme.textPrimaryFor(Theme.of(this).brightness);
  Color get cluvoTextSecondary =>
      CluvoTheme.textSecondaryFor(Theme.of(this).brightness);
  Color get cluvoBorder => CluvoTheme.borderFor(Theme.of(this).brightness);
  Color get cluvoChipFill => CluvoTheme.chipFillFor(Theme.of(this).brightness);
  Color get cluvoPrimaryText =>
      CluvoTheme.primaryTextFor(Theme.of(this).brightness);
  Color get cluvoErrorFill =>
      Theme.of(this).brightness == Brightness.dark
          ? CluvoTheme.error.withValues(alpha: 0.1)
          : const Color(0xFFFEF2F2);
  Color get cluvoErrorBorder =>
      Theme.of(this).brightness == Brightness.dark
              ? CluvoTheme.error.withValues(alpha: 0.3)
              : const Color(0xFFFECACA);
  Color get cluvoErrorText => Theme.of(this).brightness == Brightness.dark
      ? const Color(0xFFF87171)
      : const Color(0xFFDC2626);
  Color get cluvoSuccessFill =>
      Theme.of(this).brightness == Brightness.dark
          ? CluvoTheme.success.withValues(alpha: 0.1)
          : const Color(0xFFF0FDF4);
  Color get cluvoSuccessBorder =>
      Theme.of(this).brightness == Brightness.dark
              ? CluvoTheme.success.withValues(alpha: 0.3)
              : const Color(0xFFBBF7D0);
  Color get cluvoSuccessText =>
      Theme.of(this).brightness == Brightness.dark
          ? const Color(0xFF34D399)
          : const Color(0xFF16A34A);
}
