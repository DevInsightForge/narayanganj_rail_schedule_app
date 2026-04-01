import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/community_session_aggregate.dart';
import '../../domain/entities/data_origin.dart';
import '../../domain/entities/delay_status.dart';
import '../../domain/entities/predicted_stop_time.dart';
import '../../domain/entities/report_confidence.dart';
import '../../domain/entities/train_session.dart';
import '../models/firestore_models.dart';

class FirestoreCommunityMapper {
  const FirestoreCommunityMapper();

  TrainSession toSession(FirestoreSessionModel model) {
    final serviceDate = _parseServiceDate(model.serviceDate);
    return TrainSession(
      sessionId: model.sessionId,
      templateId: model.templateId,
      routeId: model.routeId,
      directionId: model.directionId,
      trainNo: model.trainNo,
      serviceDate: serviceDate,
      stops: model.stops
          .map(
            (stop) => SessionStop(
              stationId: stop.stationId,
              stationName: stop.stationName,
              sequence: stop.sequence,
              scheduledAt: stop.scheduledAt.toDate(),
            ),
          )
          .toList(growable: false),
    );
  }

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
      lastObservedAt: model.lastObservedAt?.toDate(),
      delayMinutes: model.delayMinutes,
      delayStatus: _parseDelayStatus(model.delayStatus),
      confidence: _readAggregateConfidence(model.confidence),
      freshnessSeconds: model.freshnessSeconds,
      stationBuckets: model.stationBuckets.values
          .map(toStationAggregateBucket)
          .toList(growable: false),
    );
  }

  FirestoreSessionAggregateModel toFirestoreSessionAggregate(
    CommunitySessionAggregate aggregate,
  ) {
    return FirestoreSessionAggregateModel(
      sessionId: aggregate.sessionId,
      routeId: aggregate.routeId,
      directionId: aggregate.directionId,
      trainNo: aggregate.trainNo,
      serviceDate: _dateKey(aggregate.serviceDate),
      updatedAt: _toTimestamp(aggregate.updatedAt),
      lastObservedAt: aggregate.lastObservedAt == null
          ? null
          : _toTimestamp(aggregate.lastObservedAt!),
      delayMinutes: aggregate.delayMinutes,
      delayStatus: aggregate.delayStatus.name,
      confidence: _writeAggregateConfidence(aggregate.confidence),
      freshnessSeconds: aggregate.freshnessSeconds,
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
      stationName: model.stationName,
      sequence: model.sequence,
      scheduledAt: model.scheduledAt.toDate(),
      firstObservedAt: model.firstObservedAt.toDate(),
      lastObservedAt: model.lastObservedAt.toDate(),
      firstSubmittedAt: model.firstSubmittedAt.toDate(),
      lastSubmittedAt: model.lastSubmittedAt.toDate(),
      latestReportId: model.latestReportId,
      latestDeviceId: model.latestDeviceId,
      submissionCount: model.submissionCount,
      delayMinutes: model.delayMinutes,
    );
  }

  FirestoreStationAggregateBucketModel toFirestoreStationAggregateBucket(
    StationAggregateBucket bucket,
  ) {
    return FirestoreStationAggregateBucketModel(
      stationId: bucket.stationId,
      stationName: bucket.stationName,
      sequence: bucket.sequence,
      scheduledAt: _toTimestamp(bucket.scheduledAt),
      firstObservedAt: _toTimestamp(bucket.firstObservedAt),
      lastObservedAt: _toTimestamp(bucket.lastObservedAt),
      firstSubmittedAt: _toTimestamp(bucket.firstSubmittedAt),
      lastSubmittedAt: _toTimestamp(bucket.lastSubmittedAt),
      latestReportId: bucket.latestReportId,
      latestDeviceId: bucket.latestDeviceId,
      submissionCount: bucket.submissionCount,
      delayMinutes: bucket.delayMinutes,
    );
  }

  PredictedStopTime toPredictedStop(FirestorePredictedStopModel model) {
    final confidenceScore = model.confidence.toDouble().clamp(0.0, 1.0);
    return PredictedStopTime(
      sessionId: model.sessionId,
      stationId: model.stationId,
      predictedAt: model.predictedAt.toDate(),
      referenceStationId: model.referenceStationId,
      origin: DataOrigin.inferred,
      confidence: ReportConfidence(
        score: confidenceScore,
        sampleSize: 0,
        freshnessSeconds: model.freshnessSeconds,
        agreementScore: confidenceScore,
      ),
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

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
