import 'package:flutter/material.dart';

import 'panel_palette.dart';

class RailSectionHeader extends StatelessWidget {
  const RailSectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eyebrow != null)
              Text(
                eyebrow!,
                style: textTheme.labelMedium?.copyWith(
                  letterSpacing: 0.8,
                  color: tokens.textMuted,
                ),
              ),
            if (eyebrow != null) SizedBox(height: tokens.compactGap),
            Text(title, style: textTheme.titleLarge),
            if (subtitle != null) SizedBox(height: tokens.compactGap),
            if (subtitle != null)
              Text(
                subtitle!,
                style: textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
              ),
          ],
        );

        if (trailing == null || constraints.maxWidth >= 360) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: heading),
              if (trailing case final trailingWidget?) ...[
                SizedBox(width: tokens.itemGap),
                trailingWidget,
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading,
            SizedBox(height: tokens.itemGap),
            trailing!,
          ],
        );
      },
    );
  }
}

class RailPill extends StatelessWidget {
  const RailPill({
    super.key,
    required this.label,
    this.value,
    this.icon,
    this.accent = false,
  });

  final String label;
  final String? value;
  final IconData? icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: accent ? tokens.accentSoft : tokens.secondarySurface,
        borderRadius: BorderRadius.circular(tokens.chipRadius),
        border: Border.all(
          color: accent ? tokens.accent.withValues(alpha: 0.24) : tokens.border,
        ),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 3,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (icon != null)
            Icon(
              icon,
              size: 14,
              color: accent ? tokens.accent : tokens.textMuted,
            ),
          RichText(
            text: TextSpan(
              style: textTheme.labelMedium?.copyWith(
                color: accent ? tokens.accent : tokens.textMuted,
              ),
              children: [
                TextSpan(text: value == null ? label : '$label  '),
                if (value != null)
                  TextSpan(text: value!, style: textTheme.labelMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RailMetricTile extends StatelessWidget {
  const RailMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    this.icon,
  });

  final String label;
  final String value;
  final String detail;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: tokens.secondarySurface,
        borderRadius: BorderRadius.circular(tokens.chipRadius),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null)
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: tokens.accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 13, color: tokens.accent),
            ),
          if (icon != null) const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: tokens.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: textTheme.titleMedium),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              detail,
              textAlign: TextAlign.end,
              style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class RailStateMessage extends StatelessWidget {
  const RailStateMessage({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.action,
    this.compact = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        compact ? tokens.itemGap : tokens.panelPadding.left,
      ),
      decoration: BoxDecoration(
        color: tokens.secondarySurface,
        borderRadius: BorderRadius.circular(tokens.chipRadius),
        border: Border.all(color: tokens.border),
      ),
      child: compact
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: tokens.accentSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 14, color: tokens.accent),
                ),
                SizedBox(width: tokens.itemGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.labelLarge),
                      SizedBox(height: tokens.compactGap),
                      Text(
                        message,
                        style: textTheme.bodySmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                      if (action case final actionWidget?) ...[
                        SizedBox(height: tokens.itemGap),
                        actionWidget,
                      ],
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: tokens.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 18, color: tokens.accent),
                ),
                const SizedBox(height: 8),
                Text(title, style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: textTheme.bodyMedium?.copyWith(
                    color: tokens.textMuted,
                  ),
                ),
                if (action case final actionWidget?) ...[
                  const SizedBox(height: 10),
                  actionWidget,
                ],
              ],
            ),
    );
  }
}
