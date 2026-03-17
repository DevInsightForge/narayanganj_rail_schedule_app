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
      backgroundColor: const Color(0xEBF7F7F7),
      borderColor: const Color(0x29171717),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;

              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: _DecisionCopy(
                            verdict: boardService.getDecision(
                              nextService.waitMinutes,
                            ),
                            detail:
                                'Leave from ${snapshot.selectedStationName} and reach ${snapshot.destinationStationName} in ${boardService.getEtaLabel(nextService.etaMinutes)}.',
                          ),
                        ),
                        const SizedBox(width: 12),
                        _RouteChip(
                          label:
                              '${snapshot.selectedStationName} to ${snapshot.destinationStationName}',
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DecisionCopy(
                          verdict: boardService.getDecision(
                            nextService.waitMinutes,
                          ),
                          detail:
                              'Leave from ${snapshot.selectedStationName} and reach ${snapshot.destinationStationName} in ${boardService.getEtaLabel(nextService.etaMinutes)}.',
                        ),
                        const SizedBox(height: 12),
                        _RouteChip(
                          label:
                              '${snapshot.selectedStationName} to ${snapshot.destinationStationName}',
                        ),
                      ],
                    );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricCard(
                label: 'Boards at',
                value: boardService.formatTimeAmPm(nextService.departureTime),
                detail: boardService.getWaitLabel(nextService.waitMinutes),
              ),
              _MetricCard(
                label: 'Travel',
                value: boardService.getDurationLabel(travelMinutes),
                detail: 'On-train duration',
              ),
              _MetricCard(
                label: 'Arrives',
                value: boardService.formatTimeAmPm(nextService.arrivalTime),
                detail: 'Train ${nextService.trainNo}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DecisionCopy extends StatelessWidget {
  const _DecisionCopy({required this.verdict, required this.detail});

  final String verdict;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Next departure verdict',
          style: textTheme.labelLarge?.copyWith(
            color: const Color(0xFF5E5E5E),
            fontSize: 11,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(verdict, style: textTheme.displayMedium?.copyWith(fontSize: 44)),
        const SizedBox(height: 8),
        Text(
          detail,
          style: textTheme.bodyLarge?.copyWith(
            color: const Color(0xFF5E5E5E),
            fontSize: 16,
          ),
        ),
      ],
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
        color: const Color(0xB8FBF8F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1F171717)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
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
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x75FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14171717)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5E5E5E)),
          ),
        ],
      ),
    );
  }
}
