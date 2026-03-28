import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../community/domain/entities/delay_status.dart';
import '../../../community/domain/entities/session_status_snapshot.dart';
import '../../domain/services/rail_board_service.dart';
import '../bloc/rail_board_bloc.dart';
import 'panel_palette.dart';
import 'panel_shell.dart';

class DecisionPanel extends StatelessWidget {
  const DecisionPanel({
    super.key,
    required this.view,
    required this.report,
    required this.community,
  });

  final RailBoardViewState view;
  final RailBoardReportState report;
  final RailBoardCommunityState community;

  @override
  Widget build(BuildContext context) {
    final boardService = context.read<RailBoardService>();
    final palette = RailPanelPalette.of(Theme.of(context).colorScheme);
    final nextService = view.snapshot.nextService!;
    final travelMinutes = nextService.etaMinutes - nextService.waitMinutes;

    return PanelShell(
      backgroundColor: palette.panelBackground,
      borderColor: palette.panelBorder,
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
            'Board at ${view.snapshot.selectedStationName} and arrive at ${view.snapshot.destinationStationName} in ${boardService.getEtaLabel(nextService.etaMinutes)}.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: palette.panelMutedText,
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
                    '${view.snapshot.selectedStationName} to ${view.snapshot.destinationStationName}',
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
          if (community.featuresEnabled) ...[
            const SizedBox(height: 12),
            _CommunityEstimateBlock(
              communityInsightStatus: community.insightStatus,
              sessionStatusSnapshot: community.sessionStatusSnapshot,
              communityMessage: community.message,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: report.status == RailReportSubmissionStatus.submitting
                  ? null
                  : () => context.read<RailBoardBloc>().add(
                      const RailBoardArrivalReportRequested(),
                    ),
              icon: Icon(
                report.status == RailReportSubmissionStatus.submitting
                    ? Icons.sync
                    : Icons.flag_rounded,
              ),
              label: Text(_reportButtonLabel(report.status)),
            ),
          ],
        ],
      ),
    );
  }

  String _reportButtonLabel(RailReportSubmissionStatus status) {
    switch (status) {
      case RailReportSubmissionStatus.submitting:
        return 'Sending report...';
      case RailReportSubmissionStatus.success:
        return 'Report sent';
      case RailReportSubmissionStatus.rateLimited:
        return 'Rate limited';
      case RailReportSubmissionStatus.offlineQueue:
        return 'Queued offline';
      case RailReportSubmissionStatus.error:
        return 'Try reporting again';
      case RailReportSubmissionStatus.idle:
        return 'Report arrival at this station';
    }
  }
}

class _CommunityEstimateBlock extends StatelessWidget {
  const _CommunityEstimateBlock({
    required this.communityInsightStatus,
    required this.sessionStatusSnapshot,
    required this.communityMessage,
  });

  final RailCommunityInsightStatus communityInsightStatus;
  final SessionStatusSnapshot? sessionStatusSnapshot;
  final String? communityMessage;

  @override
  Widget build(BuildContext context) {
    final palette = RailPanelPalette.of(Theme.of(context).colorScheme);
    final status = sessionStatusSnapshot;
    final title = switch (communityInsightStatus) {
      RailCommunityInsightStatus.loading => 'Community estimate updating',
      RailCommunityInsightStatus.ready => 'Community estimate',
      RailCommunityInsightStatus.stale => 'Community estimate (stale)',
      RailCommunityInsightStatus.empty => 'Community estimate unavailable',
      RailCommunityInsightStatus.error => 'Community estimate error',
      RailCommunityInsightStatus.idle => 'Community estimate',
    };
    final detail = status == null
        ? (communityMessage ?? 'No community signal yet.')
        : '${_delayLabel(status)} | Confidence ${_confidencePercent(status)} | Freshness ${_freshnessLabel(status.freshnessSeconds)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.panelSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: palette.panelMutedText,
              fontSize: 12,
            ),
          ),
          if (communityMessage != null && communityMessage!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              communityMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.panelMutedText,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _delayLabel(SessionStatusSnapshot snapshot) {
    final minutes = snapshot.delayMinutes;
    switch (snapshot.delayStatus) {
      case DelayStatus.early:
        return '${minutes.abs()} min early';
      case DelayStatus.onTime:
        return 'On time';
      case DelayStatus.late:
        return '$minutes min late';
    }
  }

  String _confidencePercent(SessionStatusSnapshot snapshot) {
    final percent = (snapshot.confidence.score * 100).round();
    return '$percent%';
  }

  String _freshnessLabel(int freshnessSeconds) {
    if (freshnessSeconds < 60) {
      return '${freshnessSeconds}s';
    }
    final minutes = freshnessSeconds ~/ 60;
    return '${minutes}m';
  }
}

class _RouteChip extends StatelessWidget {
  const _RouteChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = RailPanelPalette.of(Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.panelElevatedSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.panelBorder),
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
    final palette = RailPanelPalette.of(Theme.of(context).colorScheme);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.panelSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.panelBorder),
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
              color: palette.panelMutedText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
