import '../../../domain/entities/arrival_report.dart';
import '../../../domain/entities/arrival_report_submission.dart';
import '../../../domain/entities/community_session_aggregate.dart';
import '../../../domain/repositories/arrival_report_repository.dart';
import '../../../domain/services/community_session_aggregate_reducer.dart';

class FakeArrivalReportRepository implements ArrivalReportRepository {
  FakeArrivalReportRepository({List<ArrivalReport> seed = const []})
    : _reports = List<ArrivalReport>.from(seed);

  final List<ArrivalReport> _reports;
  final Map<String, CommunitySessionAggregate> _aggregates =
      <String, CommunitySessionAggregate>{};
  final CommunitySessionAggregateReducer _reducer =
      const CommunitySessionAggregateReducer();

  @override
  Future<List<ArrivalReport>> fetchStopReports({
    required String sessionId,
    required String stationId,
  }) async {
    final aggregate = _aggregates[sessionId];
    if (aggregate == null) {
      return _reports
          .where(
            (report) =>
                report.sessionId == sessionId && report.stationId == stationId,
          )
          .toList(growable: false);
    }
    final bucket = aggregate.bucketForStation(stationId);
    if (bucket == null) {
      return const <ArrivalReport>[];
    }
    return [
      ArrivalReport(
        reportId: bucket.latestReportId,
        sessionId: aggregate.sessionId,
        stationId: bucket.stationId,
        deviceId: bucket.latestDeviceId,
        observedArrivalAt: bucket.lastObservedAt,
        submittedAt: bucket.lastSubmittedAt,
      ),
    ];
  }

  @override
  Future<int> fetchStationSubmissionCount({
    required String sessionId,
    required String stationId,
  }) async {
    return _aggregates[sessionId]
            ?.bucketForStation(stationId)
            ?.submissionCount ??
        0;
  }

  @override
  Future<void> submitArrivalReport(ArrivalReportSubmission submission) async {
    _reports.add(submission.report);
    try {
      _aggregates[submission.session.sessionId] = _reducer.reduce(
        current: _aggregates[submission.session.sessionId],
        submission: submission,
        now: submission.report.submittedAt,
      );
    } on StateError catch (error) {
      _reports.removeLast();
      if (error.message == 'station_submission_capacity_reached') {
        throw const ArrivalReportRepositoryException(
          ArrivalReportRepositoryErrorCode.stationCapacityReached,
        );
      }
      rethrow;
    }
  }

  CommunitySessionAggregate? aggregateForSession(String sessionId) {
    return _aggregates[sessionId];
  }
}
