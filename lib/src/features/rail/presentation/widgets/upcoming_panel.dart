import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/rail_snapshot.dart';
import '../../domain/services/rail_board_service.dart';
import 'panel_palette.dart';
import 'panel_shell.dart';
import 'rail_primitives.dart';

class UpcomingPanel extends StatelessWidget {
  const UpcomingPanel({super.key, required this.snapshot});

  final RailBoardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final boardService = context.read<RailBoardService>();
    final tokens = RailBoardTokens.of(context);
    final alternatives = snapshot.upcomingServices
        .skip(1)
        .toList(growable: false);

    return PanelShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RailSectionHeader(
            eyebrow: 'Backup options',
            title: 'Later departures',
            subtitle: alternatives.isEmpty
                ? 'No later departure matches the current selection.'
                : '${alternatives.length} more departures are available if you miss the next train.',
          ),
          SizedBox(height: tokens.sectionGap),
          if (alternatives.isEmpty)
            const RailStateMessage(
              title: 'No later departure',
              message:
                  'Change direction or route selection to see more departures.',
              icon: Icons.event_busy_rounded,
            )
          else
            Column(
              children: [
                for (var i = 0; i < alternatives.length; i++) ...[
                  _UpcomingCard(
                    index: i + 1,
                    departureLabel: boardService.formatTimeAmPm(
                      alternatives[i].departureTime,
                    ),
                    arrivalLabel: boardService.formatTimeAmPm(
                      alternatives[i].arrivalTime,
                    ),
                    waitLabel: boardService.getWaitLabel(
                      alternatives[i].waitMinutes,
                    ),
                    durationLabel: boardService.getDurationLabel(
                      alternatives[i].etaMinutes - alternatives[i].waitMinutes,
                    ),
                    periodLabel: boardService.getServicePeriodLabel(
                      alternatives[i].servicePeriod,
                    ),
                  ),
                  if (i < alternatives.length - 1)
                    SizedBox(height: tokens.itemGap),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({
    required this.index,
    required this.departureLabel,
    required this.arrivalLabel,
    required this.waitLabel,
    required this.durationLabel,
    required this.periodLabel,
  });

  final int index;
  final String departureLabel;
  final String arrivalLabel;
  final String waitLabel;
  final String durationLabel;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.secondarySurface,
        borderRadius: BorderRadius.circular(tokens.chipRadius),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tokens.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      departureLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      waitLabel,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$periodLabel - Arrives $arrivalLabel',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  durationLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
