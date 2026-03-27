import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/rail_snapshot.dart';
import '../../domain/services/rail_board_service.dart';
import 'panel_palette.dart';
import 'panel_shell.dart';

class UpcomingPanel extends StatelessWidget {
  const UpcomingPanel({super.key, required this.snapshot});

  final RailBoardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final boardService = context.read<RailBoardService>();
    final colorScheme = Theme.of(context).colorScheme;
    final palette = RailPanelPalette.of(colorScheme);
    final alternatives = snapshot.upcomingServices
        .skip(1)
        .toList(growable: false);

    return PanelShell(
      backgroundColor: palette.panelBackground,
      borderColor: palette.panelBorder,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Later departures',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 11, letterSpacing: 1.4),
          ),
          const SizedBox(height: 4),
          Text(
            'Keep these as backup options',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '${alternatives.length} alternatives available',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: palette.panelMutedText,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          if (alternatives.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.panelElevatedSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.panelBorder),
              ),
              child: Text(
                'No later departures are available for the current route selection.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: palette.panelMutedText),
              ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final palette = RailPanelPalette.of(colorScheme);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.panelSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.panelBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 220;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCompact)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            departureLabel,
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            waitLabel,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: palette.panelMutedText,
                                  fontSize: 12,
                                ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              departureLabel,
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              waitLabel,
                              textAlign: TextAlign.end,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: palette.panelMutedText,
                                    fontSize: 12,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '$periodLabel - Arrives $arrivalLabel',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.panelMutedText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      durationLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 12,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
