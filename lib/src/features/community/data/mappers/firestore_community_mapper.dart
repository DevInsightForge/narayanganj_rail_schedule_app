import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/community_session_aggregate.dart';
import '../../domain/entities/delay_status.dart';
import '../../domain/entities/report_confidence.dart';
import '../../domain/services/service_day_key.dart';
import '../models/firestore_models.dart';

class FirestoreCommunityMapper {
  const FirestoreCommunityMapper();

  CommunitySessionAggregate toCommunitySessionAggregate(
    FirestoreSessionAggregateModel model,
  ) {
    return CommunitySessionAggregate(
      sessionId: model.sessionId,
      routeId: model.routeId,
      directionId: model.directionId,
      trainNo: model.trainNo,
      serviceDate: _parseServiceDate(model.serviceDate),
      updatedAt: model.updatedAt.toDate(),
      lastObservedAt: _lastObservedAt(model.stationBuckets.values),
      delayMinutes: model.delayMinutes,
      delayStatus: _parseDelayStatus(model.delayStatus),
      confidence: _readAggregateConfidence(model.confidence),
      freshnessSeconds: _freshnessSeconds(model.updatedAt.toDate()),
      stationBuckets: model.stationBuckets.values
          .map(toStationAggregateBucket)
          .toList(growable: false),
    );
  }

  FirestoreSessionAggregateModel toFirestoreSessionAggregate(
    CommunitySessionAggregate aggregate,
  ) {
    return FirestoreSessionAggregateModel(
      schemaVersion: FirestoreSessionAggregateModel.currentSchemaVersion,
      sessionId: aggregate.sessionId,
      routeId: aggregate.routeId,
      directionId: aggregate.directionId,
      trainNo: aggregate.trainNo,
      serviceDate: serviceDateKey(aggregate.serviceDate),
      updatedAt: _toTimestamp(aggregate.updatedAt),
      lastReportedStationId: _lastReportedStationId(aggregate),
      delayMinutes: aggregate.delayMinutes,
      delayStatus: aggregate.delayStatus.name,
      confidence: _writeAggregateConfidence(aggregate.confidence),
      reportCount: aggregate.reportCount,
      stationCount: aggregate.stationCount,
      stationBuckets: {
        for (final bucket in aggregate.stationBuckets)
          bucket.stationId: toFirestoreStationAggregateBucket(bucket),
      },
    );
  }

  StationAggregateBucket toStationAggregateBucket(
    FirestoreStationAggregateBucketModel model,
  ) {
    return StationAggregateBucket(
      stationId: model.stationId,
      sequence: model.sequence,
      scheduledAt: model.scheduledAt.toDate(),
      firstObservedAt: model.firstObservedAt.toDate(),
      lastObservedAt: model.lastObservedAt.toDate(),
      lastSubmittedAt: model.lastSubmittedAt.toDate(),
      submissionCount: model.submissionCount,
      delayMinutes: model.delayMinutes,
    );
  }

  FirestoreStationAggregateBucketModel toFirestoreStationAggregateBucket(
    StationAggregateBucket bucket,
  ) {
    return FirestoreStationAggregateBucketModel(
      stationId: bucket.stationId,
      sequence: bucket.sequence,
      scheduledAt: _toTimestamp(bucket.scheduledAt),
      firstObservedAt: _toTimestamp(bucket.firstObservedAt),
      lastObservedAt: _toTimestamp(bucket.lastObservedAt),
      lastSubmittedAt: _toTimestamp(bucket.lastSubmittedAt),
      submissionCount: bucket.submissionCount,
      delayMinutes: bucket.delayMinutes,
    );
  }

  DateTime _parseServiceDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  Timestamp _toTimestamp(DateTime value) {
    return Timestamp.fromDate(value);
  }

  ReportConfidence _readAggregateConfidence(Map<String, dynamic> map) {
    return ReportConfidence(
      score: (map['score'] as num?)?.toDouble() ?? 0,
      sampleSize: (map['sampleSize'] as num?)?.toInt() ?? 0,
      freshnessSeconds: (map['freshnessSeconds'] as num?)?.toInt() ?? 0,
      agreementScore: (map['agreementScore'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> _writeAggregateConfidence(ReportConfidence confidence) {
    return <String, dynamic>{
      'score': confidence.score,
      'sampleSize': confidence.sampleSize,
      'freshnessSeconds': confidence.freshnessSeconds,
      'agreementScore': confidence.agreementScore,
    };
  }

  DelayStatus _parseDelayStatus(String value) {
    return switch (value) {
      'early' => DelayStatus.early,
      'late' => DelayStatus.late,
      _ => DelayStatus.onTime,
    };
  }

  DateTime? _lastObservedAt(
    Iterable<FirestoreStationAggregateBucketModel> buckets,
  ) {
    DateTime? latest;
    for (final bucket in buckets) {
      final observedAt = bucket.lastObservedAt.toDate();
      if (latest == null || observedAt.isAfter(latest)) {
        latest = observedAt;
      }
    }
    return latest;
  }

  int _freshnessSeconds(DateTime updatedAt) {
    final seconds = DateTime.now().difference(updatedAt).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  String _lastReportedStationId(CommunitySessionAggregate aggregate) {
    StationAggregateBucket? latest;
    for (final bucket in aggregate.stationBuckets) {
      if (latest == null ||
          bucket.sequence > latest.sequence ||
          (bucket.sequence == latest.sequence &&
              bucket.lastSubmittedAt.isAfter(latest.lastSubmittedAt))) {
        latest = bucket;
      }
    }
    return latest?.stationId ?? '';
  }
}
