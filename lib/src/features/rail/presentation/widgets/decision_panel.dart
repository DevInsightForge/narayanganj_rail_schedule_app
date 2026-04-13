import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/rail_board_cubit.dart';
import 'panel_palette.dart';
import 'panel_shell.dart';
import 'rail_primitives.dart';
import 'rail_board_texts.dart';
import 'rail_board_copy.dart';

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
    final tokens = RailBoardTokens.of(context);
    final nextService = view.snapshot.nextService;

    if (nextService == null) {
      return const PanelShell(
        child: RailStateMessage(
          title: RailBoardTexts.noTrainsMatchRouteTitle,
          message: RailBoardTexts.noTrainsMatchRouteMessage,
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
            eyebrow: RailBoardTexts.bestNextTrainEyebrow,
            title: RailBoardCopy.getDecision(nextService.waitMinutes),
            subtitle:
                RailBoardTexts.bestNextTrainSubtitle(
                  from: view.snapshot.selectedStationName,
                  destination: view.snapshot.destinationStationName,
                  etaLabel: RailBoardCopy.getEtaLabel(nextService.etaMinutes),
                ),
          ),
          SizedBox(height: tokens.sectionGap),
          Wrap(
            spacing: tokens.compactGap,
            runSpacing: tokens.compactGap,
            children: [
              RailPill(
                label: RailBoardTexts.tripLabel,
                value:
                    '${view.snapshot.selectedStationName} to ${view.snapshot.destinationStationName}',
              ),
              RailPill(
                label: RailBoardTexts.trainLabel,
                value: '${nextService.trainNo}',
              ),
              RailPill(
                label: RailBoardTexts.serviceLabel,
                value: RailBoardCopy.getServicePeriodLabel(
                  nextService.servicePeriod,
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.sectionGap),
          _MetricGrid(
            tiles: [
              RailMetricTile(
                label: RailBoardTexts.departsLabel,
                value: RailBoardCopy.formatTimeAmPm(nextService.departureTime),
                detail: RailBoardCopy.getWaitLabel(nextService.waitMinutes),
                icon: Icons.login_rounded,
              ),
              RailMetricTile(
                label: RailBoardTexts.rideLabel,
                value: RailBoardCopy.getDurationLabel(travelMinutes),
                detail: RailBoardTexts.rideTimeDetail,
                icon: Icons.train_rounded,
              ),
              RailMetricTile(
                label: RailBoardTexts.arrivesLabel,
                value: RailBoardCopy.formatTimeAmPm(nextService.arrivalTime),
                detail: RailBoardCopy.getEtaLabel(nextService.etaMinutes),
                icon: Icons.flag_rounded,
              ),
            ],
          ),
          if (community.featuresEnabled) ...[
            SizedBox(height: tokens.sectionGap),
            _CommunityPanel(
              report: report,
              community: community,
              onPressed: () =>
                  context.read<RailBoardCubit>().submitArrivalReport(),
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
            eyebrow: RailBoardTexts.liveRiderUpdatesEyebrow,
            title: RailBoardTexts.communityHeadline(community.insightStatus),
          ),
          if (status != null) ...[
            SizedBox(height: tokens.sectionGap),
            Wrap(
              spacing: tokens.compactGap,
              runSpacing: tokens.compactGap,
              children: [
                RailPill(
                  label: RailBoardTexts.delayStatusLabel,
                  value: RailBoardTexts.delayValue(
                    status.delayStatus,
                    status.delayMinutes,
                  ),
                  accent: true,
                ),
                RailPill(
                  label: RailBoardTexts.confidenceLabel,
                  value: '${(status.confidence.score * 100).round()}%',
                ),
                RailPill(
                  label: RailBoardTexts.lastUpdatedLabel,
                  value: RailBoardTexts.freshnessLabel(status.freshnessSeconds),
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
                label: Text(
                  RailBoardTexts.communityButtonLabel(
                    hasReportedCurrentSession: report.hasReportedCurrentSession,
                    status: report.status,
                    submitEnabled: report.submitEnabled,
                  ),
                ),
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

}
