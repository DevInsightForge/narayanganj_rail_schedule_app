import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/rail_snapshot.dart';
import '../../domain/services/rail_board_service.dart';
import 'panel_shell.dart';

class UpcomingPanel extends StatelessWidget {
  const UpcomingPanel({super.key, required this.snapshot});

  final RailBoardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final boardService = context.read<RailBoardService>();
    final alternatives = snapshot.upcomingServices
        .skip(1)
        .toList(growable: false);

    return PanelShell(
      backgroundColor: const Color(0xD1F7F7F7),
      borderColor: const Color(0x14171717),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 520;

              return isWide
                  ? Row(
                      children: [
                        const Expanded(child: _Heading()),
                        Text(
                          '${alternatives.length} alternatives available',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFF5E5E5E)),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Heading(),
                        const SizedBox(height: 6),
                        Text(
                          '${alternatives.length} alternatives available',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: const Color(0xFF5E5E5E)),
                        ),
                      ],
                    );
            },
          ),
          const SizedBox(height: 12),
          if (alternatives.isEmpty)
            Text(
              'No later departures are available for the current route selection.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5E5E5E)),
            )
          else
            Column(
              children: List.generate(
                alternatives.length,
                (index) => Padding(
                  padding: EdgeInsets.only(
                    bottom: index == alternatives.length - 1 ? 0 : 8,
                  ),
                  child: _AlternativeRow(
                    index: index + 1,
                    departureLabel: boardService.formatTimeAmPm(
                      alternatives[index].departureTime,
                    ),
                    arrivalLabel: boardService.formatTimeAmPm(
                      alternatives[index].arrivalTime,
                    ),
                    waitLabel: boardService.getWaitLabel(
                      alternatives[index].waitMinutes,
                    ),
                    periodLabel: boardService.getServicePeriodLabel(
                      alternatives[index].servicePeriod,
                    ),
                    durationLabel: boardService.getDurationLabel(
                      alternatives[index].etaMinutes -
                          alternatives[index].waitMinutes,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Backup options',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xFF5E5E5E),
            fontSize: 11,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Later trains in the same direction',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _AlternativeRow extends StatelessWidget {
  const _AlternativeRow({
    required this.index,
    required this.departureLabel,
    required this.arrivalLabel,
    required this.waitLabel,
    required this.periodLabel,
    required this.durationLabel,
  });

  final int index;
  final String departureLabel;
  final String arrivalLabel;
  final String waitLabel;
  final String periodLabel;
  final String durationLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x85FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14171717)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Color(0xFFE0E0E0),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        departureLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      waitLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5E5E5E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        periodLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5E5E5E),
                        ),
                      ),
                    ),
                    Text(
                      'Arrives $arrivalLabel - $durationLabel',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5E5E5E),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
