import 'package:flutter/material.dart';

import '../../domain/entities/rail_snapshot.dart';
import 'panel_palette.dart';
import 'panel_shell.dart';
import 'rail_board_copy.dart';
import 'rail_primitives.dart';

class UpcomingPanel extends StatelessWidget {
  const UpcomingPanel({super.key, required this.snapshot});

  final RailBoardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
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
                    departureLabel: RailBoardCopy.formatTimeAmPm(
                      alternatives[i].departureTime,
                    ),
                    arrivalLabel: RailBoardCopy.formatTimeAmPm(
                      alternatives[i].arrivalTime,
                    ),
                    waitLabel: RailBoardCopy.getWaitLabel(
                      alternatives[i].waitMinutes,
                    ),
                    durationLabel: RailBoardCopy.getDurationLabel(
                      alternatives[i].etaMinutes - alternatives[i].waitMinutes,
                    ),
                    periodLabel: RailBoardCopy.getServicePeriodLabel(
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
              color: tokens.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        departureLabel,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    SizedBox(width: tokens.itemGap),
                    Text(
                      arrivalLabel,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '$periodLabel - $waitLabel',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                    ),
                    SizedBox(width: tokens.itemGap),
                    Text(
                      durationLabel,
                      textAlign: TextAlign.end,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: tokens.textMuted),
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
