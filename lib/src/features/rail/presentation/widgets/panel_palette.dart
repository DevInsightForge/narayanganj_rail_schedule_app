import 'package:flutter/material.dart';

class RailPanelPalette {
  const RailPanelPalette({
    required this.panelBackground,
    required this.panelSurface,
    required this.panelElevatedSurface,
    required this.panelBorder,
    required this.panelMutedText,
    required this.headerBackground,
    required this.headerOn,
    required this.headerSoftFill,
    required this.headerSoftBorder,
    required this.headerChipFill,
    required this.headerChipBorder,
    required this.headerChipText,
    required this.headerSelectedChipFill,
    required this.headerSelectedChipBorder,
    required this.headerSelectedChipText,
    required this.noticeIconTint,
    required this.noticeIconBackground,
    required this.shadow,
  });

  final Color panelBackground;
  final Color panelSurface;
  final Color panelElevatedSurface;
  final Color panelBorder;
  final Color panelMutedText;
  final Color headerBackground;
  final Color headerOn;
  final Color headerSoftFill;
  final Color headerSoftBorder;
  final Color headerChipFill;
  final Color headerChipBorder;
  final Color headerChipText;
  final Color headerSelectedChipFill;
  final Color headerSelectedChipBorder;
  final Color headerSelectedChipText;
  final Color noticeIconTint;
  final Color noticeIconBackground;
  final Color shadow;

  factory RailPanelPalette.of(ColorScheme colorScheme) {
    final isDarkTheme = colorScheme.brightness == Brightness.dark;
    final headerOn = colorScheme.onSurface;

    return RailPanelPalette(
      panelBackground: colorScheme.surfaceContainerLow,
      panelSurface: colorScheme.surfaceContainer,
      panelElevatedSurface: colorScheme.surfaceContainerHighest,
      panelBorder: colorScheme.outlineVariant.withValues(alpha: 0.45),
      panelMutedText: colorScheme.onSurfaceVariant,
      headerBackground: isDarkTheme
          ? colorScheme.surfaceContainerHigh
          : colorScheme.surfaceContainerHigh,
      headerOn: headerOn,
      headerSoftFill: headerOn.withValues(alpha: isDarkTheme ? 0.08 : 0.05),
      headerSoftBorder: headerOn.withValues(alpha: isDarkTheme ? 0.2 : 0.14),
      headerChipFill: isDarkTheme
          ? const Color(0xFF3A3A3A)
          : const Color(0xFFE2E2E2),
      headerChipBorder: isDarkTheme
          ? const Color(0xFF5A5A5A)
          : const Color(0xFFC7C7C7),
      headerChipText: isDarkTheme
          ? const Color(0xFFF1F1F1)
          : const Color(0xFF202020),
      headerSelectedChipFill: isDarkTheme
          ? const Color(0xFFE6E6E6)
          : const Color(0xFF2A2A2A),
      headerSelectedChipBorder: isDarkTheme
          ? const Color(0xFFF2F2F2)
          : const Color(0xFF3A3A3A),
      headerSelectedChipText: isDarkTheme
          ? const Color(0xFF1A1A1A)
          : const Color(0xFFF2F2F2),
      noticeIconTint: colorScheme.primary,
      noticeIconBackground: colorScheme.primary.withValues(alpha: 0.1),
      shadow: colorScheme.shadow,
    );
  }
}
