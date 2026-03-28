import '../../../domain/entities/arrival_report.dart';
import '../../../domain/repositories/arrival_report_repository.dart';

class FakeArrivalReportRepository implements ArrivalReportRepository {
  FakeArrivalReportRepository({List<ArrivalReport> seed = const []})
    : _reports = List<ArrivalReport>.from(seed);

  final List<ArrivalReport> _reports;

  @override
  Future<List<ArrivalReport>> fetchStopReports({
    required String sessionId,
    required String stationId,
  }) async {
    return _reports
        .where(
          (report) =>
              report.sessionId == sessionId && report.stationId == stationId,
        )
        .toList(growable: false);
  }

  @override
  Future<void> submitArrivalReport(ArrivalReport report) async {
    _reports.add(report);
  }
}
