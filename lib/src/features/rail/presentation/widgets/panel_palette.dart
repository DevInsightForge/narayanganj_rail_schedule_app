import 'package:flutter/material.dart';

enum RailPanelSurface { primary, secondary, accent }

class RailBoardTokens {
  const RailBoardTokens({
    required this.isWide,
    required this.maxContentWidth,
    required this.pagePadding,
    required this.panelPadding,
    required this.sheetPadding,
    required this.panelGap,
    required this.sectionGap,
    required this.itemGap,
    required this.compactGap,
    required this.heroRadius,
    required this.panelRadius,
    required this.chipRadius,
    required this.boardStart,
    required this.boardEnd,
    required this.primarySurface,
    required this.secondarySurface,
    required this.accentSurface,
    required this.border,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.shadow,
  });

  final bool isWide;
  final double maxContentWidth;
  final EdgeInsets pagePadding;
  final EdgeInsets panelPadding;
  final EdgeInsets sheetPadding;
  final double panelGap;
  final double sectionGap;
  final double itemGap;
  final double compactGap;
  final double heroRadius;
  final double panelRadius;
  final double chipRadius;
  final Color boardStart;
  final Color boardEnd;
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
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final isTablet = width >= 900;
    final isWide = width >= 700;
    final isCompact = width < 360;

    return RailBoardTokens(
      isWide: isWide,
      maxContentWidth: isTablet ? 1040 : 700,
      pagePadding: EdgeInsets.fromLTRB(
        isTablet ? 20 : (isCompact ? 6 : 10),
        isTablet ? 16 : (isCompact ? 6 : 8),
        isTablet ? 20 : (isCompact ? 6 : 10),
        isTablet ? 18 : (isCompact ? 10 : 12),
      ),
      panelPadding: EdgeInsets.all(isTablet ? 16 : (isCompact ? 10 : 12)),
      sheetPadding: EdgeInsets.fromLTRB(
        isTablet ? 16 : (isCompact ? 10 : 12),
        0,
        isTablet ? 16 : (isCompact ? 10 : 12),
        isTablet ? 44 : 40,
      ),
      panelGap: isTablet ? 12 : (isCompact ? 6 : 8),
      sectionGap: isTablet ? 10 : (isCompact ? 6 : 8),
      itemGap: isTablet ? 8 : (isCompact ? 5 : 6),
      compactGap: isTablet ? 6 : (isCompact ? 3 : 4),
      heroRadius: 20,
      panelRadius: 18,
      chipRadius: 12,
      boardStart: theme.scaffoldBackgroundColor,
      boardEnd: colorScheme.surfaceContainerLow,
      primarySurface: colorScheme.surfaceContainerLowest,
      secondarySurface: colorScheme.surfaceContainerLow,
      accentSurface: isDark
          ? colorScheme.surfaceContainerHigh
          : colorScheme.surfaceContainerHighest,
      border: colorScheme.outlineVariant,
      textMuted: colorScheme.onSurfaceVariant,
      accent: colorScheme.primary,
      accentSoft: colorScheme.onSurface.withValues(alpha: isDark ? 0.12 : 0.06),
      shadow: colorScheme.shadow.withValues(alpha: isDark ? 0.40 : 0.08),
    );
  }

  Color surfaceFor(RailPanelSurface surface) {
    return switch (surface) {
      RailPanelSurface.primary => primarySurface,
      RailPanelSurface.secondary => secondarySurface,
      RailPanelSurface.accent => accentSurface,
    };
  }
}
