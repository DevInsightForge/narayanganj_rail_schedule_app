import 'package:flutter/material.dart';

import '../bloc/rail_board_state.dart';
import 'panel_palette.dart';
import 'rail_board_copy.dart';

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
                      'Narayanganj Commuter',
                      style: textTheme.headlineMedium,
                    ),
                    SizedBox(height: tokens.compactGap),
                    Text(
                      nextService == null
                          ? 'Your schedule-first rail board is ready. Pick a direction to see the best departure, stop trace, and backup options.'
                          : 'Next departure leaves ${RailBoardCopy.getWaitLabel(nextService.waitMinutes).toLowerCase()} and reaches ${view.snapshot.destinationStationName} in ${RailBoardCopy.getEtaLabel(nextService.etaMinutes).toLowerCase()}.',
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
                    ? 'No departure'
                    : RailBoardCopy.formatTimeAmPm(nextService.departureTime),
                detail: nextService == null
                    ? 'Try another route selection'
                    : 'Train ${nextService.trainNo} - ${RailBoardCopy.getWaitLabel(nextService.waitMinutes)}',
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Narayanganj Commuter', style: textTheme.headlineMedium),
              SizedBox(height: tokens.compactGap),
              Text(
                nextService == null
                    ? 'Choose your route to get the next commuter option and later departures.'
                    : 'Next departure leaves ${RailBoardCopy.getWaitLabel(nextService.waitMinutes).toLowerCase()}.',
                style: textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
              ),
              SizedBox(height: tokens.itemGap),
              _DepartureHero(
                title: nextService == null
                    ? 'No departure'
                    : RailBoardCopy.formatTimeAmPm(nextService.departureTime),
                detail: nextService == null
                    ? 'No train available right now'
                    : 'Train ${nextService.trainNo} - ${RailBoardCopy.getEtaLabel(nextService.etaMinutes)} total',
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
                  'Next departure',
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
