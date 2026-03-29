import '../../../domain/repositories/arrival_report_ledger_repository.dart';

class FakeArrivalReportLedgerRepository implements ArrivalReportLedgerRepository {
  final Map<String, DateTime> _entries = <String, DateTime>{};

  @override
  Future<bool> hasSubmitted({
    required String sessionId,
    required String stationId,
    required String deviceId,
  }) async {
    return _entries.containsKey(_key(sessionId, stationId, deviceId));
  }

  @override
  Future<void> markSubmitted({
    required String sessionId,
    required String stationId,
    required String deviceId,
    required DateTime submittedAt,
  }) async {
    _entries[_key(sessionId, stationId, deviceId)] = submittedAt;
  }

  String _key(String sessionId, String stationId, String deviceId) {
    return '$sessionId::$stationId::$deviceId';
  }
}
