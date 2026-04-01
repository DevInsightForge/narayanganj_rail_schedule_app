import '../entities/arrival_report_submission.dart';
import '../entities/arrival_report.dart';

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
  Future<void> submitArrivalReport(ArrivalReportSubmission submission);

  Future<List<ArrivalReport>> fetchStopReports({
    required String sessionId,
    required String stationId,
  });

  Future<int> fetchStationSubmissionCount({
    required String sessionId,
    required String stationId,
  });
}
