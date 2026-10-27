import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../../../../core/api/edge_hmac_client.dart';
import '../../../community/domain/entities/community_overlay.dart';
import '../../../community/domain/entities/delay_status.dart';
import '../../presentation/bloc/rail_board_state.dart';
import '../../presentation/widgets/rail_board_copy.dart';

class RailWidgetPayload extends Equatable {
  const RailWidgetPayload({
    this.schemaVersion = currentSchemaVersion,
    required this.direction,
    required this.boardingStationId,
    required this.boardingStationName,
    required this.destinationStationId,
    required this.destinationStationName,
    required this.hasNextTrain,
    this.nextTrainNo,
    this.nextDepartureTime,
    this.nextArrivalTime,
    this.nextDepartureEpochMs,
    this.nextServicePeriod,
    required this.hasReportTarget,
    this.reportTrainNo,
    this.reportScheduledDeparture,
    this.reportOverdueMinutes,
    required this.isReportingAvailable,
    this.reportStatusLabel,
    this.communityTripId,
    this.communityTrainNo,
    this.communityStatusLabel,
    this.communityFreshness,
    required this.scheduleVersion,
    required this.updatedAtEpochMs,
    required this.updatedAtLabel,
  });

  static const int currentSchemaVersion = 1;
  static const String storageKey = 'nrs_widget_payload_v1';

  final int schemaVersion;
  final String direction;
  final String boardingStationId;
  final String boardingStationName;
  final String destinationStationId;
  final String destinationStationName;
  final bool hasNextTrain;
  final int? nextTrainNo;
  final String? nextDepartureTime;
  final String? nextArrivalTime;
  final int? nextDepartureEpochMs;
  final String? nextServicePeriod;
  final bool hasReportTarget;
  final int? reportTrainNo;
  final String? reportScheduledDeparture;
  final int? reportOverdueMinutes;
  final bool isReportingAvailable;
  final String? reportStatusLabel;
  final String? communityTripId;
  final int? communityTrainNo;
  final String? communityStatusLabel;
  final String? communityFreshness;
  final String scheduleVersion;
  final int updatedAtEpochMs;
  final String updatedAtLabel;

  static RailWidgetPayload? fromBoardState(
    RailBoardState state, {
    required DateTime now,
  }) {
    if (state.status != RailBoardStatus.ready) {
      return null;
    }

    final selection = state.selection;
    final snapshot = state.snapshot;
    if (selection.direction.isEmpty ||
        selection.boardingStationId.isEmpty ||
        selection.destinationStationId.isEmpty ||
        snapshot.selectedStationName.isEmpty ||
        snapshot.destinationStationName.isEmpty) {
      return null;
    }

    final candidateNext = snapshot.nextDepartureService;
    final nextBoardable = (candidateNext != null && !candidateNext.isOverdue)
        ? candidateNext
        : null;

    final nowMinuteStart = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );
    final nextDepartureEpochMs = nextBoardable == null
        ? null
        : nowMinuteStart
              .add(Duration(minutes: nextBoardable.waitMinutes))
              .millisecondsSinceEpoch;

    final reportService = snapshot.nextService;
    final isDistinctOverdueReportSession =
        reportService != null &&
        reportService.isOverdue &&
        reportService.trainNo != nextBoardable?.trainNo &&
        state.report.isActionVisible;

    final expectedNextTripId = nextBoardable == null
        ? null
        : EdgeHmacClient.toCanonicalTripId(
            directionId: selection.direction,
            trainNo: nextBoardable.trainNo,
          );
    final expectedReportTripId = isDistinctOverdueReportSession
        ? EdgeHmacClient.toCanonicalTripId(
            directionId: selection.direction,
            trainNo: reportService.trainNo,
          )
        : null;

    final overlay = state.community.overlay;
    final overlayMatchesReportService =
        expectedReportTripId != null &&
        overlay != null &&
        overlay.tripId == expectedReportTripId;

    final isAlreadyReported =
        state.report.hasReportedCurrentSession ||
        state.report.status == RailReportSubmissionStatus.success;
    final serverReportingAvailable =
        isDistinctOverdueReportSession &&
        overlayMatchesReportService &&
        overlay.isReportingAvailable &&
        state.report.submitEnabled &&
        !isAlreadyReported;

    final String? reportStatusLabel;
    if (!isDistinctOverdueReportSession) {
      reportStatusLabel = null;
    } else if (isAlreadyReported) {
      reportStatusLabel = 'Arrival reported';
    } else if (serverReportingAvailable) {
      reportStatusLabel = 'Report arrival';
    } else {
      reportStatusLabel = 'Reporting unavailable';
    }

    String? communityTripId;
    int? communityTrainNo;
    String? communityStatusLabel;
    String? communityFreshness;

    final insightStatus = state.community.insightStatus;
    final isUsableInsight =
        insightStatus == RailCommunityInsightStatus.ready ||
        insightStatus == RailCommunityInsightStatus.stale;

    if (overlay != null &&
        overlay.tripId.isNotEmpty &&
        isUsableInsight &&
        overlay.freshnessState != CommunityOverlayFreshness.expired) {
      int? matchedTrainNo;
      if (expectedNextTripId != null && overlay.tripId == expectedNextTripId) {
        matchedTrainNo = nextBoardable?.trainNo;
      } else if (expectedReportTripId != null &&
          overlay.tripId == expectedReportTripId) {
        matchedTrainNo = reportService?.trainNo;
      }

      if (matchedTrainNo != null) {
        final isFresh =
            insightStatus == RailCommunityInsightStatus.ready &&
            overlay.freshnessState == CommunityOverlayFreshness.fresh;
        communityTripId = overlay.tripId;
        communityTrainNo = matchedTrainNo;
        communityFreshness = isFresh ? 'fresh' : 'stale';
        final freshnessPrefix = isFresh ? 'Live' : 'Stale';
        final delayText = _formatDelayText(overlay);
        communityStatusLabel =
            '$freshnessPrefix · Train #$matchedTrainNo $delayText';
      }
    }

    final updatedTime24 =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return RailWidgetPayload(
      schemaVersion: currentSchemaVersion,
      direction: selection.direction,
      boardingStationId: selection.boardingStationId,
      boardingStationName: snapshot.selectedStationName,
      destinationStationId: selection.destinationStationId,
      destinationStationName: snapshot.destinationStationName,
      hasNextTrain: nextBoardable != null,
      nextTrainNo: nextBoardable?.trainNo,
      nextDepartureTime: nextBoardable == null
          ? null
          : RailBoardCopy.formatTimeAmPm(nextBoardable.departureTime),
      nextArrivalTime: nextBoardable == null
          ? null
          : RailBoardCopy.formatTimeAmPm(nextBoardable.arrivalTime),
      nextDepartureEpochMs: nextDepartureEpochMs,
      nextServicePeriod: nextBoardable == null
          ? null
          : RailBoardCopy.getServicePeriodLabel(nextBoardable.servicePeriod),
      hasReportTarget: isDistinctOverdueReportSession,
      reportTrainNo: isDistinctOverdueReportSession
          ? reportService.trainNo
          : null,
      reportScheduledDeparture: isDistinctOverdueReportSession
          ? RailBoardCopy.formatTimeAmPm(reportService.departureTime)
          : null,
      reportOverdueMinutes: isDistinctOverdueReportSession
          ? reportService.overdueMinutes
          : null,
      isReportingAvailable: serverReportingAvailable,
      reportStatusLabel: reportStatusLabel,
      communityTripId: communityTripId,
      communityTrainNo: communityTrainNo,
      communityStatusLabel: communityStatusLabel,
      communityFreshness: communityFreshness,
      scheduleVersion: snapshot.scheduleVersion,
      updatedAtEpochMs: now.millisecondsSinceEpoch,
      updatedAtLabel: 'Updated ${RailBoardCopy.formatTimeAmPm(updatedTime24)}',
    );
  }

  static String _formatDelayText(CommunityOverlay overlay) {
    final isDelayed =
        overlay.delayStatus == DelayStatus.minorDelay ||
        overlay.delayStatus == DelayStatus.majorDelay ||
        overlay.delayStatus == DelayStatus.severeDelay ||
        overlay.delayMinutes > 0;
    if (isDelayed) {
      final minutesSuffix = overlay.delayMinutes > 0
          ? ' ${overlay.delayMinutes}m'
          : '';
      return 'Delayed$minutesSuffix';
    }
    if (overlay.delayStatus == DelayStatus.early || overlay.delayMinutes < 0) {
      final minutesSuffix = overlay.delayMinutes < 0
          ? ' ${overlay.delayMinutes.abs()}m'
          : '';
      return 'Early$minutesSuffix';
    }
    return 'On time';
  }

  bool hasSameContent(RailWidgetPayload other) {
    return schemaVersion == other.schemaVersion &&
        direction == other.direction &&
        boardingStationId == other.boardingStationId &&
        boardingStationName == other.boardingStationName &&
        destinationStationId == other.destinationStationId &&
        destinationStationName == other.destinationStationName &&
        hasNextTrain == other.hasNextTrain &&
        nextTrainNo == other.nextTrainNo &&
        nextDepartureTime == other.nextDepartureTime &&
        nextArrivalTime == other.nextArrivalTime &&
        nextDepartureEpochMs == other.nextDepartureEpochMs &&
        nextServicePeriod == other.nextServicePeriod &&
        hasReportTarget == other.hasReportTarget &&
        reportTrainNo == other.reportTrainNo &&
        reportScheduledDeparture == other.reportScheduledDeparture &&
        isReportingAvailable == other.isReportingAvailable &&
        reportStatusLabel == other.reportStatusLabel &&
        communityTripId == other.communityTripId &&
        communityTrainNo == other.communityTrainNo &&
        communityStatusLabel == other.communityStatusLabel &&
        communityFreshness == other.communityFreshness &&
        scheduleVersion == other.scheduleVersion;
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'direction': direction,
      'boardingStationId': boardingStationId,
      'boardingStationName': boardingStationName,
      'destinationStationId': destinationStationId,
      'destinationStationName': destinationStationName,
      'hasNextTrain': hasNextTrain,
      'nextTrainNo': nextTrainNo,
      'nextDepartureTime': nextDepartureTime,
      'nextArrivalTime': nextArrivalTime,
      'nextDepartureEpochMs': nextDepartureEpochMs,
      'nextServicePeriod': nextServicePeriod,
      'hasReportTarget': hasReportTarget,
      'reportTrainNo': reportTrainNo,
      'reportScheduledDeparture': reportScheduledDeparture,
      'reportOverdueMinutes': reportOverdueMinutes,
      'isReportingAvailable': isReportingAvailable,
      'reportStatusLabel': reportStatusLabel,
      'communityTripId': communityTripId,
      'communityTrainNo': communityTrainNo,
      'communityStatusLabel': communityStatusLabel,
      'communityFreshness': communityFreshness,
      'scheduleVersion': scheduleVersion,
      'updatedAtEpochMs': updatedAtEpochMs,
      'updatedAtLabel': updatedAtLabel,
    };
  }

  String toJsonString() => jsonEncode(toMap());

  static RailWidgetPayload? tryParseJson(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final schemaVersion = (decoded['schemaVersion'] as num?)?.toInt();
      if (schemaVersion != currentSchemaVersion) {
        return null;
      }
      final direction = decoded['direction'] as String? ?? '';
      final boardingStationId = decoded['boardingStationId'] as String? ?? '';
      final boardingStationName =
          decoded['boardingStationName'] as String? ?? '';
      final destinationStationId =
          decoded['destinationStationId'] as String? ?? '';
      final destinationStationName =
          decoded['destinationStationName'] as String? ?? '';
      if (direction.isEmpty ||
          boardingStationId.isEmpty ||
          boardingStationName.isEmpty ||
          destinationStationId.isEmpty ||
          destinationStationName.isEmpty) {
        return null;
      }
      return RailWidgetPayload(
        schemaVersion: schemaVersion!,
        direction: direction,
        boardingStationId: boardingStationId,
        boardingStationName: boardingStationName,
        destinationStationId: destinationStationId,
        destinationStationName: destinationStationName,
        hasNextTrain: decoded['hasNextTrain'] as bool? ?? false,
        nextTrainNo: (decoded['nextTrainNo'] as num?)?.toInt(),
        nextDepartureTime: decoded['nextDepartureTime'] as String?,
        nextArrivalTime: decoded['nextArrivalTime'] as String?,
        nextDepartureEpochMs: (decoded['nextDepartureEpochMs'] as num?)
            ?.toInt(),
        nextServicePeriod: decoded['nextServicePeriod'] as String?,
        hasReportTarget: decoded['hasReportTarget'] as bool? ?? false,
        reportTrainNo: (decoded['reportTrainNo'] as num?)?.toInt(),
        reportScheduledDeparture:
            decoded['reportScheduledDeparture'] as String?,
        reportOverdueMinutes: (decoded['reportOverdueMinutes'] as num?)
            ?.toInt(),
        isReportingAvailable: decoded['isReportingAvailable'] as bool? ?? false,
        reportStatusLabel: decoded['reportStatusLabel'] as String?,
        communityTripId: decoded['communityTripId'] as String?,
        communityTrainNo: (decoded['communityTrainNo'] as num?)?.toInt(),
        communityStatusLabel: decoded['communityStatusLabel'] as String?,
        communityFreshness: decoded['communityFreshness'] as String?,
        scheduleVersion: decoded['scheduleVersion'] as String? ?? '',
        updatedAtEpochMs: (decoded['updatedAtEpochMs'] as num?)?.toInt() ?? 0,
        updatedAtLabel: decoded['updatedAtLabel'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    direction,
    boardingStationId,
    boardingStationName,
    destinationStationId,
    destinationStationName,
    hasNextTrain,
    nextTrainNo,
    nextDepartureTime,
    nextArrivalTime,
    nextDepartureEpochMs,
    nextServicePeriod,
    hasReportTarget,
    reportTrainNo,
    reportScheduledDeparture,
    reportOverdueMinutes,
    isReportingAvailable,
    reportStatusLabel,
    communityTripId,
    communityTrainNo,
    communityStatusLabel,
    communityFreshness,
    scheduleVersion,
    updatedAtEpochMs,
    updatedAtLabel,
  ];
}
