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
                  letterSpacing: 1.2,
                  color: tokens.textMuted,
                ),
              ),
            if (eyebrow != null) SizedBox(height: tokens.compactGap),
            Text(title, style: textTheme.headlineSmall),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent ? tokens.accentSoft : tokens.secondarySurface,
        borderRadius: BorderRadius.circular(tokens.chipRadius),
        border: Border.all(
          color: accent ? tokens.accent.withValues(alpha: 0.24) : tokens.border,
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (icon != null)
            Icon(
              icon,
              size: 16,
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
                  TextSpan(text: value!, style: textTheme.labelLarge),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.secondarySurface,
        borderRadius: BorderRadius.circular(tokens.chipRadius),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) Icon(icon, size: 16, color: tokens.textMuted),
              if (icon != null) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.labelMedium?.copyWith(
                    color: tokens.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            detail,
            style: textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
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
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(tokens.panelPadding.left),
      decoration: BoxDecoration(
        color: tokens.secondarySurface,
        borderRadius: BorderRadius.circular(tokens.chipRadius),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tokens.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: tokens.accent),
          ),
          const SizedBox(height: 12),
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
          ),
          if (action case final actionWidget?) ...[
            const SizedBox(height: 16),
            actionWidget,
          ],
        ],
      ),
    );
  }
}
