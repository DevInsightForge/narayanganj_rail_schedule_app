import 'package:equatable/equatable.dart';

class SessionStop extends Equatable {
  const SessionStop({
    required this.stationId,
    required this.stationName,
    required this.sequence,
    required this.scheduledAt,
  });

  final String stationId;
  final String stationName;
  final int sequence;
  final DateTime scheduledAt;

  @override
  List<Object> get props => [stationId, stationName, sequence, scheduledAt];
}

class TrainSession extends Equatable {
  const TrainSession({
    required this.sessionId,
    required this.templateId,
    required this.routeId,
    required this.directionId,
    required this.trainNo,
    required this.serviceDate,
    required this.stops,
  });

  final String sessionId;
  final String templateId;
  final String routeId;
  final String directionId;
  final int trainNo;
  final DateTime serviceDate;
  final List<SessionStop> stops;

  DateTime get departureAt => stops.first.scheduledAt;
  DateTime get arrivalAt => stops.last.scheduledAt;

  @override
  List<Object> get props => [
    sessionId,
    templateId,
    routeId,
    directionId,
    trainNo,
    serviceDate,
    stops,
  ];
}
