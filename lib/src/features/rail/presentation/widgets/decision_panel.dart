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
            subtitle: RailBoardTexts.bestNextTrainSubtitle(
              from: view.snapshot.selectedStationName,
              destination: view.snapshot.destinationStationName,
              etaLabel: RailBoardCopy.getDurationLabel(travelMinutes),
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
                detail: RailBoardCopy.getWaitLabel(nextService.etaMinutes),
                icon: Icons.flag_rounded,
              ),
            ],
          ),
          if (community.featuresEnabled) ...[
            SizedBox(height: tokens.sectionGap),
            _CommunityLiveBlock(
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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            Expanded(child: tiles[i]),
            if (i < tiles.length - 1) SizedBox(width: tokens.itemGap),
          ],
        ],
      ),
    );
  }
}

class _CommunityLiveBlock extends StatelessWidget {
  const _CommunityLiveBlock({
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
    final textTheme = Theme.of(context).textTheme;
    final status = community.overlay;
    final isReported =
        report.hasReportedCurrentSession ||
        report.status == RailReportSubmissionStatus.success;

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
            SizedBox(height: tokens.itemGap),
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
            SizedBox(height: tokens.compactGap),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: status.confidence.score >= 0.6
                        ? tokens.accent
                        : tokens.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${(status.confidence.score * 100).round()}% confidence • ${RailBoardTexts.freshnessLabel(status.freshnessSeconds)} • ${RailBoardTexts.reportsCountLabel(status.confidence.sampleCount)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (community.message != null && community.message!.isNotEmpty) ...[
            SizedBox(height: tokens.itemGap),
            Text(
              community.message!,
              style: textTheme.bodyMedium?.copyWith(color: tokens.textMuted),
            ),
          ],

          if (report.isActionVisible) ...[
            SizedBox(height: tokens.sectionGap),
            if (isReported)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: tokens.accentSoft,
                  borderRadius: BorderRadius.circular(tokens.chipRadius),
                  border: Border.all(
                    color: tokens.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: tokens.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      RailBoardTexts.arrivalSharedThankYou,
                      style: textTheme.labelMedium?.copyWith(
                        color: tokens.accent,
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: report.isSubmissionLocked ? null : onPressed,
                  icon: report.status == RailReportSubmissionStatus.submitting
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.flag_rounded, size: 16),
                  label: Text(
                    RailBoardTexts.communityButtonLabel(
                      hasReportedCurrentSession:
                          report.hasReportedCurrentSession,
                      status: report.status,
                      submitEnabled: report.submitEnabled,
                      actionReason: report.actionReason,
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
