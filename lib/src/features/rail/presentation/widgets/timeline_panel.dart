import 'package:flutter/material.dart';

import '../../../community/domain/entities/predicted_stop_time.dart';
import '../../domain/entities/rail_snapshot.dart';
import 'panel_palette.dart';
import 'panel_shell.dart';
import 'rail_board_copy.dart';
import 'rail_board_texts.dart';
import 'rail_primitives.dart';

class TimelinePanel extends StatelessWidget {
  const TimelinePanel({
    super.key,
    required this.snapshot,
    required this.predictedStopTimes,
  });

  final RailBoardSnapshot snapshot;
  final List<PredictedStopTime> predictedStopTimes;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final nextService = snapshot.nextService;

    if (nextService == null) {
      return const PanelShell(
        child: RailStateMessage(
          title: RailBoardTexts.stopByStopUnavailableTitle,
          message: RailBoardTexts.stopByStopUnavailableMessage,
          icon: Icons.timeline_rounded,
        ),
      );
    }

    final predictedByStation = {
      for (final prediction in predictedStopTimes)
        prediction.stationId: prediction,
    };

    final hasPassedStops = predictedByStation.values.any((p) => p.isPassed);
    final firstApproachingIndex = hasPassedStops
        ? nextService.stops.indexWhere(
            (stop) => predictedByStation[stop.stationId]?.isPassed != true,
          )
        : -1;

    return PanelShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RailSectionHeader(
            eyebrow: RailBoardTexts.routeStopsEyebrow,
            title: RailBoardTexts.scheduledStopsTitle,
            subtitle: RailBoardTexts.routeStopsSubtitle(nextService.trainNo),
            trailing: RailPill(
              label: RailBoardTexts.trainLabel,
              value: '${nextService.trainNo}',
              accent: true,
            ),
          ),
          SizedBox(height: tokens.sectionGap),
          Column(
            children: [
              for (var i = 0; i < nextService.stops.length; i++) ...[
                _StopCard(
                  stop: nextService.stops[i],
                  scheduledLabel: RailBoardCopy.formatTimeAmPm(
                    nextService.stops[i].time,
                  ),
                  predicted: predictedByStation[nextService.stops[i].stationId],
                  isFirst: i == 0,
                  isLast: i == nextService.stops.length - 1,
                  isApproaching: i == firstApproachingIndex,
                ),
                if (i < nextService.stops.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Expanded(
                          child: Divider(color: tokens.border, height: 1),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.stop,
    required this.scheduledLabel,
    required this.predicted,
    required this.isFirst,
    required this.isLast,
    this.isApproaching = false,
  });

  final RailStopSnapshot stop;
  final String scheduledLabel;
  final PredictedStopTime? predicted;
  final bool isFirst;
  final bool isLast;
  final bool isApproaching;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isPassed = predicted?.isPassed == true;

    final cardBorder = isApproaching
        ? Border.all(color: tokens.accent.withValues(alpha: 0.6), width: 1.5)
        : Border.all(color: tokens.border);

    final cardColor = isApproaching
        ? tokens.accentSoft
        : isPassed
        ? tokens.secondarySurface.withValues(alpha: 0.5)
        : tokens.secondarySurface;

    final iconData = isPassed
        ? Icons.check_circle_outline_rounded
        : isApproaching
        ? Icons.navigation_rounded
        : isFirst
        ? Icons.login_rounded
        : isLast
        ? Icons.flag_rounded
        : Icons.more_horiz_rounded;

    final iconColor = isPassed ? tokens.textMuted : tokens.accent;

    final subtitleText = isPassed
        ? RailBoardTexts.departedHere
        : isFirst
        ? RailBoardTexts.boardHere
        : isApproaching
        ? RailBoardTexts.nextStopHere
        : isLast
        ? RailBoardTexts.arriveHere
        : RailBoardTexts.alongRoute;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(tokens.chipRadius),
        border: cardBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isApproaching || isFirst || isLast
                  ? tokens.accentSoft
                  : tokens.primarySurface,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(iconData, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.stationName,
                  style: textTheme.labelLarge?.copyWith(
                    color: isPassed ? tokens.textMuted : null,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitleText,
                  style: textTheme.bodyMedium?.copyWith(
                    color: isApproaching ? tokens.accent : tokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text.rich(
                TextSpan(
                  style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                  children: [
                    const TextSpan(text: '${RailBoardTexts.plannedLabel} '),
                    TextSpan(text: scheduledLabel, style: textTheme.labelLarge),
                  ],
                ),
                textAlign: TextAlign.end,
              ),
              if (predicted != null) ...[
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    style: textTheme.bodySmall?.copyWith(color: tokens.accent),
                    children: [
                      const TextSpan(
                        text: '${RailBoardTexts.liveEstimateLabel} ',
                      ),
                      TextSpan(
                        text: RailBoardCopy.formatTimeAmPm(
                          '${predicted!.predictedAt.hour.toString().padLeft(2, '0')}:${predicted!.predictedAt.minute.toString().padLeft(2, '0')}',
                        ),
                        style: textTheme.labelLarge?.copyWith(
                          color: tokens.accent,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.end,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
