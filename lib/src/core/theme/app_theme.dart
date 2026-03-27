import 'package:flutter/material.dart';

class AppTheme {
  static const _primary = Color(0xFF171717);
  static const _primarySoft = Color(0xFF262626);
  static const _secondary = Color(0xFFE0E0E0);
  static const _background = Color(0xFFEBEBEB);
  static const _surface = Color(0xFFF7F7F7);
  static const _surfaceMuted = Color(0xFFF1F1F1);
  static const _textSecondary = Color(0xFF5E5E5E);
  static const _divider = Color(0xFFD3D3D3);
  static const _darkPrimary = Color(0xFFF7F7F7);
  static const _darkPrimarySoft = Color(0xFFE0E0E0);
  static const _darkSecondary = Color(0xFF262626);
  static const _darkBackground = Color(0xFF171717);
  static const _darkSurface = Color(0xFF0F0F0F);
  static const _darkSurfaceMuted = Color(0xFF1A1A1A);
  static const _darkTextSecondary = Color(0xFFB8B8B8);
  static const _darkDivider = Color(0xFF3A3A3A);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primary,
        brightness: Brightness.light,
        primary: _primary,
        secondary: _secondary,
        surface: _surface,
      ),
      scaffoldBackgroundColor: _background,
      fontFamily: 'Segoe UI',
      dividerColor: _divider,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      cardColor: _surface,
      textTheme: base.textTheme.copyWith(
        displayLarge: const TextStyle(
          fontSize: 40,
          height: 1,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
          color: _primary,
        ),
        displayMedium: const TextStyle(
          fontSize: 28,
          height: 1,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.7,
          color: _primary,
        ),
        headlineMedium: const TextStyle(
          fontSize: 22,
          height: 1.05,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: _primary,
        ),
        titleLarge: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: _primary,
        ),
        titleMedium: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
          color: _primary,
        ),
        bodyLarge: const TextStyle(
          fontSize: 15,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: _primary,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w500,
          color: _primary,
        ),
        bodySmall: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: _textSecondary,
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: _primary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _primary,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: _surfaceMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x12171717)),
        ),
        labelStyle: const TextStyle(
          color: _primarySoft,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _darkPrimary,
        brightness: Brightness.dark,
        primary: _darkPrimary,
        secondary: _darkSecondary,
        surface: _darkSurface,
      ),
      scaffoldBackgroundColor: _darkBackground,
      fontFamily: 'Segoe UI',
      dividerColor: _darkDivider,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      cardColor: _darkSurface,
      textTheme: base.textTheme.copyWith(
        displayLarge: const TextStyle(
          fontSize: 40,
          height: 1,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
          color: _darkPrimary,
        ),
        displayMedium: const TextStyle(
          fontSize: 28,
          height: 1,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.7,
          color: _darkPrimary,
        ),
        headlineMedium: const TextStyle(
          fontSize: 22,
          height: 1.05,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: _darkPrimary,
        ),
        titleLarge: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: _darkPrimary,
        ),
        titleMedium: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
          color: _darkPrimary,
        ),
        bodyLarge: const TextStyle(
          fontSize: 15,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: _darkPrimary,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w500,
          color: _darkPrimary,
        ),
        bodySmall: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: _darkTextSecondary,
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: _darkPrimary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _darkPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: _darkSurfaceMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x26F5F5F5)),
        ),
        labelStyle: const TextStyle(
          color: _darkPrimarySoft,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
