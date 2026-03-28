import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timelines_plus/timelines_plus.dart';

import '../../../community/domain/entities/predicted_stop_time.dart';
import '../../domain/entities/rail_snapshot.dart';
import '../../domain/services/rail_board_service.dart';
import 'panel_palette.dart';
import 'panel_shell.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final palette = RailPanelPalette.of(colorScheme);
    final nextService = snapshot.nextService!;
    final predictedByStation = {
      for (final prediction in predictedStopTimes)
        prediction.stationId: prediction,
    };

    return PanelShell(
      backgroundColor: palette.panelBackground,
      borderColor: palette.panelBorder,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Journey trace',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scheduled and estimated stops',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: palette.panelElevatedSurface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: palette.panelBorder),
                ),
                child: Text(
                  'Train ${nextService.trainNo}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FixedTimeline.tileBuilder(
            theme: TimelineThemeData(
              nodePosition: 0,
              connectorTheme: ConnectorThemeData(
                color: colorScheme.outlineVariant,
                thickness: 2,
              ),
              indicatorTheme: const IndicatorThemeData(position: 0.5, size: 12),
            ),
            builder: TimelineTileBuilder.connected(
              contentsAlign: ContentsAlign.basic,
              connectionDirection: ConnectionDirection.before,
              itemCount: nextService.stops.length,
              indicatorBuilder: (context, index) {
                final isTerminal =
                    index == 0 || index == nextService.stops.length - 1;

                return DotIndicator(
                  size: isTerminal ? 12 : 10,
                  color: isTerminal ? colorScheme.primary : colorScheme.outline,
                );
              },
              connectorBuilder: (context, index, connectorType) {
                return SolidLineConnector(
                  color: colorScheme.outlineVariant,
                  thickness: 2,
                );
              },
              contentsBuilder: (context, index) {
                final stop = nextService.stops[index];
                final isFirst = index == 0;
                final isLast = index == nextService.stops.length - 1;
                final subtitle = isFirst
                    ? 'Board here'
                    : isLast
                    ? 'Arrive here'
                    : 'Intermediate stop';
                final predicted = predictedByStation[stop.stationId];

                return Padding(
                  padding: EdgeInsets.only(left: 14, bottom: isLast ? 0 : 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.panelSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: palette.panelBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stop.stationName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: palette.panelMutedText,
                                      fontSize: 12,
                                    ),
                              ),
                              if (predicted != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'Estimate ${_formatEstimate(boardService, predicted.predictedAt)}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colorScheme.primary,
                                        fontSize: 11,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              boardService.formatTimeAmPm(stop.time),
                              style: Theme.of(
                                context,
                              ).textTheme.labelLarge?.copyWith(fontSize: 13),
                            ),
                            if (predicted != null)
                              Text(
                                'Scheduled',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(fontSize: 10),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatEstimate(RailBoardService boardService, DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return boardService.formatTimeAmPm('$hour:$minute');
  }
}
