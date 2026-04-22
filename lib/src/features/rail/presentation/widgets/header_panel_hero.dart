import 'package:flutter/material.dart';

import '../bloc/rail_board_state.dart';
import 'panel_palette.dart';
import 'rail_board_copy.dart';
import 'rail_board_texts.dart';

class HeaderPanelHero extends StatelessWidget {
  const HeaderPanelHero({super.key, required this.view});

  final RailBoardViewState view;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final nextService = view.snapshot.nextService;

    return tokens.isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      RailBoardTexts.appName,
                      style: textTheme.headlineMedium,
                    ),
                    SizedBox(height: tokens.compactGap),
                    Text(
                      nextService == null
                          ? RailBoardTexts.timetableReadyMessage
                          : _routeSubtitle(
                              from: view.snapshot.selectedStationName,
                              destination: view.snapshot.destinationStationName,
                            ),
                      style: textTheme.bodyLarge?.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: tokens.panelGap),
              _DepartureHero(
                title: nextService == null
                    ? RailBoardTexts.noDepartureLabel
                    : RailBoardCopy.formatTimeAmPm(nextService.departureTime),
                detailLineOne: nextService == null
                    ? RailBoardTexts.timetableChooseRouteMessage
                    : RailBoardTexts.departureHeroDetail(nextService.trainNo),
                detailLineTwo: nextService == null
                    ? null
                    : _routeSummary(
                        from: view.snapshot.selectedStationName,
                        destination: view.snapshot.destinationStationName,
                      ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(RailBoardTexts.appName, style: textTheme.headlineMedium),
              SizedBox(height: tokens.compactGap),
              Text(
                nextService == null
                    ? RailBoardTexts.timetableChooseRouteMessage
                    : RailBoardTexts.nextDepartureNarrowMessage(
                        RailBoardCopy.getWaitLabel(
                          nextService.waitMinutes,
                        ).toLowerCase(),
                      ),
                style: textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
              ),
              SizedBox(height: tokens.itemGap),
              _DepartureHero(
                title: nextService == null
                    ? RailBoardTexts.noDepartureLabel
                    : RailBoardCopy.formatTimeAmPm(nextService.departureTime),
                detailLineOne: nextService == null
                    ? RailBoardTexts.noTrainAvailableMessage
                    : RailBoardTexts.departureHeroDetail(nextService.trainNo),
                detailLineTwo: nextService == null
                    ? null
                    : _routeSummary(
                        from: view.snapshot.selectedStationName,
                        destination: view.snapshot.destinationStationName,
                      ),
              ),
            ],
          );
  }

  static String _routeSubtitle({
    required String from,
    required String destination,
  }) {
    return 'Board at $from and travel to $destination.';
  }

  static String _routeSummary({
    required String from,
    required String destination,
  }) {
    return '$from to $destination';
  }
}

class _DepartureHero extends StatelessWidget {
  const _DepartureHero({
    required this.title,
    required this.detailLineOne,
    required this.detailLineTwo,
  });

  final String title;
  final String detailLineOne;
  final String? detailLineTwo;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: tokens.isWide ? 260 : double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: tokens.primarySurface,
        borderRadius: BorderRadius.circular(tokens.heroRadius),
        border: Border.all(color: tokens.border),
      ),
      clipBehavior: Clip.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: tokens.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.schedule_rounded, size: 14, color: tokens.accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  RailBoardTexts.nextDepartureLabel,
                  style: textTheme.labelMedium?.copyWith(
                    color: tokens.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(title, style: textTheme.titleMedium),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    detailLineOne,
                    textAlign: TextAlign.end,
                    softWrap: false,
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                  if (detailLineTwo != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      detailLineTwo!,
                      textAlign: TextAlign.end,
                      softWrap: false,
                      style: textTheme.bodySmall?.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
