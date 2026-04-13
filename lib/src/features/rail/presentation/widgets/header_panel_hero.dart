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
                          : RailBoardTexts.bestNextTrainSubtitle(
                              from: view.snapshot.selectedStationName,
                              destination: view.snapshot.destinationStationName,
                              etaLabel: RailBoardCopy.getEtaLabel(
                                nextService.etaMinutes,
                              ).toLowerCase(),
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
                detail: nextService == null
                    ? RailBoardTexts.timetableChooseRouteMessage
                    : RailBoardTexts.departureHeroDetail(
                        nextService.trainNo,
                        RailBoardCopy.getWaitLabel(nextService.waitMinutes),
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
                        RailBoardCopy.getWaitLabel(nextService.waitMinutes)
                            .toLowerCase(),
                      ),
                style: textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
              ),
              SizedBox(height: tokens.itemGap),
              _DepartureHero(
                title: nextService == null
                    ? RailBoardTexts.noDepartureLabel
                    : RailBoardCopy.formatTimeAmPm(nextService.departureTime),
                detail: nextService == null
                    ? RailBoardTexts.noTrainAvailableMessage
                    : RailBoardTexts.departureHeroEtaDetail(
                        nextService.trainNo,
                        RailBoardCopy.getEtaLabel(nextService.etaMinutes),
                      ),
              ),
            ],
          );
  }
}

class _DepartureHero extends StatelessWidget {
  const _DepartureHero({required this.title, required this.detail});

  final String title;
  final String detail;

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
          Flexible(
            child: Text(
              detail,
              textAlign: TextAlign.end,
              style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
