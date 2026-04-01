class ErrorReportContext {
  const ErrorReportContext({
    this.feature,
    this.event,
    this.sessionId,
    this.stationId,
    this.uid,
    this.attemptId,
    this.extra = const <String, Object?>{},
  });

  final String? feature;
  final String? event;
  final String? sessionId;
  final String? stationId;
  final String? uid;
  final String? attemptId;
  final Map<String, Object?> extra;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (feature != null) 'feature': feature,
      if (event != null) 'event': event,
      if (sessionId != null) 'sessionId': sessionId,
      if (stationId != null) 'stationId': stationId,
      if (uid != null) 'uid': uid,
      if (attemptId != null) 'attemptId': attemptId,
      ...extra,
    };
  }
}
