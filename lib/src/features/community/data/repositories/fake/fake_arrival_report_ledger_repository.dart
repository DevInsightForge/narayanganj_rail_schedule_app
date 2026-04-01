import '../../../domain/repositories/arrival_report_ledger_repository.dart';

class FakeArrivalReportLedgerRepository
    implements ArrivalReportLedgerRepository {
  static const _entryTtl = Duration(hours: 18);
  final Map<String, DateTime> _entries = <String, DateTime>{};

  @override
  Future<bool> hasSubmitted({
    required String sessionId,
    required String stationId,
    required String deviceId,
    DateTime? now,
  }) async {
    if (now != null) {
      _pruneExpiredEntries(now);
    }
    return _entries.containsKey(_key(sessionId, stationId, deviceId));
  }

  @override
  Future<void> markSubmitted({
    required String sessionId,
    required String stationId,
    required String deviceId,
    required DateTime submittedAt,
  }) async {
    _pruneExpiredEntries(submittedAt);
    _entries[_key(sessionId, stationId, deviceId)] = submittedAt;
  }

  void _pruneExpiredEntries(DateTime now) {
    final cutoff = now.subtract(_entryTtl);
    _entries.removeWhere((_, submittedAt) => submittedAt.isBefore(cutoff));
  }

  String _key(String sessionId, String stationId, String deviceId) {
    return '$sessionId::$stationId::$deviceId';
  }
}
