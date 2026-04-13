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
  });

  final RailStopSnapshot stop;
  final String scheduledLabel;
  final PredictedStopTime? predicted;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.secondarySurface,
        borderRadius: BorderRadius.circular(tokens.chipRadius),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isFirst || isLast
                  ? tokens.accentSoft
                  : tokens.primarySurface,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(
              isFirst
                  ? Icons.login_rounded
                  : isLast
                  ? Icons.flag_rounded
                  : Icons.more_horiz_rounded,
              size: 14,
              color: tokens.accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stop.stationName, style: textTheme.labelLarge),
                const SizedBox(height: 1),
                Text(
                  isFirst
                      ? RailBoardTexts.boardHere
                      : isLast
                      ? RailBoardTexts.arriveHere
                      : RailBoardTexts.alongRoute,
                  style: textTheme.bodyMedium?.copyWith(
                    color: tokens.textMuted,
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
