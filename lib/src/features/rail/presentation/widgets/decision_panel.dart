import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/rail_snapshot.dart';
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
    this.showCommunity = true,
  });

  final RailBoardViewState view;
  final RailBoardReportState report;
  final RailBoardCommunityState community;
  final bool showCommunity;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final nextService = view.snapshot.nextDepartureService;
    final reportService = view.snapshot.nextService;
    final showLateArrivalReport =
        reportService?.isOverdue == true && report.isActionVisible;
    final communityTrainNo = reportService?.trainNo;
    final communityBelongsToPrimary =
        nextService != null && reportService?.trainNo == nextService.trainNo;
    final delayMinutes =
        communityBelongsToPrimary &&
            (community.insightStatus == RailCommunityInsightStatus.ready ||
                community.insightStatus == RailCommunityInsightStatus.stale)
        ? community.overlay?.delayMinutes
        : null;
    final hasLiveDelay = delayMinutes != null && delayMinutes != 0;
    final estimatedDeparture = hasLiveDelay && nextService != null
        ? RailBoardCopy.formatTimeAmPm(
            RailBoardCopy.addMinutesToTime24(
              nextService.departureTime,
              delayMinutes,
            ),
          )
        : null;
    final estimatedArrival = hasLiveDelay && nextService != null
        ? RailBoardCopy.formatTimeAmPm(
            RailBoardCopy.addMinutesToTime24(
              nextService.arrivalTime,
              delayMinutes,
            ),
          )
        : null;
    final animationDuration =
        MediaQuery.maybeOf(context)?.disableAnimations == true
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final boardContent = nextService == null
        ? const KeyedSubtree(
            key: ValueKey('no-upcoming-departure'),
            child: RailStateMessage(
              title: RailBoardTexts.noTrainAvailableMessage,
              message: RailBoardTexts.noUpcomingDepartureMessage,
              icon: Icons.schedule_rounded,
            ),
          )
        : KeyedSubtree(
            key: ValueKey('${view.selection.direction}-${nextService.trainNo}'),
            child: _BoardableServiceContent(
              service: nextService,
              departureTime: RailBoardCopy.formatTimeAmPm(
                nextService.departureTime,
              ),
              arrivalTime: RailBoardCopy.formatTimeAmPm(
                nextService.arrivalTime,
              ),
              estimatedDepartureTime: estimatedDeparture,
              estimatedArrivalTime: estimatedArrival,
              durationLabel: RailBoardCopy.getDurationLabel(
                nextService.etaMinutes - nextService.waitMinutes,
              ),
              departureStatusLabel:
                  '${RailBoardTexts.departsLabel} ${RailBoardCopy.getWaitLabel(nextService.waitMinutes).toLowerCase()}',
              arrivalStatusLabel:
                  '${RailBoardTexts.arrivesLabel} ${RailBoardCopy.getWaitLabel(nextService.etaMinutes).toLowerCase()}',
              selectedStationName: view.snapshot.selectedStationName,
              destinationStationName: view.snapshot.destinationStationName,
            ),
          );

    return PanelShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            child: AnimatedSwitcher(
              duration: animationDuration,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: boardContent,
            ),
          ),
          AnimatedSize(
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            child: showLateArrivalReport && reportService != null
                ? Padding(
                    padding: EdgeInsets.only(top: tokens.sectionGap),
                    child: _LateArrivalReportStrip(
                      key: ValueKey('late-report-${reportService.trainNo}'),
                      service: reportService,
                      report: report,
                      onPressed: () =>
                          context.read<RailBoardCubit>().submitArrivalReport(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (showCommunity && community.featuresEnabled) ...[
            SizedBox(height: tokens.sectionGap),
            CommunityPanel(
              report: report,
              community: community,
              serviceTrainNo: communityTrainNo,
              showReportAction: !showLateArrivalReport,
              onPressed: () =>
                  context.read<RailBoardCubit>().submitArrivalReport(),
            ),
          ],
        ],
      ),
    );
  }
}

class _BoardableServiceContent extends StatelessWidget {
  const _BoardableServiceContent({
    required this.service,
    required this.departureTime,
    required this.arrivalTime,
    required this.estimatedDepartureTime,
    required this.estimatedArrivalTime,
    required this.durationLabel,
    required this.departureStatusLabel,
    required this.arrivalStatusLabel,
    required this.selectedStationName,
    required this.destinationStationName,
  });

  final RailServiceSnapshot service;
  final String departureTime;
  final String arrivalTime;
  final String? estimatedDepartureTime;
  final String? estimatedArrivalTime;
  final String durationLabel;
  final String departureStatusLabel;
  final String arrivalStatusLabel;
  final String selectedStationName;
  final String destinationStationName;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RailSectionHeader(
          eyebrow: RailBoardTexts.nextBoardableEyebrow,
          title: RailBoardCopy.getDecision(service.waitMinutes),
          subtitle: RailBoardTexts.bestNextTrainSubtitle(
            from: selectedStationName,
            destination: destinationStationName,
            etaLabel: durationLabel,
          ),
        ),
        SizedBox(height: tokens.sectionGap),
        Wrap(
          spacing: tokens.compactGap,
          runSpacing: tokens.compactGap,
          children: [
            RailPill(
              label: RailBoardTexts.tripLabel,
              value: '$selectedStationName to $destinationStationName',
            ),
            RailPill(
              label: RailBoardTexts.trainLabel,
              value: '${service.trainNo}',
            ),
            RailPill(
              label: RailBoardTexts.serviceLabel,
              value: RailBoardCopy.getServicePeriodLabel(service.servicePeriod),
            ),
          ],
        ),
        SizedBox(height: tokens.sectionGap),
        RailJourneyTicketStrip(
          departureTime: departureTime,
          arrivalTime: arrivalTime,
          estimatedDepartureTime: estimatedDepartureTime,
          estimatedArrivalTime: estimatedArrivalTime,
          durationLabel: durationLabel,
          departureStatusLabel: departureStatusLabel,
          arrivalStatusLabel: arrivalStatusLabel,
          showPulse: service.waitMinutes <= 15,
        ),
      ],
    );
  }
}

class _LateArrivalReportStrip extends StatelessWidget {
  const _LateArrivalReportStrip({
    super.key,
    required this.service,
    required this.report,
    required this.onPressed,
  });

  final RailServiceSnapshot service;
  final RailBoardReportState report;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isSubmitting = report.status == RailReportSubmissionStatus.submitting;
    final isReported =
        report.hasReportedCurrentSession ||
        report.status == RailReportSubmissionStatus.success;

    final actionLabel = isReported
        ? RailBoardTexts.communityUpdateShared
        : isSubmitting
        ? RailBoardTexts.sendingUpdate
        : report.submitEnabled
        ? RailBoardTexts.reportArrivalAction
        : RailBoardTexts.communityButtonLabel(
            hasReportedCurrentSession: report.hasReportedCurrentSession,
            status: report.status,
            submitEnabled: report.submitEnabled,
            actionReason: report.actionReason,
          );

    final actionButton = Semantics(
      label: RailBoardTexts.reportArrivalForTrain(service.trainNo),
      child: Tooltip(
        message: RailBoardTexts.reportArrivalForTrain(service.trainNo),
        child: FilledButton.icon(
          onPressed: report.isSubmissionLocked ? null : onPressed,
          icon: isSubmitting
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: tokens.accent,
                  ),
                )
              : Icon(
                  isReported ? Icons.check_circle_rounded : Icons.flag_rounded,
                  size: 15,
                  color: report.isSubmissionLocked
                      ? tokens.textMuted
                      : tokens.accent,
                ),
          label: Text(
            actionLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: report.isSubmissionLocked
                  ? tokens.textMuted
                  : theme.colorScheme.onSurface,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: tokens.primarySurface,
            foregroundColor: theme.colorScheme.onSurface,
            disabledBackgroundColor: tokens.primarySurface.withValues(
              alpha: 0.5,
            ),
            disabledForegroundColor: tokens.textMuted,
            side: BorderSide(
              color: report.submitEnabled
                  ? tokens.accent.withValues(alpha: 0.4)
                  : tokens.border,
            ),
            elevation: 0,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.chipRadius),
            ),
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final target = Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: tokens.accentSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.history_rounded,
                size: 16,
                color: tokens.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${RailBoardTexts.previousTrainLabel} #${service.trainNo}',
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    RailBoardCopy.getOverdueDepartureDetail(
                      overdueMinutes: service.overdueMinutes,
                    ),
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final isNarrow = constraints.maxWidth < 360;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: tokens.secondarySurface,
            borderRadius: BorderRadius.circular(tokens.panelRadius),
            border: Border.all(color: tokens.border),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [target, const SizedBox(height: 10), actionButton],
                )
              : Row(
                  children: [
                    Expanded(child: target),
                    const SizedBox(width: 10),
                    actionButton,
                  ],
                ),
        );
      },
    );
  }
}

class CommunityPanel extends StatelessWidget {
  const CommunityPanel({
    super.key,
    required this.report,
    required this.community,
    this.onPressed,
    this.isStandalone = false,
    this.serviceTrainNo,
    this.showReportAction = true,
  });

  final RailBoardReportState report;
  final RailBoardCommunityState community;
  final VoidCallback? onPressed;
  final bool isStandalone;
  final int? serviceTrainNo;
  final bool showReportAction;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final status = community.overlay;
    final isReported =
        report.hasReportedCurrentSession ||
        report.status == RailReportSubmissionStatus.success;

    return PanelShell(
      surface: isStandalone
          ? RailPanelSurface.primary
          : RailPanelSurface.secondary,
      padding: isStandalone ? tokens.panelPadding : const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RailSectionHeader(
            eyebrow: serviceTrainNo == null
                ? RailBoardTexts.liveRiderUpdatesEyebrow
                : RailBoardTexts.liveUpdatesForTrain(serviceTrainNo!),
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
              ],
            ),
            SizedBox(height: tokens.itemGap),
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

          if (showReportAction && report.isActionVisible) ...[
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
                    Flexible(
                      child: Text(
                        RailBoardTexts.arrivalSharedThankYou,
                        style: textTheme.labelMedium?.copyWith(
                          color: tokens.accent,
                        ),
                        textAlign: TextAlign.center,
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
