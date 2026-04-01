import '../../../domain/entities/arrival_report.dart';
import '../../../domain/repositories/arrival_report_repository.dart';

class NoOpArrivalReportRepository implements ArrivalReportRepository {
  const NoOpArrivalReportRepository();

  @override
  Future<List<ArrivalReport>> fetchStopReports({
    required String sessionId,
    required String stationId,
  }) async {
    return const <ArrivalReport>[];
  }

  @override
  Future<void> submitArrivalReport(ArrivalReport report) async {}
}
