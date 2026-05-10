import 'package:equatable/equatable.dart';

import 'delay_status.dart';
import 'report_confidence.dart';

class StationAggregateBucket extends Equatable {
  const StationAggregateBucket({
    required this.stationId,
    required this.sequence,
    required this.scheduledAt,
    required this.firstObservedAt,
    required this.lastObservedAt,
    required this.lastSubmittedAt,
    required this.submissionCount,
    required this.delayMinutes,
  });

  final String stationId;
  final int sequence;
  final DateTime scheduledAt;
  final DateTime firstObservedAt;
  final DateTime lastObservedAt;
  final DateTime lastSubmittedAt;
  final int submissionCount;
  final int delayMinutes;

  StationAggregateBucket copyWith({
    String? stationId,
    int? sequence,
    DateTime? scheduledAt,
    DateTime? firstObservedAt,
    DateTime? lastObservedAt,
    DateTime? lastSubmittedAt,
    int? submissionCount,
    int? delayMinutes,
  }) {
    return StationAggregateBucket(
      stationId: stationId ?? this.stationId,
      sequence: sequence ?? this.sequence,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      firstObservedAt: firstObservedAt ?? this.firstObservedAt,
      lastObservedAt: lastObservedAt ?? this.lastObservedAt,
      lastSubmittedAt: lastSubmittedAt ?? this.lastSubmittedAt,
      submissionCount: submissionCount ?? this.submissionCount,
      delayMinutes: delayMinutes ?? this.delayMinutes,
    );
  }

  @override
  List<Object?> get props => [
    stationId,
    sequence,
    scheduledAt,
    firstObservedAt,
    lastObservedAt,
    lastSubmittedAt,
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
