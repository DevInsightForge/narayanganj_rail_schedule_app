import 'package:flutter/material.dart';

class AppTheme {
  static const _primary = Color(0xFF000000);
  static const _onPrimary = Color(0xFFFFFFFF);
  static const _secondary = Color(0xFF262626);
  static const _background = Color(0xFFF5F5F5);
  static const _surface = Color(0xFFFFFFFF);
  static const _surfaceLow = Color(0xFFF5F5F5);
  static const _surfaceMuted = Color(0xFFEEEEEE);
  static const _surfaceHigh = Color(0xFFE5E5E5);
  static const _surfaceHighest = Color(0xFFDCDCDC);
  static const _textPrimary = Color(0xFF000000);
  static const _textSecondary = Color(0xFF555555);
  static const _divider = Color(0xFFE0E0E0);
  static const _outline = Color(0xFF888888);

  static const _darkPrimary = Color(0xFFFFFFFF);
  static const _darkOnPrimary = Color(0xFF000000);
  static const _darkSecondary = Color(0xFFE0E0E0);
  static const _darkBackground = Color(0xFF000000);
  static const _darkSurfaceLowest = Color(0xFF0A0A0A);
  static const _darkSurface = Color(0xFF121212);
  static const _darkSurfaceLow = Color(0xFF161616);
  static const _darkSurfaceMuted = Color(0xFF1E1E1E);
  static const _darkSurfaceHigh = Color(0xFF262626);
  static const _darkSurfaceHighest = Color(0xFF333333);
  static const _darkTextPrimary = Color(0xFFFFFFFF);
  static const _darkTextSecondary = Color(0xFFAAAAAA);
  static const _darkDivider = Color(0xFF2A2A2A);
  static const _darkOutline = Color(0xFF777777);
  static const _shadow = Color(0xFF000000);

  static ThemeData light() {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: _primary,
      onPrimary: _onPrimary,
      primaryContainer: _surfaceHigh,
      onPrimaryContainer: _primary,
      secondary: _secondary,
      onSecondary: _onPrimary,
      secondaryContainer: _surfaceMuted,
      onSecondaryContainer: _textPrimary,
      surface: _surface,
      onSurface: _textPrimary,
      surfaceContainerLowest: _surface,
      surfaceContainerLow: _surfaceLow,
      surfaceContainer: _surfaceMuted,
      surfaceContainerHigh: _surfaceHigh,
      surfaceContainerHighest: _surfaceHighest,
      onSurfaceVariant: _textSecondary,
      outline: _outline,
      outlineVariant: _divider,
      shadow: _shadow,
      error: _textPrimary,
      onError: _onPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _background,
      fontFamily: 'Segoe UI',
      dividerColor: _divider,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      cardColor: _surface,
      textTheme: base.textTheme.copyWith(
        displayLarge: const TextStyle(
          fontSize: 48,
          height: 1,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
          color: _textPrimary,
        ),
        displaySmall: const TextStyle(
          fontSize: 36,
          height: 1.05,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: _textPrimary,
        ),
        headlineSmall: const TextStyle(
          fontSize: 24,
          height: 1.1,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: _textPrimary,
        ),
        headlineMedium: const TextStyle(
          fontSize: 22,
          height: 1.1,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: _textPrimary,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: _textPrimary,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
          color: _textPrimary,
        ),
        bodyLarge: const TextStyle(
          fontSize: 15,
          height: 1.35,
          fontWeight: FontWeight.w500,
          color: _textPrimary,
        ),
        bodyMedium: const TextStyle(
          fontSize: 15,
          height: 1.35,
          fontWeight: FontWeight.w500,
          color: _textPrimary,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: _textSecondary,
        ),
        labelMedium: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: _textSecondary,
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: _textPrimary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: _surfaceMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _divider),
        ),
        labelStyle: const TextStyle(
          color: _textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 42),
          side: const BorderSide(color: _divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _darkPrimary,
      onPrimary: _darkOnPrimary,
      primaryContainer: _darkSurfaceHigh,
      onPrimaryContainer: _darkPrimary,
      secondary: _darkSecondary,
      onSecondary: _darkOnPrimary,
      secondaryContainer: _darkSurfaceMuted,
      onSecondaryContainer: _darkTextPrimary,
      surface: _darkSurface,
      onSurface: _darkTextPrimary,
      surfaceContainerLowest: _darkSurfaceLowest,
      surfaceContainerLow: _darkSurfaceLow,
      surfaceContainer: _darkSurfaceMuted,
      surfaceContainerHigh: _darkSurfaceHigh,
      surfaceContainerHighest: _darkSurfaceHighest,
      onSurfaceVariant: _darkTextSecondary,
      outline: _darkOutline,
      outlineVariant: _darkDivider,
      shadow: _shadow,
      error: _darkTextPrimary,
      onError: _darkOnPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _darkBackground,
      fontFamily: 'Segoe UI',
      dividerColor: _darkDivider,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      cardColor: _darkSurface,
      textTheme: base.textTheme.copyWith(
        displayLarge: const TextStyle(
          fontSize: 48,
          height: 1,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
          color: _darkTextPrimary,
        ),
        displaySmall: const TextStyle(
          fontSize: 36,
          height: 1.05,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: _darkTextPrimary,
        ),
        headlineSmall: const TextStyle(
          fontSize: 24,
          height: 1.1,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: _darkTextPrimary,
        ),
        headlineMedium: const TextStyle(
          fontSize: 22,
          height: 1.1,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: _darkTextPrimary,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: _darkTextPrimary,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
          color: _darkTextPrimary,
        ),
        bodyLarge: const TextStyle(
          fontSize: 15,
          height: 1.35,
          fontWeight: FontWeight.w500,
          color: _darkTextPrimary,
        ),
        bodyMedium: const TextStyle(
          fontSize: 15,
          height: 1.35,
          fontWeight: FontWeight.w500,
          color: _darkTextPrimary,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: _darkTextSecondary,
        ),
        labelMedium: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: _darkTextSecondary,
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: _darkTextPrimary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _darkTextPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: _darkSurfaceMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _darkDivider),
        ),
        labelStyle: const TextStyle(
          color: _darkTextPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 42),
          side: const BorderSide(color: _darkDivider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
