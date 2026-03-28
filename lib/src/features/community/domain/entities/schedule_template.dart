import 'package:equatable/equatable.dart';

class StationStop extends Equatable {
  const StationStop({
    required this.stationId,
    required this.stationName,
    required this.sequence,
    required this.scheduledTime,
  });

  final String stationId;
  final String stationName;
  final int sequence;
  final String scheduledTime;

  @override
  List<Object> get props => [stationId, stationName, sequence, scheduledTime];
}

class ScheduleTemplate extends Equatable {
  const ScheduleTemplate({
    required this.templateId,
    required this.routeId,
    required this.directionId,
    required this.trainNo,
    required this.servicePeriod,
    required this.stops,
  });

  final String templateId;
  final String routeId;
  final String directionId;
  final int trainNo;
  final String servicePeriod;
  final List<StationStop> stops;

  @override
  List<Object> get props => [
    templateId,
    routeId,
    directionId,
    trainNo,
    servicePeriod,
    stops,
  ];
}
