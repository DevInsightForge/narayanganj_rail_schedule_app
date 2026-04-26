import '../../../domain/entities/arrival_report.dart';
import '../../../domain/entities/arrival_report_submission.dart';
import '../../../domain/entities/community_session_aggregate.dart';
import '../../../domain/repositories/arrival_report_repository.dart';

class NoOpArrivalReportRepository implements ArrivalReportRepository {
  const NoOpArrivalReportRepository();

  @override
  Future<List<ArrivalReport>> fetchStopReports({
    required String sessionId,
    required DateTime serviceDate,
    required String stationId,
  }) async {
    return const <ArrivalReport>[];
  }

  @override
  Future<int> fetchStationSubmissionCount({
    required String sessionId,
    required DateTime serviceDate,
    required String stationId,
  }) async {
    return 0;
  }

  @override
  Future<CommunitySessionAggregate> submitArrivalReport(
    ArrivalReportSubmission submission,
  ) async {
    throw UnimplementedError();
  }
}
