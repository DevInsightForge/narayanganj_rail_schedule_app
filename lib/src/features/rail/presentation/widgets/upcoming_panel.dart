import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/rail_snapshot.dart';
import '../bloc/rail_board_cubit.dart';
import 'panel_palette.dart';
import 'panel_shell.dart';
import 'rail_board_copy.dart';
import 'rail_board_texts.dart';
import 'rail_primitives.dart';

class UpcomingPanel extends StatelessWidget {
  const UpcomingPanel({
    super.key,
    required this.snapshot,
    this.previewTrainNo,
    this.boardingStationId,
    this.destinationStationId,
  });

  final RailBoardSnapshot snapshot;
  final int? previewTrainNo;
  final String? boardingStationId;
  final String? destinationStationId;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final nextDepartureTrainNo = snapshot.nextDepartureService?.trainNo;
    final alternatives = snapshot.upcomingServices
        .where(
          (service) =>
              !service.isOverdue && service.trainNo != nextDepartureTrainNo,
        )
        .toList(growable: false);

    return PanelShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RailSectionHeader(
            eyebrow: RailBoardTexts.moreOptionsEyebrow,
            title: RailBoardTexts.laterDeparturesTitle,
            subtitle: RailBoardTexts.laterDeparturesSubtitle(
              alternatives.length,
            ),
          ),
          SizedBox(height: tokens.sectionGap),
          if (alternatives.isEmpty)
            const RailStateMessage(
              title: RailBoardTexts.noMoreDeparturesTitle,
              message: RailBoardTexts.noMoreDeparturesMessage,
              icon: Icons.event_busy_rounded,
            )
          else
            Column(
              children: [
                for (var i = 0; i < alternatives.length; i++) ...[
                  _UpcomingCard(
                    trainNo: alternatives[i].trainNo,
                    isSelected: alternatives[i].trainNo == previewTrainNo,
                    onTap: () {
                      final cubit = context.read<RailBoardCubit>();
                      if (alternatives[i].trainNo == previewTrainNo) {
                        cubit.previewService(null);
                      } else {
                        cubit.previewService(alternatives[i].trainNo);
                      }
                    },
                    departureLabel: RailBoardCopy.formatTimeAmPm(
                      alternatives[i].departureTime,
                    ),
                    arrivalLabel: RailBoardCopy.formatTimeAmPm(
                      alternatives[i].arrivalTime,
                    ),
                    waitLabel: alternatives[i].isOverdue
                        ? RailBoardCopy.getOverdueDepartureDetail(
                            overdueMinutes: alternatives[i].overdueMinutes,
                          )
                        : RailBoardCopy.getWaitLabel(
                            alternatives[i].waitMinutes,
                          ),
                    durationLabel: RailBoardCopy.getDurationLabel(
                      alternatives[i].etaMinutes - alternatives[i].waitMinutes,
                    ),
                    periodLabel: RailBoardCopy.getServicePeriodLabel(
                      alternatives[i].servicePeriod,
                    ),
                    stops: alternatives[i].stops,
                    boardingStationId: boardingStationId,
                    destinationStationId: destinationStationId,
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
    required this.trainNo,
    required this.isSelected,
    required this.onTap,
    required this.departureLabel,
    required this.arrivalLabel,
    required this.waitLabel,
    required this.durationLabel,
    required this.periodLabel,
    required this.stops,
    this.boardingStationId,
    this.destinationStationId,
  });

  final int trainNo;
  final bool isSelected;
  final VoidCallback onTap;
  final String departureLabel;
  final String arrivalLabel;
  final String waitLabel;
  final String durationLabel;
  final String periodLabel;
  final List<RailStopSnapshot> stops;
  final String? boardingStationId;
  final String? destinationStationId;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final theme = Theme.of(context);

    final rawBoardingIndex = boardingStationId != null
        ? stops.indexWhere((stop) => stop.stationId == boardingStationId)
        : -1;
    final boardingIndex = rawBoardingIndex >= 0 ? rawBoardingIndex : 0;

    final rawDestIndex = destinationStationId != null
        ? stops.indexWhere((stop) => stop.stationId == destinationStationId)
        : -1;
    final destIndex = rawDestIndex >= 0 ? rawDestIndex : stops.length - 1;

    final relevantStops = stops.sublist(
      boardingIndex,
      destIndex >= boardingIndex ? destIndex + 1 : stops.length,
    );

    return RailPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.chipRadius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? tokens.accentSoft : tokens.secondarySurface,
          borderRadius: BorderRadius.circular(tokens.chipRadius),
          border: Border.all(
            color: isSelected ? tokens.accent : tokens.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? tokens.accent : tokens.primarySurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? tokens.accent : tokens.border,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '#$trainNo',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSelected ? theme.colorScheme.onPrimary : null,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Text(
                            departureLabel,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: isSelected ? FontWeight.w700 : null,
                            ),
                          ),
                          Text(
                            '→',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: tokens.textMuted,
                            ),
                          ),
                          Text(
                            arrivalLabel,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: isSelected ? FontWeight.w700 : null,
                            ),
                          ),
                          Text(
                            '($durationLabel)',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: tokens.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$periodLabel • $waitLabel',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isSelected
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: isSelected ? tokens.accent : tokens.textMuted,
                ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(height: 8),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tokens.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.border),
                  ),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final stop in relevantStops)
                        Text(
                          '${stop.stationName} ${RailBoardCopy.formatTimeAmPm(stop.time)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.textMuted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
