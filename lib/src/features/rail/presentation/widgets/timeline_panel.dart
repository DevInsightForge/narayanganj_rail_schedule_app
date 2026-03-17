import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
      backgroundColor: const Color(0xD1F7F7F7),
      borderColor: const Color(0x14171717),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Journey trace',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF5E5E5E),
              fontSize: 11,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Station-by-station timeline',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x66E0E0E0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x14171717)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active service',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5E5E5E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Train ${nextService.trainNo}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${nextService.stops.length} stops',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5E5E5E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: List.generate(
              nextService.stops.length,
              (index) => _StopRow(
                stop: nextService.stops[index],
                isFirst: index == 0,
                isLast: index == nextService.stops.length - 1,
                timeLabel: boardService.formatTimeAmPm(
                  nextService.stops[index].time,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.isFirst,
    required this.isLast,
    required this.timeLabel,
  });

  final RailStopSnapshot stop;
  final bool isFirst;
  final bool isLast;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!isFirst)
                  Positioned(
                    top: 0,
                    child: Container(
                      width: 2,
                      height: 23,
                      color: const Color(0xFFD3D3D3),
                    ),
                  ),
                if (!isLast)
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: 2,
                      height: 23,
                      color: const Color(0xFFD3D3D3),
                    ),
                  ),
                Container(
                  width: isFirst || isLast ? 12 : 10,
                  height: isFirst || isLast ? 12 : 10,
                  decoration: BoxDecoration(
                    color: isFirst || isLast
                        ? const Color(0xFF171717)
                        : const Color(0xFFB8B8B8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF7F7F7),
                      width: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.stationName,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  isFirst
                      ? 'Board here'
                      : isLast
                      ? 'Arrive here'
                      : 'Intermediate stop',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5E5E5E),
                  ),
                ),
              ],
            ),
          ),
          Text(timeLabel, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
