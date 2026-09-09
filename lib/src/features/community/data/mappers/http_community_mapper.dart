import '../../domain/entities/community_session_aggregate.dart';
import '../../domain/entities/data_origin.dart';
import '../../domain/entities/delay_status.dart';
import '../../domain/entities/predicted_stop_time.dart';
import '../../domain/entities/report_confidence.dart';
import '../../domain/entities/session_status_snapshot.dart';

class HttpCommunityMapper {
  const HttpCommunityMapper();

  SessionStatusSnapshot? toSessionStatusSnapshot(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return null;
    }

    final sessionId =
        (json['sessionId'] ?? json['session_id'])?.toString() ?? '';
    final delayMinutes =
        ((json['delayMinutes'] ?? json['delay_minutes']) as num?)?.toInt() ?? 0;
    final delayStatus = _parseDelayStatus(json['status']?.toString() ?? '');

    double confidenceScore = 0.0;
    final confidenceRaw = json['confidence'];
    if (confidenceRaw is num) {
      confidenceScore = confidenceRaw.toDouble();
    } else if (confidenceRaw is Map) {
      confidenceScore = (confidenceRaw['score'] as num?)?.toDouble() ?? 0.0;
    }

    final freshnessSeconds =
        ((json['freshnessSeconds'] ?? json['freshness_seconds']) as num?)
            ?.toInt() ??
        (confidenceRaw is Map
            ? (confidenceRaw['freshnessSeconds'] as num?)?.toInt() ?? 0
            : 0);

    final updatedAtRaw = (json['updatedAt'] ?? json['updated_at'])?.toString();
    final updatedAt = updatedAtRaw != null
        ? DateTime.tryParse(updatedAtRaw)
        : null;

    final stationsRaw = json['stations'] ?? json['station_buckets'];
    final sampleSize =
        (confidenceRaw is Map
            ? (confidenceRaw['sampleSize'] as num?)?.toInt()
            : null) ??
        ((stationsRaw as Map?)?.length ?? 1);

    final confidence = ReportConfidence(
      score: confidenceScore,
      sampleSize: sampleSize,
      freshnessSeconds: freshnessSeconds,
      agreementScore: 1.0,
    );

    return SessionStatusSnapshot(
      sessionId: sessionId,
      state: SessionLifecycleState.active,
      delayMinutes: delayMinutes,
      delayStatus: delayStatus,
      confidence: confidence,
      freshnessSeconds: freshnessSeconds,
      lastObservedAt: updatedAt,
    );
  }

  List<PredictedStopTime> toPredictedStopTimes(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const [];
    }

    final sessionId = json['sessionId']?.toString() ?? '';
    final predictedStopsRaw = json['predictedStops'] as List<dynamic>?;
    if (predictedStopsRaw == null || predictedStopsRaw.isEmpty) {
      return const [];
    }

    double confidenceScore = 0.0;
    final confidenceRaw = json['confidence'];
    if (confidenceRaw is num) {
      confidenceScore = confidenceRaw.toDouble();
    } else if (confidenceRaw is Map) {
      confidenceScore = (confidenceRaw['score'] as num?)?.toDouble() ?? 0.0;
    }

    final freshnessSeconds =
        (json['freshnessSeconds'] as num?)?.toInt() ??
        (confidenceRaw is Map
            ? (confidenceRaw['freshnessSeconds'] as num?)?.toInt() ?? 0
            : 0);

    final confidence = ReportConfidence(
      score: confidenceScore,
      sampleSize: (predictedStopsRaw.length),
      freshnessSeconds: freshnessSeconds,
      agreementScore: 1.0,
    );

    final result = <PredictedStopTime>[];
    for (final item in predictedStopsRaw) {
      if (item is Map<String, dynamic>) {
        final stationId = item['stationId']?.toString() ?? '';
        final predictedAtRaw = item['predictedAt']?.toString();
        final predictedAt = predictedAtRaw != null
            ? DateTime.tryParse(predictedAtRaw)
            : null;

        if (predictedAt != null && stationId.isNotEmpty) {
          result.add(
            PredictedStopTime(
              sessionId: sessionId,
              stationId: stationId,
              predictedAt: predictedAt,
              referenceStationId: 'dhaka',
              origin: item['origin'] == 'community'
                  ? DataOrigin.community
                  : DataOrigin.inferred,
              confidence: confidence,
            ),
          );
        }
      }
    }

    return result;
  }

  CommunitySessionAggregate toCommunitySessionAggregate({
    required Map<String, dynamic> json,
    required String directionId,
    required int trainNo,
  }) {
    final sessionId =
        (json['sessionId'] ?? json['session_id'])?.toString() ?? '';
    final routeId =
        (json['routeId'] ?? json['route_id'])?.toString() ?? 'narayanganj_line';
    final serviceDateRaw =
        (json['serviceDate'] ?? json['service_date'])?.toString() ?? '';
    final serviceDate = DateTime.tryParse(serviceDateRaw) ?? DateTime.now();
    final delayMinutes =
        ((json['delayMinutes'] ?? json['delay_minutes']) as num?)?.toInt() ?? 0;
    final delayStatus = _parseDelayStatus(json['status']?.toString() ?? '');

    double confidenceScore = 0.0;
    final confidenceRaw = json['confidence'];
    if (confidenceRaw is num) {
      confidenceScore = confidenceRaw.toDouble();
    } else if (confidenceRaw is Map) {
      confidenceScore = (confidenceRaw['score'] as num?)?.toDouble() ?? 0.0;
    }

    final freshnessSeconds =
        ((json['freshnessSeconds'] ?? json['freshness_seconds']) as num?)
            ?.toInt() ??
        (confidenceRaw is Map
            ? (confidenceRaw['freshnessSeconds'] as num?)?.toInt() ?? 0
            : 0);

    final updatedAtRaw = (json['updatedAt'] ?? json['updated_at'])?.toString();
    final updatedAt = updatedAtRaw != null
        ? DateTime.tryParse(updatedAtRaw) ?? DateTime.now()
        : DateTime.now();

    final stationsRaw = json['stations'] ?? json['station_buckets'];
    final stationsMap = stationsRaw is Map<String, dynamic>
        ? stationsRaw
        : <String, dynamic>{};
    final stationBuckets = <StationAggregateBucket>[];

    var sequence = 0;
    for (final entry in stationsMap.entries) {
      if (entry.value is Map<String, dynamic>) {
        final bucketMap = entry.value as Map<String, dynamic>;
        final bucketUpdatedAtRaw =
            (bucketMap['updatedAt'] ?? bucketMap['updated_at'])?.toString();
        final bucketUpdatedAt = bucketUpdatedAtRaw != null
            ? DateTime.tryParse(bucketUpdatedAtRaw) ?? updatedAt
            : updatedAt;

        final reportCount =
            ((bucketMap['reportCount'] ?? bucketMap['report_count']) as num?)
                ?.toInt() ??
            1;
        final bucketDelayMinutes =
            ((bucketMap['delayMinutes'] ?? bucketMap['delay_minutes']) as num?)
                ?.toInt() ??
            delayMinutes;

        stationBuckets.add(
          StationAggregateBucket(
            stationId: entry.key,
            sequence: sequence++,
            scheduledAt: bucketUpdatedAt,
            firstObservedAt: bucketUpdatedAt,
            lastObservedAt: bucketUpdatedAt,
            lastSubmittedAt: bucketUpdatedAt,
            submissionCount: reportCount,
            delayMinutes: bucketDelayMinutes,
          ),
        );
      }
    }

    final confidence = ReportConfidence(
      score: confidenceScore,
      sampleSize: stationBuckets.length,
      freshnessSeconds: freshnessSeconds,
      agreementScore: 1.0,
    );

    return CommunitySessionAggregate(
      sessionId: sessionId,
      routeId: routeId,
      directionId: directionId,
      trainNo: trainNo,
      serviceDate: serviceDate,
      updatedAt: updatedAt,
      lastObservedAt: updatedAt,
      delayMinutes: delayMinutes,
      delayStatus: delayStatus,
      confidence: confidence,
      freshnessSeconds: freshnessSeconds,
      stationBuckets: stationBuckets,
    );
  }

  DelayStatus _parseDelayStatus(String value) {
    return switch (value.toLowerCase()) {
      'delayed' || 'late' => DelayStatus.late,
      'early' => DelayStatus.early,
      _ => DelayStatus.onTime,
    };
  }
}
