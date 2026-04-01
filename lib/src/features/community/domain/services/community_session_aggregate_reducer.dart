import '../entities/arrival_report_submission.dart';
import '../entities/community_session_aggregate.dart';
import '../entities/delay_status.dart';
import '../entities/report_confidence.dart';
import '../entities/train_session.dart';

class CommunitySessionAggregateReducer {
  const CommunitySessionAggregateReducer({this.maxSubmissionsPerStation = 10});

  final int maxSubmissionsPerStation;

  CommunitySessionAggregate reduce({
    CommunitySessionAggregate? current,
    required ArrivalReportSubmission submission,
    required DateTime now,
  }) {
    final session = submission.session;
    final stationStop = submission.stationStop;
    final observedAt = submission.report.observedArrivalAt;
    final submittedAt = submission.report.submittedAt;
    final delayMinutes = observedAt
        .difference(stationStop.scheduledAt)
        .inMinutes;
    final nextBucket = _updateBucket(
      current?.bucketForStation(stationStop.stationId),
      reportId: submission.report.reportId,
      deviceId: submission.report.deviceId,
      stationStop: stationStop,
      observedAt: observedAt,
      submittedAt: submittedAt,
      delayMinutes: delayMinutes,
    );
    final stationBuckets = _mergeBuckets(
      current?.stationBuckets ?? const <StationAggregateBucket>[],
      nextBucket,
    );
    final latestBucket = _latestBucket(stationBuckets);
    final sessionDelayMinutes = latestBucket?.delayMinutes ?? delayMinutes;
    final freshnessSeconds = latestBucket == null
        ? 0
        : now.difference(latestBucket.lastSubmittedAt).inSeconds < 0
        ? 0
        : now.difference(latestBucket.lastSubmittedAt).inSeconds;
    final confidence = _buildConfidence(
      session: session,
      stationBuckets: stationBuckets,
      freshnessSeconds: freshnessSeconds,
    );

    return CommunitySessionAggregate(
      sessionId: session.sessionId,
      routeId: session.routeId,
      directionId: session.directionId,
      trainNo: session.trainNo,
      serviceDate: session.serviceDate,
      updatedAt: now,
      lastObservedAt: latestBucket?.lastObservedAt,
      delayMinutes: sessionDelayMinutes,
      delayStatus: _classifyDelay(sessionDelayMinutes),
      confidence: confidence,
      freshnessSeconds: freshnessSeconds,
      stationBuckets: stationBuckets,
    );
  }

  StationAggregateBucket _updateBucket(
    StationAggregateBucket? existing, {
    required String reportId,
    required String deviceId,
    required SessionStop stationStop,
    required DateTime observedAt,
    required DateTime submittedAt,
    required int delayMinutes,
  }) {
    if (existing == null) {
      return StationAggregateBucket(
        stationId: stationStop.stationId,
        stationName: stationStop.stationName,
        sequence: stationStop.sequence,
        scheduledAt: stationStop.scheduledAt,
        firstObservedAt: observedAt,
        lastObservedAt: observedAt,
        firstSubmittedAt: submittedAt,
        lastSubmittedAt: submittedAt,
        latestReportId: reportId,
        latestDeviceId: deviceId,
        submissionCount: 1,
        delayMinutes: delayMinutes,
      );
    }

    if (existing.submissionCount >= maxSubmissionsPerStation) {
      throw StateError('station_submission_capacity_reached');
    }

    return existing.copyWith(
      lastObservedAt: observedAt,
      lastSubmittedAt: submittedAt,
      latestReportId: reportId,
      latestDeviceId: deviceId,
      submissionCount: existing.submissionCount + 1,
      delayMinutes: delayMinutes,
    );
  }

  List<StationAggregateBucket> _mergeBuckets(
    List<StationAggregateBucket> current,
    StationAggregateBucket nextBucket,
  ) {
    final buckets = <StationAggregateBucket>[];
    var replaced = false;
    for (final bucket in current) {
      if (bucket.stationId == nextBucket.stationId) {
        buckets.add(nextBucket);
        replaced = true;
      } else {
        buckets.add(bucket);
      }
    }
    if (!replaced) {
      buckets.add(nextBucket);
    }
    buckets.sort((a, b) {
      final sequenceComparison = a.sequence.compareTo(b.sequence);
      if (sequenceComparison != 0) {
        return sequenceComparison;
      }
      return a.stationId.compareTo(b.stationId);
    });
    return buckets;
  }

  StationAggregateBucket? _latestBucket(List<StationAggregateBucket> buckets) {
    if (buckets.isEmpty) {
      return null;
    }
    var latest = buckets.first;
    for (final bucket in buckets.skip(1)) {
      if (bucket.sequence > latest.sequence ||
          (bucket.sequence == latest.sequence &&
              bucket.lastSubmittedAt.isAfter(latest.lastSubmittedAt))) {
        latest = bucket;
      }
    }
    return latest;
  }

  ReportConfidence _buildConfidence({
    required TrainSession session,
    required List<StationAggregateBucket> stationBuckets,
    required int freshnessSeconds,
  }) {
    if (stationBuckets.isEmpty) {
      return const ReportConfidence(
        score: 0,
        sampleSize: 0,
        freshnessSeconds: 0,
        agreementScore: 0,
      );
    }

    final totalStops = session.stops.length;
    final coverage = totalStops == 0 ? 0.0 : stationBuckets.length / totalStops;
    final delays = stationBuckets.map((bucket) => bucket.delayMinutes).toList();
    final minDelay = delays.reduce((a, b) => a < b ? a : b);
    final maxDelay = delays.reduce((a, b) => a > b ? a : b);
    final spread = maxDelay - minDelay;
    final agreementScore = 1 / (1 + (spread.abs() / 10));
    final score = (coverage * 0.7) + (agreementScore * 0.3);

    return ReportConfidence(
      score: score.clamp(0.0, 1.0).toDouble(),
      sampleSize: stationBuckets.fold<int>(
        0,
        (count, bucket) => count + bucket.submissionCount,
      ),
      freshnessSeconds: freshnessSeconds,
      agreementScore: agreementScore.clamp(0.0, 1.0).toDouble(),
    );
  }

  DelayStatus _classifyDelay(int delayMinutes) {
    if (delayMinutes > 0) {
      return DelayStatus.late;
    }
    if (delayMinutes < 0) {
      return DelayStatus.early;
    }
    return DelayStatus.onTime;
  }
}
