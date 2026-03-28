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

  factory RailBoardTokens.of(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 900;
    final isWide = width >= 700;

    return RailBoardTokens(
      isTablet: isTablet,
      isWide: isWide,
      maxContentWidth: isTablet ? 1040 : 700,
      pagePadding: EdgeInsets.fromLTRB(
        isTablet ? 20 : 10,
        isTablet ? 16 : 8,
        isTablet ? 20 : 10,
        isTablet ? 18 : 12,
      ),
      panelPadding: EdgeInsets.all(isTablet ? 16 : 12),
      panelGap: isTablet ? 12 : 8,
      sectionGap: isTablet ? 10 : 8,
      itemGap: isTablet ? 8 : 6,
      compactGap: isTablet ? 6 : 4,
      heroRadius: 20,
      panelRadius: 18,
      chipRadius: 12,
      boardStart: colorScheme.surface,
      boardEnd: colorScheme.surfaceContainerLow,
      shellSurface: colorScheme.surface.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.94 : 0.88,
      ),
      primarySurface: colorScheme.surfaceContainerLowest,
      secondarySurface: colorScheme.surfaceContainerLow,
      accentSurface: theme.brightness == Brightness.dark
          ? colorScheme.surfaceContainerHigh
          : colorScheme.surfaceContainerHighest,
      border: colorScheme.outlineVariant.withValues(alpha: 0.55),
      textMuted: colorScheme.onSurfaceVariant,
      accent: colorScheme.primary,
      accentSoft: colorScheme.onSurface.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.1 : 0.06,
      ),
      shadow: colorScheme.shadow.withValues(alpha: 0.12),
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
