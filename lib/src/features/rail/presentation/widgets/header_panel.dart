import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/rail_snapshot.dart';
import '../../domain/services/rail_board_service.dart';
import '../bloc/rail_board_bloc.dart';
import 'panel_shell.dart';

class HeaderPanel extends StatelessWidget {
  const HeaderPanel({super.key, required this.state});

  final RailBoardState state;

  @override
  Widget build(BuildContext context) {
    final boardService = context.read<RailBoardService>();
    final nextService = state.snapshot.nextService;

    return PanelShell(
      backgroundColor: const Color(0xFF171717),
      borderColor: const Color(0x29171717),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;

              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(child: _HeaderTitle()),
                        const SizedBox(width: 16),
                        _TimeBadge(
                          departureLabel: nextService == null
                              ? 'No train'
                              : boardService.formatTimeAmPm(
                                  nextService.departureTime,
                                ),
                          waitLabel: nextService == null
                              ? 'No departure for this selection'
                              : boardService.getWaitLabel(
                                  nextService.waitMinutes,
                                ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _HeaderTitle(),
                        const SizedBox(height: 12),
                        _TimeBadge(
                          departureLabel: nextService == null
                              ? 'No train'
                              : boardService.formatTimeAmPm(
                                  nextService.departureTime,
                                ),
                          waitLabel: nextService == null
                              ? 'No departure for this selection'
                              : boardService.getWaitLabel(
                                  nextService.waitMinutes,
                                ),
                        ),
                      ],
                    );
            },
          ),
          const SizedBox(height: 16),
          _SelectionStrip(
            label: 'Direction',
            options: state.directionOptions,
            value: state.selection.direction,
            onPressed: (value) {
              context.read<RailBoardBloc>().add(
                RailBoardDirectionChanged(value),
              );
            },
          ),
          const SizedBox(height: 12),
          _SelectionStrip(
            label: 'Boarding station',
            options: state.boardingStations,
            value: state.selection.boardingStationId,
            onPressed: (value) {
              context.read<RailBoardBloc>().add(
                RailBoardBoardingChanged(value),
              );
            },
          ),
          const SizedBox(height: 12),
          _SelectionStrip(
            label: 'Destination station',
            options: state.destinationStations,
            value: state.selection.destinationStationId,
            onPressed: (value) {
              context.read<RailBoardBloc>().add(
                RailBoardDestinationChanged(value),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Live commuter board',
            style: textTheme.labelLarge?.copyWith(
              color: const Color(0x8FF5F5F5),
              fontSize: 11,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Narayanganj Rail Schedule',
            style: textTheme.displayMedium?.copyWith(
              color: const Color(0xFFF5F5F5),
              fontSize: 36,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeBadge extends StatelessWidget {
  const _TimeBadge({required this.departureLabel, required this.waitLabel});

  final String departureLabel;
  final String waitLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 220),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x14F5F5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x2EF5F5F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next scheduled train',
            style: textTheme.bodySmall?.copyWith(
              color: const Color(0xA3F5F5F5),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            departureLabel,
            style: textTheme.headlineMedium?.copyWith(
              color: const Color(0xFFF5F5F5),
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            waitLabel,
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xB3F5F5F5),
              fontSize: 13,
            ),
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
    final labelWidget = Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: const Color(0xADF5F5F5),
        fontSize: 12,
      ),
    );

    final optionsWidget = Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0x0AF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1AF5F5F5)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
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
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;

        return isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 176,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: labelWidget,
                    ),
                  ),
                  Expanded(child: optionsWidget),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  labelWidget,
                  const SizedBox(height: 8),
                  optionsWidget,
                ],
              );
      },
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
    return Material(
      color: selected ? const Color(0xFFE0E0E0) : const Color(0x08F5F5F5),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : disabled
                  ? const Color(0x14F5F5F5)
                  : const Color(0x1FF5F5F5),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: disabled
                  ? const Color(0x59F5F5F5)
                  : selected
                  ? const Color(0xFF171717)
                  : const Color(0xFFF5F5F5),
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
