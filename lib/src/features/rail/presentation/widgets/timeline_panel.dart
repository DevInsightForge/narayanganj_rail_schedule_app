import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../community/domain/entities/predicted_stop_time.dart';
import '../../domain/entities/rail_snapshot.dart';
import '../bloc/rail_board_cubit.dart';
import 'panel_palette.dart';
import 'panel_shell.dart';
import 'rail_board_copy.dart';
import 'rail_board_texts.dart';
import 'rail_primitives.dart';

class TimelinePanel extends StatelessWidget {
  const TimelinePanel({
    super.key,
    required this.snapshot,
    required this.predictedStopTimes,
    this.previewService,
    this.isCollapsed = false,
    this.boardingStationId,
    this.destinationStationId,
  });

  final RailBoardSnapshot snapshot;
  final List<PredictedStopTime> predictedStopTimes;
  final RailServiceSnapshot? previewService;
  final bool isCollapsed;
  final String? boardingStationId;
  final String? destinationStationId;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final defaultService =
        snapshot.nextDepartureService ?? snapshot.nextService;
    final activeTrain = previewService ?? defaultService;

    if (activeTrain == null) {
      return const PanelShell(
        child: RailStateMessage(
          title: RailBoardTexts.stopByStopUnavailableTitle,
          message: RailBoardTexts.stopByStopUnavailableMessage,
          icon: Icons.timeline_rounded,
        ),
      );
    }

    final isPreviewing =
        previewService != null &&
        defaultService != null &&
        previewService!.trainNo != defaultService.trainNo;

    final predictionsBelongToActiveTrain =
        !isPreviewing && snapshot.nextService?.trainNo == activeTrain.trainNo;
    final predictedByStation = !predictionsBelongToActiveTrain
        ? const <String, PredictedStopTime>{}
        : {
            for (final prediction in predictedStopTimes)
              prediction.stationId: prediction,
          };

    final hasPassedStops = predictedByStation.values.any((p) => p.isPassed);
    final firstApproachingIndex = hasPassedStops
        ? activeTrain.stops.indexWhere(
            (stop) => predictedByStation[stop.stationId]?.isPassed != true,
          )
        : -1;

    final rawBoardingIndex = boardingStationId != null
        ? activeTrain.stops.indexWhere(
            (stop) => stop.stationId == boardingStationId,
          )
        : -1;
    final boardingIndex = rawBoardingIndex >= 0 ? rawBoardingIndex : 0;

    final rawDestIndex = destinationStationId != null
        ? activeTrain.stops.indexWhere(
            (stop) => stop.stationId == destinationStationId,
          )
        : -1;
    final destinationIndex = rawDestIndex >= 0
        ? rawDestIndex
        : activeTrain.stops.length - 1;

    final displayedStops = isCollapsed
        ? [
            activeTrain.stops[boardingIndex],
            if (firstApproachingIndex > boardingIndex &&
                firstApproachingIndex < destinationIndex)
              activeTrain.stops[firstApproachingIndex],
            activeTrain.stops[destinationIndex],
          ]
        : activeTrain.stops;

    return PanelShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RailSectionHeader(
            eyebrow: RailBoardTexts.routeStopsEyebrow,
            title: RailBoardTexts.scheduledStopsTitle,
            subtitle: RailBoardTexts.routeStopsSubtitle(activeTrain.trainNo),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RailPill(
                  label: RailBoardTexts.trainLabel,
                  value: '${activeTrain.trainNo}',
                  accent: true,
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: isCollapsed
                      ? RailBoardTexts.expandTimelineLabel
                      : RailBoardTexts.collapseTimelineLabel,
                  onPressed: () =>
                      context.read<RailBoardCubit>().toggleTimelineExpansion(),
                  style: IconButton.styleFrom(
                    backgroundColor: tokens.secondarySurface,
                    foregroundColor: tokens.accent,
                    side: BorderSide(color: tokens.border),
                    minimumSize: const Size(32, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    isCollapsed
                        ? Icons.unfold_more_rounded
                        : Icons.unfold_less_rounded,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          if (isPreviewing) ...[
            SizedBox(height: tokens.itemGap),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: tokens.accentSoft,
                borderRadius: BorderRadius.circular(tokens.chipRadius),
                border: Border.all(color: tokens.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.remove_red_eye_rounded,
                    size: 14,
                    color: tokens.accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${RailBoardTexts.previewingTrainLabel} #${activeTrain.trainNo}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tokens.accent,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        context.read<RailBoardCubit>().previewService(null),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 24),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      RailBoardTexts.backToNextTrainAction,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: tokens.sectionGap),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Column(
              children: [
                for (var i = 0; i < displayedStops.length; i++) ...[
                  () {
                    final originalIndex = activeTrain.stops.indexOf(
                      displayedStops[i],
                    );
                    final isWithinRide =
                        originalIndex >= boardingIndex &&
                        originalIndex <= destinationIndex;
                    final isBoarding = originalIndex == boardingIndex;
                    final isDestination = originalIndex == destinationIndex;
                    final isUpstream = originalIndex < boardingIndex;

                    return _StopCard(
                      stop: displayedStops[i],
                      scheduledLabel: RailBoardCopy.formatTimeAmPm(
                        displayedStops[i].time,
                      ),
                      predicted:
                          predictedByStation[displayedStops[i].stationId],
                      isFirst: isBoarding,
                      isLast: isDestination,
                      isWithinRide: isWithinRide,
                      isUpstream: isUpstream,
                      isApproaching: originalIndex == firstApproachingIndex,
                    );
                  }(),
                  if (i < displayedStops.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Row(
                        children: [
                          Container(
                            width: 2,
                            height: 8,
                            color: tokens.accent.withValues(alpha: 0.35),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  const _StopCard({
    required this.stop,
    required this.scheduledLabel,
    required this.predicted,
    required this.isFirst,
    required this.isLast,
    this.isWithinRide = true,
    this.isUpstream = false,
    this.isApproaching = false,
  });

  final RailStopSnapshot stop;
  final String scheduledLabel;
  final PredictedStopTime? predicted;
  final bool isFirst;
  final bool isLast;
  final bool isWithinRide;
  final bool isUpstream;
  final bool isApproaching;

  @override
  Widget build(BuildContext context) {
    final tokens = RailBoardTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isPassed = predicted?.isPassed == true;

    final cardBorder = isApproaching
        ? Border.all(color: tokens.accent.withValues(alpha: 0.6), width: 1.5)
        : Border.all(color: tokens.border);

    final cardColor = isApproaching
        ? tokens.accentSoft
        : isPassed
        ? tokens.secondarySurface.withValues(alpha: 0.5)
        : tokens.secondarySurface;

    final iconData = isPassed
        ? Icons.check_circle_outline_rounded
        : isFirst
        ? Icons.login_rounded
        : isLast
        ? Icons.flag_rounded
        : isWithinRide
        ? Icons.more_horiz_rounded
        : Icons.remove_circle_outline_rounded;

    final iconColor = isPassed
        ? tokens.textMuted
        : isWithinRide
        ? tokens.accent
        : tokens.textMuted;

    final subtitleText = isPassed
        ? RailBoardTexts.departedHere
        : isFirst
        ? RailBoardTexts.boardHere
        : isApproaching
        ? RailBoardTexts.nextStopHere
        : isLast
        ? RailBoardTexts.arriveHere
        : isWithinRide
        ? RailBoardTexts.alongRoute
        : (isUpstream
              ? RailBoardTexts.upstreamStopLabel
              : RailBoardTexts.downstreamStopLabel);

    return Opacity(
      opacity: isWithinRide ? 1.0 : 0.62,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(tokens.chipRadius),
          border: cardBorder,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            isApproaching
                ? PulsingRadarDot(
                    color: tokens.accent,
                    size: 10,
                    pulseRadius: 24,
                  )
                : Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isFirst || isLast
                          ? tokens.accentSoft
                          : tokens.primarySurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Icon(iconData, size: 14, color: iconColor),
                  ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.stationName,
                    style: textTheme.labelLarge?.copyWith(
                      color: isPassed ? tokens.textMuted : null,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitleText,
                    style: textTheme.bodyMedium?.copyWith(
                      color: isApproaching ? tokens.accent : tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text.rich(
                    TextSpan(
                      style: textTheme.bodySmall?.copyWith(
                        color: tokens.textMuted,
                      ),
                      children: [
                        const TextSpan(text: '${RailBoardTexts.plannedLabel} '),
                        TextSpan(
                          text: scheduledLabel,
                          style: textTheme.labelLarge,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.end,
                  ),
                  if (predicted != null) ...[
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        style: textTheme.bodySmall?.copyWith(
                          color: tokens.accent,
                        ),
                        children: [
                          const TextSpan(
                            text: '${RailBoardTexts.liveEstimateLabel} ',
                          ),
                          TextSpan(
                            text: RailBoardCopy.formatTimeAmPm(
                              '${predicted!.predictedAt.hour.toString().padLeft(2, '0')}:${predicted!.predictedAt.minute.toString().padLeft(2, '0')}',
                            ),
                            style: textTheme.labelLarge?.copyWith(
                              color: tokens.accent,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
