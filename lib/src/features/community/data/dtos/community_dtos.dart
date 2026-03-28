class ArrivalReportDto {
  const ArrivalReportDto({
    required this.reportId,
    required this.sessionId,
    required this.stationId,
    required this.deviceId,
    required this.observedArrivalAtIso,
    required this.submittedAtIso,
  });

  final String reportId;
  final String sessionId;
  final String stationId;
  final String deviceId;
  final String observedArrivalAtIso;
  final String submittedAtIso;
}
