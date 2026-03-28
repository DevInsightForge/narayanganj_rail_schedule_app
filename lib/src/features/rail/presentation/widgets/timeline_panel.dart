import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../community/domain/entities/predicted_stop_time.dart';
import '../../domain/entities/rail_snapshot.dart';
import '../../domain/services/rail_board_service.dart';
import 'panel_palette.dart';
import 'panel_shell.dart';
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
    final boardService = context.read<RailBoardService>();
    final tokens = RailBoardTokens.of(context);
    final nextService = snapshot.nextService;

    if (nextService == null) {
      return const PanelShell(
        child: RailStateMessage(
          title: 'Journey trace unavailable',
          message:
              'A stop-by-stop trace appears when a matching train is found.',
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
            eyebrow: 'Journey trace',
            title: 'Scheduled and estimated stops',
            subtitle:
                'Track the stop sequence for train ${nextService.trainNo} from boarding to destination.',
            trailing: RailPill(
              label: 'Train',
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
                  scheduledLabel: boardService.formatTimeAmPm(
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
    final boardService = context.read<RailBoardService>();
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
                      ? 'Board here'
                      : isLast
                      ? 'Arrive here'
                      : 'Intermediate stop',
                  style: textTheme.bodyMedium?.copyWith(
                    color: tokens.textMuted,
                  ),
                ),
                if (predicted != null) ...[
                  const SizedBox(height: 4),
                  RailPill(
                    label: 'Estimate',
                    value: boardService.formatTimeAmPm(
                      '${predicted!.predictedAt.hour.toString().padLeft(2, '0')}:${predicted!.predictedAt.minute.toString().padLeft(2, '0')}',
                    ),
                    accent: true,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(scheduledLabel, style: textTheme.labelLarge),
              const SizedBox(height: 1),
              Text(
                'Scheduled',
                style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
