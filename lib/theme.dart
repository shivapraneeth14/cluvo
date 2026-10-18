import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Mode-dependent surface tokens. Both light and dark themes keep dark text on
/// a pure-white surface; the only real difference is negligible (the palette is
/// white in every mode).
@immutable
class CluvoTokens extends ThemeExtension<CluvoTokens> {
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color chipFill;

  const CluvoTokens({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.chipFill,
  });

  static const CluvoTokens light = CluvoTokens(
    background: CluvoTheme._backgroundLight,
    surface: CluvoTheme._surfaceLight,
    textPrimary: CluvoTheme.textPrimaryColor,
    textSecondary: CluvoTheme.textSecondaryColor,
    border: CluvoTheme.borderLavender,
    chipFill: CluvoTheme._chipFillLight,
  );

  static const CluvoTokens dark = CluvoTokens(
    background: CluvoTheme._backgroundDark,
    surface: CluvoTheme._surfaceDark,
    textPrimary: CluvoTheme.textPrimaryColor,
    textSecondary: CluvoTheme.textSecondaryColor,
    border: CluvoTheme.borderLavender,
    chipFill: CluvoTheme._chipFillDark,
  );

  @override
  CluvoTokens copyWith({
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? chipFill,
  }) {
    return CluvoTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      chipFill: chipFill ?? this.chipFill,
    );
  }

  @override
  CluvoTokens lerp(ThemeExtension<CluvoTokens>? other, double t) {
    if (other is! CluvoTokens) return this;
    return CluvoTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      chipFill: Color.lerp(chipFill, other.chipFill, t)!,
    );
  }
}

class CluvoTheme {
  // ---------------------------------------------------------------------------
  // Brand palette
  // ---------------------------------------------------------------------------
  // "Ink & Paper" palette. Pure white #FFFFFF is used everywhere — no gray
  // backgrounds and no off-white boxes. Structure comes from crisp, paper-thin
  // black outlines (#000000, 0.5px hairlines) rather than filled surfaces.
  // Hierarchy is carried by typography: large, heavy, bold black headings with
  // small, quiet labels. Token names are retained from earlier palettes to
  // avoid a broad rename across the codebase.
  static const Color primary = Color(0xFF000000); // Ink
  static const Color primaryHover = Color(0xFF000000);
  static const Color primaryLight = Color(0xFF333333);
  static const Color electricViolet = Color(0xFF000000); // Ink
  static const Color deepNavy = Color(0xFF000000); // Ink
  static const Color nightPurple = Color(0xFF1A1A1A); // Ink depth
  static const Color lavenderBackground = Color(0xFFFFFFFF); // Paper
  static const Color milkyFill = Color(0xFFF5F5F7); // Cool milk surface
  static const Color textPrimaryColor = Color(0xFF000000); // Ink
  static const Color textSecondaryColor = Color(0x99000000); // Ink @60%
  static const Color borderLavender = Color(0xFF000000); // Hairline ink
  static const Color lavenderAccent = Color(0xFF000000); // Ink
  static const Color successGreen = Color(0xFF16845B);

  /// Paper-thin hairline used for outlines and dividers.
  static const double hairline = 0.5;

  // Media / gallery surfaces (Community Detail media section).
  static const Color lavenderFill = Color(0xFFFFFFFF); // Paper
  static const Color viewerBackground = Color(0xFF000000); // Ink
  static const Color mediaScrim = Color(0x66000000);

  static const Color error = Color(0xFFEF4444);
  static const Color success = successGreen;

  // Event detail semantics.
  static const Color live = Color(0xFFFF3347);
  static const Color neutral = Color(0xFF6B7280);

  // ---------------------------------------------------------------------------
  // Gradients
  // ---------------------------------------------------------------------------
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF5F5F7), Color(0xFFECECF0), Color(0xFFE4E4EA)],
  );
  static const LinearGradient headlineGradient = LinearGradient(
    colors: [Color(0xFF000000), Color(0xFF9A9A9A)],
  );
  static const LinearGradient primaryCtaGradient = LinearGradient(
    colors: [Color(0xFF000000), Color(0xFF222222)],
  );
  static const LinearGradient freeBannerGradient = LinearGradient(
    colors: [Color(0xFF000000), Color(0xFF1A1A1A)],
  );

  // Body backgrounds: pure white in both modes.
  static const Color _backgroundLight = Color(0xFFFFFFFF);
  static const Color _backgroundDark = Color(0xFFFFFFFF);
  static const Color _surfaceLight = Color(0xFFFFFFFF);
  static const Color _surfaceDark = Color(0xFFFFFFFF);
  static const Color _chipFillLight = Color(0xFFFFFFFF);
  static const Color _chipFillDark = Color(0xFFFFFFFF);

  static Color backgroundFor(Brightness brightness) =>
      brightness == Brightness.dark ? _backgroundDark : _backgroundLight;
  static Color surfaceFor(Brightness brightness) =>
      brightness == Brightness.dark ? _surfaceDark : _surfaceLight;
  static Color textPrimaryFor(Brightness brightness) => textPrimaryColor;
  static Color textSecondaryFor(Brightness brightness) => textSecondaryColor;
  static Color borderFor(Brightness brightness) => borderLavender;
  static Color chipFillFor(Brightness brightness) =>
      brightness == Brightness.dark ? _chipFillDark : _chipFillLight;
  static Color primaryTextFor(Brightness brightness) => primary;

  // Spacing / radius tokens
  static const double screenPadding = 22;
  static const double sectionSpacing = 32;
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;
  static const double radiusXl = 16;
  static const double radiusCard = 24;
  static const double radiusPill = 28;
  static const double radiusSearch = 34;
  static const double radiusButton = 18;

  static ThemeData get lightTheme => _buildTheme(CluvoTokens.light);
  static ThemeData get darkTheme => _buildTheme(CluvoTokens.dark);

  static ThemeData _buildTheme(CluvoTokens tokens) {
    // A light ColorScheme + Brightness.light keeps all framework defaults on
    // dark text, which is required because both modes are light surfaces.
    const scheme = ColorScheme.light(
      primary: primary,
      secondary: electricViolet,
      error: error,
      surface: _surfaceLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: tokens.background,
      colorScheme: scheme,
      extensions: [tokens],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textPrimaryColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: textPrimaryColor),
        titleTextStyle: TextStyle(
          color: textPrimaryColor,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        shape: Border(
          bottom: BorderSide(color: textPrimaryColor, width: hairline),
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: borderLavender, width: hairline),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: primary.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? textPrimaryColor : textSecondaryColor,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? textPrimaryColor : textSecondaryColor,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: borderLavender,
        thickness: hairline,
        space: hairline,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderLavender, width: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderLavender, width: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: error),
        ),
        labelStyle: TextStyle(color: tokens.textSecondary, fontSize: 14),
        hintStyle: TextStyle(
          color: tokens.textSecondary.withValues(alpha: 0.6),
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

extension CluvoThemeX on BuildContext {
  CluvoTokens get _tokens =>
      Theme.of(this).extension<CluvoTokens>() ?? CluvoTokens.light;

  Color get cluvoBackground => _tokens.background;
  Color get cluvoSurface => _tokens.surface;
  Color get cluvoTextPrimary => _tokens.textPrimary;
  Color get cluvoTextSecondary => _tokens.textSecondary;
  Color get cluvoBorder => _tokens.border;
  Color get cluvoChipFill => _tokens.chipFill;
  Color get cluvoPrimaryText => CluvoTheme.primary;

  /// Light lavender used for inactive chips / icon backgrounds in the media
  /// gallery. Constant in both modes so the gallery keeps a single look.
  Color get cluvoLavenderFill => CluvoTheme.lavenderFill;

  /// Dark surface behind full-screen photo / video viewers.
  Color get cluvoViewerBackground => CluvoTheme.viewerBackground;

  Color get cluvoErrorFill => const Color(0xFFFEF2F2);
  Color get cluvoErrorBorder => const Color(0xFFFECACA);
  Color get cluvoErrorText => const Color(0xFFDC2626);
  Color get cluvoSuccessFill => const Color(0xFFF0FDF4);
  Color get cluvoSuccessBorder => const Color(0xFFBBF7D0);
  Color get cluvoSuccessText => CluvoTheme.successGreen;
}
