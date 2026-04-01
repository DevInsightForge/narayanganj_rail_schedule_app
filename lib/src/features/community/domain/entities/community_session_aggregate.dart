import 'package:equatable/equatable.dart';

import 'delay_status.dart';
import 'report_confidence.dart';

class StationAggregateBucket extends Equatable {
  const StationAggregateBucket({
    required this.stationId,
    required this.stationName,
    required this.sequence,
    required this.scheduledAt,
    required this.firstObservedAt,
    required this.lastObservedAt,
    required this.firstSubmittedAt,
    required this.lastSubmittedAt,
    required this.latestReportId,
    required this.latestDeviceId,
    required this.submissionCount,
    required this.delayMinutes,
  });

  final String stationId;
  final String stationName;
  final int sequence;
  final DateTime scheduledAt;
  final DateTime firstObservedAt;
  final DateTime lastObservedAt;
  final DateTime firstSubmittedAt;
  final DateTime lastSubmittedAt;
  final String latestReportId;
  final String latestDeviceId;
  final int submissionCount;
  final int delayMinutes;

  StationAggregateBucket copyWith({
    String? stationId,
    String? stationName,
    int? sequence,
    DateTime? scheduledAt,
    DateTime? firstObservedAt,
    DateTime? lastObservedAt,
    DateTime? firstSubmittedAt,
    DateTime? lastSubmittedAt,
    String? latestReportId,
    String? latestDeviceId,
    int? submissionCount,
    int? delayMinutes,
  }) {
    return StationAggregateBucket(
      stationId: stationId ?? this.stationId,
      stationName: stationName ?? this.stationName,
      sequence: sequence ?? this.sequence,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      firstObservedAt: firstObservedAt ?? this.firstObservedAt,
      lastObservedAt: lastObservedAt ?? this.lastObservedAt,
      firstSubmittedAt: firstSubmittedAt ?? this.firstSubmittedAt,
      lastSubmittedAt: lastSubmittedAt ?? this.lastSubmittedAt,
      latestReportId: latestReportId ?? this.latestReportId,
      latestDeviceId: latestDeviceId ?? this.latestDeviceId,
      submissionCount: submissionCount ?? this.submissionCount,
      delayMinutes: delayMinutes ?? this.delayMinutes,
    );
  }

  @override
  List<Object?> get props => [
    stationId,
    stationName,
    sequence,
    scheduledAt,
    firstObservedAt,
    lastObservedAt,
    firstSubmittedAt,
    lastSubmittedAt,
    latestReportId,
    latestDeviceId,
    submissionCount,
    delayMinutes,
  ];
}

class CommunitySessionAggregate extends Equatable {
  const CommunitySessionAggregate({
    required this.sessionId,
    required this.routeId,
    required this.directionId,
    required this.trainNo,
    required this.serviceDate,
    required this.updatedAt,
    required this.lastObservedAt,
    required this.delayMinutes,
    required this.delayStatus,
    required this.confidence,
    required this.freshnessSeconds,
    required this.stationBuckets,
  });

  final String sessionId;
  final String routeId;
  final String directionId;
  final int trainNo;
  final DateTime serviceDate;
  final DateTime updatedAt;
  final DateTime? lastObservedAt;
  final int delayMinutes;
  final DelayStatus delayStatus;
  final ReportConfidence confidence;
  final int freshnessSeconds;
  final List<StationAggregateBucket> stationBuckets;

  int get reportCount => stationBuckets.fold<int>(
    0,
    (count, bucket) => count + bucket.submissionCount,
  );

  int get stationCount => stationBuckets.length;

  StationAggregateBucket? bucketForStation(String stationId) {
    for (final bucket in stationBuckets) {
      if (bucket.stationId == stationId) {
        return bucket;
      }
    }
    return null;
  }

  CommunitySessionAggregate copyWith({
    String? sessionId,
    String? routeId,
    String? directionId,
    int? trainNo,
    DateTime? serviceDate,
    DateTime? updatedAt,
    DateTime? lastObservedAt,
    int? delayMinutes,
    DelayStatus? delayStatus,
    ReportConfidence? confidence,
    int? freshnessSeconds,
    List<StationAggregateBucket>? stationBuckets,
    bool clearLastObservedAt = false,
  }) {
    return CommunitySessionAggregate(
      sessionId: sessionId ?? this.sessionId,
      routeId: routeId ?? this.routeId,
      directionId: directionId ?? this.directionId,
      trainNo: trainNo ?? this.trainNo,
      serviceDate: serviceDate ?? this.serviceDate,
      updatedAt: updatedAt ?? this.updatedAt,
      lastObservedAt: clearLastObservedAt
          ? null
          : lastObservedAt ?? this.lastObservedAt,
      delayMinutes: delayMinutes ?? this.delayMinutes,
      delayStatus: delayStatus ?? this.delayStatus,
      confidence: confidence ?? this.confidence,
      freshnessSeconds: freshnessSeconds ?? this.freshnessSeconds,
      stationBuckets: stationBuckets ?? this.stationBuckets,
    );
  }

  @override
  List<Object?> get props => [
    sessionId,
    routeId,
    directionId,
    trainNo,
    serviceDate,
    updatedAt,
    lastObservedAt,
    delayMinutes,
    delayStatus,
    confidence,
    freshnessSeconds,
    stationBuckets,
  ];
}
