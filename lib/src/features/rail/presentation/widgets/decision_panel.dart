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
              lastResolvedInsightStatus: community.lastResolvedInsightStatus,
              sessionStatusSnapshot: community.sessionStatusSnapshot,
              communityMessage: community.message,
              report: report,
              onReportRequested: () {
                context.read<RailBoardBloc>().add(
                  const RailBoardArrivalReportRequested(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _CommunityEstimateBlock extends StatelessWidget {
  const _CommunityEstimateBlock({
    required this.communityInsightStatus,
    required this.lastResolvedInsightStatus,
    required this.sessionStatusSnapshot,
    required this.communityMessage,
    required this.report,
    required this.onReportRequested,
  });

  final RailCommunityInsightStatus communityInsightStatus;
  final RailCommunityInsightStatus lastResolvedInsightStatus;
  final SessionStatusSnapshot? sessionStatusSnapshot;
  final String? communityMessage;
  final RailBoardReportState report;
  final VoidCallback onReportRequested;

  @override
  Widget build(BuildContext context) {
    final palette = RailPanelPalette.of(Theme.of(context).colorScheme);
    final status = sessionStatusSnapshot;
    final isRefreshing =
        communityInsightStatus == RailCommunityInsightStatus.loading;
    final displayStatus =
        isRefreshing &&
            lastResolvedInsightStatus != RailCommunityInsightStatus.idle
        ? lastResolvedInsightStatus
        : communityInsightStatus;

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
          _CommunityEstimateHeader(communityInsightStatus: displayStatus),
          const SizedBox(height: 6),
          Text(
            _statusDescription(displayStatus),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: palette.panelMutedText,
              fontSize: 12,
            ),
          ),
          if (status != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CommunitySignalChip(
                  label: 'Reported Delay',
                  value: _delayLabel(status),
                ),
                _CommunitySignalChip(
                  label: 'Confidence',
                  value: _confidencePercent(status),
                ),
                _CommunitySignalChip(
                  label: 'Freshness',
                  value: _freshnessLabel(status.freshnessSeconds),
                ),
              ],
            ),
          ],
          if (communityMessage != null && communityMessage!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              communityMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.panelMutedText,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Divider(color: palette.panelBorder, height: 1),
          const SizedBox(height: 10),
          if (report.actionHint != null &&
              report.actionHint!.isNotEmpty &&
              report.actionReason != RailReportActionReason.eligible) ...[
            Text(
              report.actionHint!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.panelMutedText,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  report.status == RailReportSubmissionStatus.submitting ||
                      !report.isActionEnabled
                  ? null
                  : onReportRequested,
              icon: Icon(
                report.status == RailReportSubmissionStatus.submitting
                    ? Icons.sync
                    : Icons.flag_rounded,
              ),
              label: Text(_reportButtonLabel(report)),
            ),
          ),
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

  String _statusDescription(RailCommunityInsightStatus status) {
    switch (status) {
      case RailCommunityInsightStatus.loading:
        return 'Updating delay signal from the latest rider reports.';
      case RailCommunityInsightStatus.ready:
        return 'Aggregated delay signal for the active train session.';
      case RailCommunityInsightStatus.stale:
        return 'Latest session delay signal is stale and will refresh automatically.';
      case RailCommunityInsightStatus.empty:
        return 'No rider reports have been received for this train session yet.';
      case RailCommunityInsightStatus.error:
        return 'Live delay signal is temporarily unavailable.';
      case RailCommunityInsightStatus.idle:
        return 'Waiting for the initial session delay signal.';
    }
  }

  String _reportButtonLabel(RailBoardReportState reportState) {
    if (reportState.hasReportedCurrentSession) {
      return 'Arrival Reported';
    }
    switch (reportState.status) {
      case RailReportSubmissionStatus.submitting:
        return 'Submitting Report...';
      case RailReportSubmissionStatus.success:
        return 'Report Submitted';
      case RailReportSubmissionStatus.rateLimited:
        return 'Please Wait';
      case RailReportSubmissionStatus.error:
        return reportState.isActionEnabled
            ? 'Submit Arrival Report'
            : 'Reporting Unavailable';
      case RailReportSubmissionStatus.idle:
        return reportState.isActionEnabled
            ? 'Submit Arrival Report'
            : 'Reporting Unavailable';
    }
  }
}

class _CommunityEstimateHeader extends StatelessWidget {
  const _CommunityEstimateHeader({required this.communityInsightStatus});

  final RailCommunityInsightStatus communityInsightStatus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _title(communityInsightStatus),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: 14),
          ),
        ),
      ],
    );
  }

  String _title(RailCommunityInsightStatus status) {
    switch (status) {
      case RailCommunityInsightStatus.loading:
        return 'Reported Delay';
      case RailCommunityInsightStatus.ready:
        return 'Reported Delay';
      case RailCommunityInsightStatus.stale:
        return 'Reported Delay (Stale)';
      case RailCommunityInsightStatus.empty:
        return 'Reported Delay';
      case RailCommunityInsightStatus.error:
        return 'Reported Delay';
      case RailCommunityInsightStatus.idle:
        return 'Reported Delay';
    }
  }
}

class _CommunitySignalChip extends StatelessWidget {
  const _CommunitySignalChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = RailPanelPalette.of(Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.panelElevatedSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.panelBorder),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: palette.panelMutedText,
            fontSize: 11,
          ),
          children: [
            TextSpan(text: '$label '),
            TextSpan(
              text: value,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
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
