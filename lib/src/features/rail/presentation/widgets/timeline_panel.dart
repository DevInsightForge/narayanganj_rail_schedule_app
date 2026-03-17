import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:timelines_plus/timelines_plus.dart';

import '../../domain/entities/rail_snapshot.dart';
import '../../domain/services/rail_board_service.dart';
import 'panel_shell.dart';

class TimelinePanel extends StatelessWidget {
  const TimelinePanel({super.key, required this.snapshot});

  final RailBoardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final boardService = context.read<RailBoardService>();
    final nextService = snapshot.nextService!;

    return PanelShell(
      backgroundColor: const Color(0xFFF8F8F8),
      borderColor: const Color(0x14171717),
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
                      'Your stop-by-stop trip',
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
                  color: const Color(0xFFF1F1F1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x12171717)),
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
              connectorTheme: const ConnectorThemeData(
                color: Color(0xFFD5D5D5),
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
                  color: isTerminal
                      ? const Color(0xFF171717)
                      : const Color(0xFFB8B8B8),
                );
              },
              connectorBuilder: (context, index, connectorType) {
                return const SolidLineConnector(
                  color: Color(0xFFD5D5D5),
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

                return Padding(
                  padding: EdgeInsets.only(left: 14, bottom: isLast ? 0 : 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0x12171717)),
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
                                      color: const Color(0xFF5E5E5E),
                                      fontSize: 12,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          boardService.formatTimeAmPm(stop.time),
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(fontSize: 13),
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
}
