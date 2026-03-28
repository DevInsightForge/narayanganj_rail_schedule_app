import '../../../domain/entities/arrival_report.dart';
import '../../../domain/repositories/arrival_report_repository.dart';

class ResilientArrivalReportRepository implements ArrivalReportRepository {
  ResilientArrivalReportRepository({
    required ArrivalReportRepository primary,
    required ArrivalReportRepository fallback,
  }) : _primary = primary,
       _fallback = fallback;

  final ArrivalReportRepository _primary;
  final ArrivalReportRepository _fallback;

  @override
  Future<List<ArrivalReport>> fetchStopReports({
    required String sessionId,
    required String stationId,
  }) async {
    try {
      final remote = await _primary.fetchStopReports(
        sessionId: sessionId,
        stationId: stationId,
      );
      final local = await _fallback.fetchStopReports(
        sessionId: sessionId,
        stationId: stationId,
      );
      if (remote.isEmpty) {
        return local;
      }
      return [...remote, ...local];
    } catch (_) {
      return _fallback.fetchStopReports(
        sessionId: sessionId,
        stationId: stationId,
      );
    }
  }

  @override
  Future<void> submitArrivalReport(ArrivalReport report) async {
    await _fallback.submitArrivalReport(report);
    try {
      await _primary.submitArrivalReport(report);
    } catch (_) {}
  }
}
