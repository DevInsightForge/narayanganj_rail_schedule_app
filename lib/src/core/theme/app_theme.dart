import 'package:flutter/material.dart';

class AppTheme {
  static const _primary = Color(0xFF171717);
  static const _secondary = Color(0xFFE0E0E0);
  static const _background = Color(0xFFEBEBEB);
  static const _surface = Color(0xFFF7F7F7);
  static const _textSecondary = Color(0xFF5E5E5E);
  static const _divider = Color(0xFFD3D3D3);

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
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: const TextStyle(
          fontSize: 44,
          height: 0.98,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
          color: _primary,
        ),
        displayMedium: const TextStyle(
          fontSize: 32,
          height: 0.95,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: _primary,
        ),
        headlineMedium: const TextStyle(
          fontSize: 24,
          height: 1,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: _primary,
        ),
        titleLarge: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: _primary,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
          color: _primary,
        ),
        bodyLarge: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: _primary,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _primary,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: _textSecondary,
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: _primary,
        ),
      ),
    );
  }
}
