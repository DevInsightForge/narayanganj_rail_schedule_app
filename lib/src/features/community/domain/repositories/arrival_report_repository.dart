import '../entities/arrival_report_submission.dart';
import '../entities/arrival_report.dart';
import '../entities/community_session_aggregate.dart';

enum ArrivalReportRepositoryErrorCode {
  permissionDenied,
  stationCapacityReached,
  unknown,
}

class ArrivalReportRepositoryException implements Exception {
  const ArrivalReportRepositoryException(this.code);

  final ArrivalReportRepositoryErrorCode code;
}

abstract class ArrivalReportRepository {
  Future<CommunitySessionAggregate> submitArrivalReport(
    ArrivalReportSubmission submission,
  );

  Future<List<ArrivalReport>> fetchStopReports({
    required String sessionId,
    required DateTime serviceDate,
    required String stationId,
  });

  Future<int> fetchStationSubmissionCount({
    required String sessionId,
    required DateTime serviceDate,
    required String stationId,
  });
}
