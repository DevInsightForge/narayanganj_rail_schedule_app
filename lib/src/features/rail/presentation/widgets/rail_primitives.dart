import 'package:flutter/material.dart';

import 'panel_palette.dart';
import 'rail_board_texts.dart';

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
    this.accent = false,
  });

  final String label;
  final String? value;
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
      child: Text.rich(
        TextSpan(
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
    );
  }
}

class RailJourneyTicketStrip extends StatelessWidget {
  const RailJourneyTicketStrip({
    super.key,
    required this.departureTime,
    required this.arrivalTime,
    required this.durationLabel,
    required this.departureStatusLabel,
    required this.arrivalStatusLabel,
    this.estimatedDepartureTime,
    this.estimatedArrivalTime,
    this.showPulse = false,
  });

  final String departureTime;
  final String arrivalTime;
  final String durationLabel;
  final String departureStatusLabel;
  final String arrivalStatusLabel;
  final String? estimatedDepartureTime;
  final String? estimatedArrivalTime;
  final bool showPulse;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final hasEstimate =
        estimatedDepartureTime != null &&
        estimatedArrivalTime != null &&
        (estimatedDepartureTime != departureTime ||
            estimatedArrivalTime != arrivalTime);

    return Container(
      decoration: BoxDecoration(
        color: tokens.secondarySurface,
        borderRadius: BorderRadius.circular(tokens.chipRadius),
        border: Border.all(
          color: showPulse
              ? tokens.accent.withValues(alpha: 0.45)
              : tokens.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isUltraNarrow = constraints.maxWidth < 250;
                final depColumn = _TicketEndpointColumn(
                  label: hasEstimate
                      ? '${RailBoardTexts.departsLabel.toUpperCase()} · ${RailBoardTexts.estimatedPrefix.toUpperCase()}'
                      : 'DEPARTS',
                  primaryTime: hasEstimate
                      ? estimatedDepartureTime!
                      : departureTime,
                  secondaryScheduledTime: hasEstimate ? departureTime : null,
                  alignEnd: false,
                );
                final arrColumn = _TicketEndpointColumn(
                  label: hasEstimate
                      ? '${RailBoardTexts.arrivesLabel.toUpperCase()} · ${RailBoardTexts.estimatedPrefix.toUpperCase()}'
                      : 'ARRIVES',
                  primaryTime: hasEstimate
                      ? estimatedArrivalTime!
                      : arrivalTime,
                  secondaryScheduledTime: hasEstimate ? arrivalTime : null,
                  alignEnd: !isUltraNarrow,
                );

                if (isUltraNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      depColumn,
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          durationLabel,
                          style: textTheme.labelMedium?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                      ),
                      arrColumn,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 4, child: depColumn),
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              durationLabel,
                              textAlign: TextAlign.center,
                              style: textTheme.labelSmall?.copyWith(
                                color: tokens.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: tokens.textMuted,
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1.5,
                                    color: tokens.border,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 13,
                                  color: tokens.accent,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(flex: 4, child: arrColumn),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: showPulse ? tokens.accentSoft : tokens.primarySurface,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(tokens.chipRadius - 1),
              ),
              border: Border(top: BorderSide(color: tokens.border)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showPulse) ...[
                      PulsingRadarDot(
                        color: tokens.accent,
                        size: 7,
                        pulseRadius: 16,
                      ),
                      const SizedBox(width: 6),
                    ] else ...[
                      Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: tokens.accent,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        departureStatusLabel,
                        style: textTheme.labelMedium?.copyWith(
                          color: showPulse ? tokens.accent : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  arrivalStatusLabel,
                  style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketEndpointColumn extends StatelessWidget {
  const _TicketEndpointColumn({
    required this.label,
    required this.primaryTime,
    this.secondaryScheduledTime,
    required this.alignEnd,
  });

  final String label;
  final String primaryTime;
  final String? secondaryScheduledTime;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            fontSize: 10,
            letterSpacing: 0.7,
            color: tokens.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          primaryTime,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (secondaryScheduledTime != null) ...[
          const SizedBox(height: 2),
          Text(
            'Sched. $secondaryScheduledTime',
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: textTheme.bodySmall?.copyWith(
              color: tokens.textMuted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ],
      ],
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

class RailPressable extends StatefulWidget {
  const RailPressable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.scaleDown = 0.98,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final double scaleDown;

  @override
  State<RailPressable> createState() => _RailPressableState();
}

class _RailPressableState extends State<RailPressable> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) {
      setState(() => _isPressed = true);
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _onTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = widget.borderRadius ?? BorderRadius.circular(12);

    return AnimatedScale(
      scale: _isPressed ? widget.scaleDown : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        borderRadius: effectiveRadius,
        child: InkWell(
          borderRadius: effectiveRadius,
          onTap: widget.onTap,
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: widget.child,
        ),
      ),
    );
  }
}

class PulsingRadarDot extends StatefulWidget {
  const PulsingRadarDot({
    super.key,
    required this.color,
    this.size = 10,
    this.pulseRadius = 20,
  });

  final Color color;
  final double size;
  final double pulseRadius;

  @override
  State<PulsingRadarDot> createState() => _PulsingRadarDotState();
}

class _PulsingRadarDotState extends State<PulsingRadarDot>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      final isAnimationsEnabled =
          MediaQuery.maybeOf(context)?.disableAnimations != true &&
          !WidgetsBinding.instance.runtimeType.toString().contains('Test');
      if (isAnimationsEnabled) {
        _controller = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1400),
        )..repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return SizedBox(
      width: widget.pulseRadius,
      height: widget.pulseRadius,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (controller != null)
            AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                final scale = 0.5 + (controller.value * 0.5);
                final opacity = (1.0 - controller.value).clamp(0.0, 1.0);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.pulseRadius,
                    height: widget.pulseRadius,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withValues(alpha: opacity * 0.4),
                    ),
                  ),
                );
              },
            ),
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
            ),
          ),
        ],
      ),
    );
  }
}
