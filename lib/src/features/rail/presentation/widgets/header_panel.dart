import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/rail_snapshot.dart';
import '../bloc/rail_board_bloc.dart';
import 'panel_palette.dart';
import 'panel_shell.dart';
import 'rail_primitives.dart';

class HeaderPanel extends StatelessWidget {
  const HeaderPanel({super.key, required this.view});

  final RailBoardViewState view;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final nextService = view.snapshot.nextService;
    final boardService = context.read<RailBoardBloc>().boardService;

    return PanelShell(
      surface: RailPanelSurface.accent,
      padding: tokens.panelPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: tokens.compactGap,
            runSpacing: tokens.compactGap,
            children: [
              RailPill(
                label: 'Dhaka time',
                value: view.snapshot.currentTime.isEmpty
                    ? 'Unavailable'
                    : view.snapshot.currentTime,
                icon: Icons.schedule_rounded,
                accent: true,
              ),
              RailPill(
                label: 'Schedule',
                value: view.snapshot.dataSourceLabel,
                icon: Icons.storage_rounded,
                accent: true,
              ),
            ],
          ),
          SizedBox(height: tokens.sectionGap),
          if (tokens.isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Narayanganj Commuter',
                        style: textTheme.displaySmall,
                      ),
                      SizedBox(height: tokens.compactGap),
                      Text(
                        nextService == null
                            ? 'Your schedule-first rail board is ready. Pick a direction to see the best departure, stop trace, and backup options.'
                            : 'Next departure leaves ${boardService.getWaitLabel(nextService.waitMinutes).toLowerCase()} and reaches ${view.snapshot.destinationStationName} in ${boardService.getEtaLabel(nextService.etaMinutes).toLowerCase()}.',
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
                      : boardService.formatTimeAmPm(nextService.departureTime),
                  detail: nextService == null
                      ? 'Try another route selection'
                      : 'Train ${nextService.trainNo} - ${boardService.getWaitLabel(nextService.waitMinutes)}',
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Narayanganj Commuter', style: textTheme.headlineMedium),
                SizedBox(height: tokens.compactGap),
                Text(
                  nextService == null
                      ? 'Choose your route to get the next commuter option and later departures.'
                      : 'Next departure leaves ${boardService.getWaitLabel(nextService.waitMinutes).toLowerCase()}.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: tokens.textMuted,
                  ),
                ),
                SizedBox(height: tokens.sectionGap),
                _DepartureHero(
                  title: nextService == null
                      ? 'No departure'
                      : boardService.formatTimeAmPm(nextService.departureTime),
                  detail: nextService == null
                      ? 'No train available right now'
                      : 'Train ${nextService.trainNo} - ${boardService.getEtaLabel(nextService.etaMinutes)} total',
                ),
              ],
            ),
          SizedBox(height: tokens.sectionGap),
          _SelectionStrip(
            label: 'Direction',
            options: view.directionOptions,
            value: view.selection.direction,
            onPressed: (value) => context.read<RailBoardBloc>().add(
              RailBoardDirectionChanged(value),
            ),
          ),
          SizedBox(height: tokens.itemGap),
          _SelectionStrip(
            label: 'Boarding',
            options: view.boardingStations,
            value: view.selection.boardingStationId,
            onPressed: (value) => context.read<RailBoardBloc>().add(
              RailBoardBoardingChanged(value),
            ),
          ),
          SizedBox(height: tokens.itemGap),
          _SelectionStrip(
            label: 'Destination',
            options: view.destinationStations,
            value: view.selection.destinationStationId,
            onPressed: (value) => context.read<RailBoardBloc>().add(
              RailBoardDestinationChanged(value),
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tokens.primarySurface,
        borderRadius: BorderRadius.circular(tokens.heroRadius),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next departure',
            style: textTheme.labelMedium?.copyWith(color: tokens.textMuted),
          ),
          const SizedBox(height: 10),
          Text(title, style: textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            detail,
            style: textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
          ),
        ],
      ),
    );
  }
}

class _SelectionStrip extends StatelessWidget {
  const _SelectionStrip({
    required this.label,
    required this.options,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final List<RailSelectableOption> options;
  final String value;
  final ValueChanged<String> onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        SizedBox(height: tokens.compactGap),
        Wrap(
          spacing: tokens.compactGap,
          runSpacing: tokens.compactGap,
          children: options
              .map(
                (option) => _SelectionChip(
                  label: option.label,
                  selected: option.value == value,
                  disabled: option.disabled,
                  onPressed: option.disabled
                      ? null
                      : () => onPressed(option.value),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _SelectionChip extends StatelessWidget {
  const _SelectionChip({
    required this.label,
    required this.selected,
    required this.disabled,
    this.onPressed,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          foregroundColor: selected ? Colors.white : null,
          backgroundColor: selected ? tokens.accent : tokens.primarySurface,
          side: BorderSide(color: selected ? tokens.accent : tokens.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.chipRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
        child: Text(label),
      ),
    );
  }
}
