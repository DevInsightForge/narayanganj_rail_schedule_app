import '../entities/arrival_report.dart';

enum ArrivalReportRepositoryErrorCode { permissionDenied, unknown }

class ArrivalReportRepositoryException implements Exception {
  const ArrivalReportRepositoryException(this.code);

  final ArrivalReportRepositoryErrorCode code;
}

abstract class ArrivalReportRepository {
  Future<void> submitArrivalReport(ArrivalReport report);

  Future<List<ArrivalReport>> fetchStopReports({
    required String sessionId,
    required String stationId,
  });
}
