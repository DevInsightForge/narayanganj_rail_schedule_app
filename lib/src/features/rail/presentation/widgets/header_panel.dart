import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/rail_snapshot.dart';
import '../bloc/rail_board_bloc.dart';
import 'panel_palette.dart';
import 'panel_shell.dart';

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
                        style: textTheme.headlineMedium,
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
                SizedBox(height: tokens.itemGap),
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
            scrollable: false,
            onPressed: (value) => context.read<RailBoardBloc>().add(
              RailBoardDirectionChanged(value),
            ),
          ),
          SizedBox(height: tokens.itemGap),
          _SelectionStrip(
            label: 'Boarding',
            options: view.boardingStations,
            value: view.selection.boardingStationId,
            scrollable: true,
            onPressed: (value) => context.read<RailBoardBloc>().add(
              RailBoardBoardingChanged(value),
            ),
          ),
          SizedBox(height: tokens.itemGap),
          _SelectionStrip(
            label: 'Destination',
            options: view.destinationStations,
            value: view.selection.destinationStationId,
            scrollable: true,
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

class _SelectionStrip extends StatelessWidget {
  const _SelectionStrip({
    required this.label,
    required this.options,
    required this.value,
    required this.scrollable,
    required this.onPressed,
  });

  final String label;
  final List<RailSelectableOption> options;
  final String value;
  final bool scrollable;
  final ValueChanged<String> onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        SizedBox(height: tokens.compactGap),
        if (scrollable)
          _ScrollableSelectionRow(
            options: options,
            value: value,
            onPressed: onPressed,
          )
        else
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

class _ScrollableSelectionRow extends StatefulWidget {
  const _ScrollableSelectionRow({
    required this.options,
    required this.value,
    required this.onPressed,
  });

  final List<RailSelectableOption> options;
  final String value;
  final ValueChanged<String> onPressed;

  @override
  State<_ScrollableSelectionRow> createState() =>
      _ScrollableSelectionRowState();
}

class _ScrollableSelectionRowState extends State<_ScrollableSelectionRow> {
  final ScrollController _controller = ScrollController();
  bool _showLeading = false;
  bool _showTrailing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncIndicators);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIndicators());
  }

  @override
  void didUpdateWidget(covariant _ScrollableSelectionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncIndicators());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_syncIndicators)
      ..dispose();
    super.dispose();
  }

  void _syncIndicators() {
    if (!_controller.hasClients) {
      return;
    }
    final position = _controller.position;
    final showLeading = position.pixels > 2;
    final showTrailing = position.pixels < position.maxScrollExtent - 2;
    if (showLeading == _showLeading && showTrailing == _showTrailing) {
      return;
    }
    setState(() {
      _showLeading = showLeading;
      _showTrailing = showTrailing;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    return Stack(
      children: [
        SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < widget.options.length; i++) ...[
                _SelectionChip(
                  label: widget.options[i].label,
                  selected: widget.options[i].value == widget.value,
                  disabled: widget.options[i].disabled,
                  onPressed: widget.options[i].disabled
                      ? null
                      : () => widget.onPressed(widget.options[i].value),
                ),
                if (i < widget.options.length - 1)
                  SizedBox(width: tokens.compactGap),
              ],
            ],
          ),
        ),
        if (_showLeading)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: _ScrollIndicator(
                alignment: Alignment.centerLeft,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                icon: Icons.chevron_left_rounded,
              ),
            ),
          ),
        if (_showTrailing)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: _ScrollIndicator(
                alignment: Alignment.centerRight,
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                icon: Icons.chevron_right_rounded,
              ),
            ),
          ),
      ],
    );
  }
}

class _ScrollIndicator extends StatelessWidget {
  const _ScrollIndicator({
    required this.alignment,
    required this.begin,
    required this.end,
    required this.icon,
  });

  final Alignment alignment;
  final Alignment begin;
  final Alignment end;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    return Container(
      width: 28,
      alignment: alignment,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          colors: [
            tokens.accentSurface,
            tokens.accentSurface.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Icon(icon, size: 16, color: tokens.textMuted),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          foregroundColor: selected
              ? (isDark ? const Color(0xFF171717) : Colors.white)
              : null,
          backgroundColor: selected ? tokens.accent : tokens.primarySurface,
          side: BorderSide(color: selected ? tokens.accent : tokens.border),
          textStyle: Theme.of(context).textTheme.labelMedium,
          minimumSize: const Size(0, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.chipRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(label),
      ),
    );
  }
}
