class RemoteSchedulePayload {
  const RemoteSchedulePayload({
    required this.sourceLabel,
    required this.document,
  });

  final String sourceLabel;
  final Map<String, dynamic> document;
}

abstract class ScheduleRemoteSource {
  Future<RemoteSchedulePayload?> fetchSchedule();
}
