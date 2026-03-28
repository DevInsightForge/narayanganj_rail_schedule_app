import 'package:flutter/material.dart';

enum RailPanelSurface { shell, primary, secondary, accent }

class RailBoardTokens {
  const RailBoardTokens({
    required this.isTablet,
    required this.isWide,
    required this.maxContentWidth,
    required this.pagePadding,
    required this.panelPadding,
    required this.panelGap,
    required this.sectionGap,
    required this.itemGap,
    required this.compactGap,
    required this.heroRadius,
    required this.panelRadius,
    required this.chipRadius,
    required this.boardStart,
    required this.boardEnd,
    required this.shellSurface,
    required this.primarySurface,
    required this.secondarySurface,
    required this.accentSurface,
    required this.border,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.shadow,
    required this.success,
    required this.warning,
  });

  final bool isTablet;
  final bool isWide;
  final double maxContentWidth;
  final EdgeInsets pagePadding;
  final EdgeInsets panelPadding;
  final double panelGap;
  final double sectionGap;
  final double itemGap;
  final double compactGap;
  final double heroRadius;
  final double panelRadius;
  final double chipRadius;
  final Color boardStart;
  final Color boardEnd;
  final Color shellSurface;
  final Color primarySurface;
  final Color secondarySurface;
  final Color accentSurface;
  final Color border;
  final Color textMuted;
  final Color accent;
  final Color accentSoft;
  final Color shadow;
  final Color success;
  final Color warning;

  factory RailBoardTokens.of(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 900;
    final isWide = width >= 700;

    return RailBoardTokens(
      isTablet: isTablet,
      isWide: isWide,
      maxContentWidth: isTablet ? 1180 : 760,
      pagePadding: EdgeInsets.fromLTRB(
        isTablet ? 28 : 16,
        isTablet ? 24 : 12,
        isTablet ? 28 : 16,
        isTablet ? 28 : 20,
      ),
      panelPadding: EdgeInsets.all(isTablet ? 20 : 16),
      panelGap: isTablet ? 18 : 12,
      sectionGap: isTablet ? 16 : 12,
      itemGap: 12,
      compactGap: 8,
      heroRadius: 28,
      panelRadius: 24,
      chipRadius: 16,
      boardStart: colorScheme.surface,
      boardEnd: colorScheme.surfaceContainerLow,
      shellSurface: colorScheme.surface.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.94 : 0.88,
      ),
      primarySurface: colorScheme.surfaceContainerLowest,
      secondarySurface: colorScheme.surfaceContainerLow,
      accentSurface: colorScheme.primaryContainer.withValues(alpha: 0.72),
      border: colorScheme.outlineVariant.withValues(alpha: 0.55),
      textMuted: colorScheme.onSurfaceVariant,
      accent: colorScheme.primary,
      accentSoft: colorScheme.primary.withValues(alpha: 0.1),
      shadow: colorScheme.shadow.withValues(alpha: 0.12),
      success: const Color(0xFF1D7A44),
      warning: const Color(0xFF9B5C00),
    );
  }

  Color surfaceFor(RailPanelSurface surface) {
    return switch (surface) {
      RailPanelSurface.shell => shellSurface,
      RailPanelSurface.primary => primarySurface,
      RailPanelSurface.secondary => secondarySurface,
      RailPanelSurface.accent => accentSurface,
    };
  }
}
