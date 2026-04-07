abstract class ArrivalReportLedgerRepository {
  Future<bool> hasSubmitted({
    required String sessionId,
    required DateTime serviceDate,
    required String stationId,
    required String deviceId,
    DateTime? now,
  });

  Future<void> markSubmitted({
    required String sessionId,
    required DateTime serviceDate,
    required String stationId,
    required String deviceId,
    required DateTime submittedAt,
  });
}
