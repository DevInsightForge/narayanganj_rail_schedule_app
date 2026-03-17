import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/rail_snapshot.dart';
import '../../domain/services/rail_board_service.dart';
import 'panel_shell.dart';

class DecisionPanel extends StatelessWidget {
  const DecisionPanel({super.key, required this.snapshot});

  final RailBoardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final boardService = context.read<RailBoardService>();
    final nextService = snapshot.nextService!;
    final travelMinutes = nextService.etaMinutes - nextService.waitMinutes;

    return PanelShell(
      backgroundColor: const Color(0xFFF8F8F8),
      borderColor: const Color(0x14171717),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Best next option',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 11, letterSpacing: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            boardService.getDecision(nextService.waitMinutes),
            style: Theme.of(
              context,
            ).textTheme.displayMedium?.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 6),
          Text(
            'Board at ${snapshot.selectedStationName} and arrive at ${snapshot.destinationStationName} in ${boardService.getEtaLabel(nextService.etaMinutes)}.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF5E5E5E),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RouteChip(
                label:
                    '${snapshot.selectedStationName} to ${snapshot.destinationStationName}',
              ),
              _RouteChip(label: 'Train ${nextService.trainNo}'),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final useGrid = constraints.maxWidth >= 420;

              final cards = [
                _MetricCard(
                  label: 'Boards',
                  value: boardService.formatTimeAmPm(nextService.departureTime),
                  detail: boardService.getWaitLabel(nextService.waitMinutes),
                ),
                _MetricCard(
                  label: 'Travel',
                  value: boardService.getDurationLabel(travelMinutes),
                  detail: 'On-train time',
                ),
                _MetricCard(
                  label: 'Arrives',
                  value: boardService.formatTimeAmPm(nextService.arrivalTime),
                  detail: boardService.getEtaLabel(nextService.etaMinutes),
                ),
              ];

              if (!useGrid) {
                return Column(
                  children: [
                    for (var index = 0; index < cards.length; index++) ...[
                      cards[index],
                      if (index != cards.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  for (var index = 0; index < cards.length; index++) ...[
                    Expanded(child: cards[index]),
                    if (index != cards.length - 1) const SizedBox(width: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RouteChip extends StatelessWidget {
  const _RouteChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x12171717)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x12171717)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5E5E5E),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
