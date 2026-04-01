import 'package:equatable/equatable.dart';

class ArrivalReport extends Equatable {
  const ArrivalReport({
    required this.reportId,
    required this.sessionId,
    required this.stationId,
    required this.deviceId,
    required this.observedArrivalAt,
    required this.submittedAt,
  });

  final String reportId;
  final String sessionId;
  final String stationId;
  final String deviceId;
  final DateTime observedArrivalAt;
  final DateTime submittedAt;

  @override
  List<Object?> get props => [
    reportId,
    sessionId,
    stationId,
    deviceId,
    observedArrivalAt,
    submittedAt,
  ];
}
