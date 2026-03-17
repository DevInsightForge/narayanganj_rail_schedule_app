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
    final mediaQuery = MediaQuery.of(context);
    final isTablet = mediaQuery.size.width >= 720;

    return PanelShell(
      backgroundColor: const Color(0xFF171717),
      borderColor: const Color(0x2E171717),
      padding: EdgeInsets.fromLTRB(
        10,
        isTablet ? 12 : 8,
        10,
        isTablet ? 10 : 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isTablet)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _HeroCopy(
                    currentTime: state.snapshot.currentTime,
                    nextServiceLabel: nextService == null
                        ? 'No train right now'
                        : boardService.formatTimeAmPm(
                            nextService.departureTime,
                          ),
                    waitLabel: nextService == null
                        ? 'No departure for this route'
                        : boardService.getWaitLabel(nextService.waitMinutes),
                    compact: false,
                  ),
                ),
                const SizedBox(width: 14),
                _PrimaryBadge(
                  departureLabel: nextService == null
                      ? 'No train'
                      : boardService.formatTimeAmPm(nextService.departureTime),
                  waitLabel: nextService == null
                      ? 'Unavailable'
                      : boardService.getWaitLabel(nextService.waitMinutes),
                  compact: false,
                ),
              ],
            )
          else
            _CompactHeader(
              currentTime: state.snapshot.currentTime,
              departureLabel: nextService == null
                  ? 'No train'
                  : boardService.formatTimeAmPm(nextService.departureTime),
              waitLabel: nextService == null
                  ? 'Unavailable'
                  : boardService.getWaitLabel(nextService.waitMinutes),
            ),
          SizedBox(height: isTablet ? 14 : 10),
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
          SizedBox(height: isTablet ? 10 : 8),
          _SelectionStrip(
            label: 'Boarding',
            options: state.boardingStations,
            value: state.selection.boardingStationId,
            onPressed: (value) {
              context.read<RailBoardBloc>().add(
                RailBoardBoardingChanged(value),
              );
            },
          ),
          SizedBox(height: isTablet ? 10 : 8),
          _SelectionStrip(
            label: 'Destination',
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

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.currentTime,
    required this.nextServiceLabel,
    required this.waitLabel,
    required this.compact,
  });

  final String currentTime;
  final String nextServiceLabel;
  final String waitLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InfoPill(
              label: 'Live commuter board',
              value: currentTime.isEmpty ? 'Dhaka time' : currentTime,
            ),
            const _InfoPill(label: 'Service', value: 'Narayanganj line'),
          ],
        ),
        SizedBox(height: compact ? 10 : 14),
        Text(
          'Narayanganj Rail',
          style: textTheme.displayMedium?.copyWith(
            color: const Color(0xFFF7F7F7),
            fontSize: compact ? 22 : 28,
          ),
        ),
        if (!compact)
          Text(
            'Plan your next commuter trip without digging through the full timetable.',
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xB8F5F5F5),
              fontSize: 13,
            ),
          ),
        SizedBox(height: compact ? 0 : 12),
        if (!compact)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x0DF5F5F5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x1AF5F5F5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0x14F5F5F5),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.train_rounded,
                    color: Color(0xFFF5F5F5),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nextServiceLabel,
                        style: textTheme.titleLarge?.copyWith(
                          color: const Color(0xFFF5F5F5),
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        waitLabel,
                        style: textTheme.bodyMedium?.copyWith(
                          color: const Color(0xB8F5F5F5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PrimaryBadge extends StatelessWidget {
  const _PrimaryBadge({
    required this.departureLabel,
    required this.waitLabel,
    required this.compact,
  });

  final String departureLabel;
  final String waitLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final labelFontSize = compact ? 10.5 : 11.0;
    final valueFontSize = compact ? 19.0 : 26.0;
    final detailFontSize = compact ? 11.0 : 12.0;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: compact ? double.infinity : 228),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 9 : 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        border: Border.all(color: const Color(0x1A171717)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next train',
            style: textTheme.bodySmall?.copyWith(
              color: const Color(0xAA171717),
              fontSize: labelFontSize,
            ),
          ),
          SizedBox(height: compact ? 4 : 8),
          Text(
            departureLabel,
            style: textTheme.headlineMedium?.copyWith(
              fontSize: valueFontSize,
              color: const Color(0xFF171717),
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            waitLabel,
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5E5E5E),
              fontSize: detailFontSize,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0x0DF5F5F5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x1AF5F5F5)),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0x99F5F5F5),
            fontSize: 11,
          ),
          children: [
            TextSpan(text: '$label  '),
            TextSpan(
              text: value,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFFF5F5F5),
                fontSize: 12,
              ),
            ),
          ],
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: const Color(0xADF5F5F5)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final option = options[index];

              return _SelectionChip(
                label: option.label,
                selected: option.value == value,
                disabled: option.disabled,
                onPressed: option.disabled
                    ? null
                    : () => onPressed(option.value),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemCount: options.length,
          ),
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
    return Opacity(
      opacity: disabled ? 0.48 : 1,
      child: Material(
        color: selected ? const Color(0xFFE0E0E0) : const Color(0x0DF5F5F5),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? Colors.transparent : const Color(0x1AF5F5F5),
              ),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected
                    ? const Color(0xFF171717)
                    : const Color(0xFFF5F5F5),
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.currentTime,
    required this.departureLabel,
    required this.waitLabel,
  });

  final String currentTime;
  final String departureLabel;
  final String waitLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Narayanganj Rail',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFFF7F7F7),
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                currentTime.isEmpty ? 'Dhaka time' : currentTime,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xB8F5F5F5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: _PrimaryBadge(
            departureLabel: departureLabel,
            waitLabel: waitLabel,
            compact: true,
          ),
        ),
      ],
    );
  }
}
