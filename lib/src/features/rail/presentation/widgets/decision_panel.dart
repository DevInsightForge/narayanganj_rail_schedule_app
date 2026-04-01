import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../community/domain/entities/delay_status.dart';
import '../../../community/domain/entities/session_status_snapshot.dart';
import '../../application/models/rail_reporting.dart';
import '../../domain/services/rail_board_service.dart';
import '../bloc/rail_board_bloc.dart';
import 'panel_palette.dart';
import 'panel_shell.dart';
import 'rail_primitives.dart';

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
    final tokens = RailBoardTokens.of(context);
    final nextService = view.snapshot.nextService;

    if (nextService == null) {
      return const PanelShell(
        child: RailStateMessage(
          title: 'No departure for this route',
          message:
              'Try switching direction or adjusting the boarding station to see the next commuter option.',
          icon: Icons.route_rounded,
        ),
      );
    }

    final travelMinutes = nextService.etaMinutes - nextService.waitMinutes;

    return PanelShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RailSectionHeader(
            eyebrow: 'Best next option',
            title: boardService.getDecision(nextService.waitMinutes),
            subtitle:
                'Board at ${view.snapshot.selectedStationName} and reach ${view.snapshot.destinationStationName} in ${boardService.getEtaLabel(nextService.etaMinutes).toLowerCase()}.',
          ),
          SizedBox(height: tokens.sectionGap),
          Wrap(
            spacing: tokens.compactGap,
            runSpacing: tokens.compactGap,
            children: [
              RailPill(
                label: 'Route',
                value:
                    '${view.snapshot.selectedStationName} to ${view.snapshot.destinationStationName}',
              ),
              RailPill(label: 'Train', value: '${nextService.trainNo}'),
              RailPill(
                label: 'Period',
                value: boardService.getServicePeriodLabel(
                  nextService.servicePeriod,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.sectionGap),
          _MetricGrid(
            tiles: [
              RailMetricTile(
                label: 'Boards',
                value: boardService.formatTimeAmPm(nextService.departureTime),
                detail: boardService.getWaitLabel(nextService.waitMinutes),
                icon: Icons.login_rounded,
              ),
              RailMetricTile(
                label: 'Travel',
                value: boardService.getDurationLabel(travelMinutes),
                detail: 'On-train time',
                icon: Icons.train_rounded,
              ),
              RailMetricTile(
                label: 'Arrives',
                value: boardService.formatTimeAmPm(nextService.arrivalTime),
                detail: boardService.getEtaLabel(nextService.etaMinutes),
                icon: Icons.flag_rounded,
              ),
            ],
          ),
          if (community.featuresEnabled) ...[
            SizedBox(height: tokens.sectionGap),
            _CommunityPanel(
              report: report,
              community: community,
              onPressed: () => context.read<RailBoardBloc>().add(
                const RailBoardArrivalReportRequested(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    if (!tokens.isWide) {
      return Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i < tiles.length - 1) SizedBox(height: tokens.itemGap),
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          Expanded(child: tiles[i]),
          if (i < tiles.length - 1) SizedBox(width: tokens.itemGap),
        ],
      ],
    );
  }
}

class _CommunityPanel extends StatelessWidget {
  const _CommunityPanel({
    required this.report,
    required this.community,
    required this.onPressed,
  });

  final RailBoardReportState report;
  final RailBoardCommunityState community;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final status = community.sessionStatusSnapshot;

    return PanelShell(
      surface: RailPanelSurface.secondary,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RailSectionHeader(
            eyebrow: 'Community signal',
            title: _title(community.insightStatus),
            subtitle: _description(community.insightStatus),
          ),
          if (status != null) ...[
            SizedBox(height: tokens.sectionGap),
            Wrap(
              spacing: tokens.compactGap,
              runSpacing: tokens.compactGap,
              children: [
                RailPill(
                  label: 'Delay',
                  value: _delayLabel(status),
                  accent: true,
                ),
                RailPill(
                  label: 'Confidence',
                  value: '${(status.confidence.score * 100).round()}%',
                ),
                RailPill(
                  label: 'Freshness',
                  value: _freshness(status.freshnessSeconds),
                ),
              ],
            ),
          ],
          if (community.message != null && community.message!.isNotEmpty) ...[
            SizedBox(height: tokens.itemGap),
            Text(
              community.message!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
            ),
          ],
          if (report.isActionVisible) ...[
            SizedBox(height: tokens.sectionGap),
            Divider(color: tokens.border, height: 1),
            SizedBox(height: tokens.sectionGap),
            if (report.actionHint != null &&
                report.actionHint!.isNotEmpty &&
                report.actionReason != RailReportActionReason.eligible)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  report.actionHint!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    report.status == RailReportSubmissionStatus.submitting ||
                        !report.submitEnabled
                    ? null
                    : onPressed,
                icon: Icon(
                  report.status == RailReportSubmissionStatus.submitting
                      ? Icons.sync_rounded
                      : Icons.flag_rounded,
                ),
                label: Text(_buttonLabel(report)),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(36),
                  visualDensity: const VisualDensity(
                    horizontal: -2,
                    vertical: -2,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _title(RailCommunityInsightStatus status) {
    return switch (status) {
      RailCommunityInsightStatus.stale => 'Reported Delay (Stale)',
      RailCommunityInsightStatus.error => 'Reported Delay Offline',
      _ => 'Reported Delay',
    };
  }

  String _description(RailCommunityInsightStatus status) {
    return switch (status) {
      RailCommunityInsightStatus.loading =>
        'Refreshing rider reports for the active train session.',
      RailCommunityInsightStatus.ready =>
        'Latest rider observations have been aggregated into one delay signal.',
      RailCommunityInsightStatus.stale =>
        'The latest rider signal is older than preferred but still shown for context.',
      RailCommunityInsightStatus.empty =>
        'No rider report has been submitted for this train yet.',
      RailCommunityInsightStatus.error =>
        'Live rider signal is unavailable. The official schedule still works.',
      RailCommunityInsightStatus.idle =>
        'Community status will appear when a matching train session is active.',
    };
  }

  String _buttonLabel(RailBoardReportState report) {
    if (report.hasReportedCurrentSession) {
      return 'Arrival Reported';
    }
    return switch (report.status) {
      RailReportSubmissionStatus.submitting => 'Submitting Report...',
      RailReportSubmissionStatus.rateLimited => 'Please Wait',
      RailReportSubmissionStatus.error =>
        report.submitEnabled
            ? 'Submit Arrival Report'
            : 'Reporting Unavailable',
      RailReportSubmissionStatus.success => 'Report Submitted',
      RailReportSubmissionStatus.idle =>
        report.submitEnabled
            ? 'Submit Arrival Report'
            : 'Reporting Unavailable',
    };
  }

  String _delayLabel(SessionStatusSnapshot snapshot) {
    return switch (snapshot.delayStatus) {
      DelayStatus.early => '${snapshot.delayMinutes.abs()} min early',
      DelayStatus.onTime => 'On time',
      DelayStatus.late => '${snapshot.delayMinutes} min late',
    };
  }

  String _freshness(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    }
    return '${seconds ~/ 60}m';
  }
}
