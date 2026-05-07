import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppPalette {
  static const Color primary = Color(0xFF0E7A80);
  static const Color secondary = Color(0xFFFF8A5B);
  static const Color tertiary = Color(0xFF3D6DFF);
  static const Color scaffold = Color(0xFFF8FAFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFCFE2FF);
}

ThemeData buildTheme() {
  final base = ColorScheme.fromSeed(seedColor: AppPalette.primary);
  final scheme = base.copyWith(
    primary: AppPalette.primary,
    secondary: AppPalette.secondary,
    tertiary: AppPalette.tertiary,
    surface: AppPalette.card,
    onSurface: const Color(0xFF152033),
    outlineVariant: AppPalette.border,
  );

  final baseTextTheme = GoogleFonts.notoSansTextTheme();
  final textTheme = baseTextTheme.copyWith(
    headlineSmall: baseTextTheme.headlineSmall?.copyWith(
      fontSize: 28,
      height: 1.15,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: baseTextTheme.titleLarge?.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
    titleMedium: baseTextTheme.titleMedium?.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
    bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.35),
    bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.35),
    labelLarge: baseTextTheme.labelLarge?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w700,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppPalette.scaffold,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      iconTheme: IconThemeData(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: AppPalette.card.withAlpha(240),
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppPalette.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withAlpha(224),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppPalette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppPalette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppPalette.primary, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: AppPalette.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppPalette.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: const BorderSide(color: AppPalette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withAlpha(220),
      selectedColor: AppPalette.tertiary.withAlpha(30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: const BorderSide(color: AppPalette.border),
      labelStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white.withAlpha(230),
      indicatorColor: AppPalette.tertiary.withAlpha(36),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppPalette.tertiary);
        }
        return IconThemeData(color: scheme.onSurface.withAlpha(170));
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return textTheme.labelMedium?.copyWith(
            color: AppPalette.tertiary,
            fontWeight: FontWeight.w700,
          );
        }
        return textTheme.labelMedium?.copyWith(
          color: scheme.onSurface.withAlpha(180),
        );
      }),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppPalette.tertiary,
      linearTrackColor: Color(0xFFDCE9FF),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1E2A3D),
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
