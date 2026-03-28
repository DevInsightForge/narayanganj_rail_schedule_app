import '../entities/arrival_report.dart';

abstract class ArrivalReportRepository {
  Future<void> submitArrivalReport(ArrivalReport report);

  Future<List<ArrivalReport>> fetchStopReports({
    required String sessionId,
    required String stationId,
  });
}
