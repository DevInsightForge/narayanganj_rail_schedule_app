import 'package:equatable/equatable.dart';

import 'rail_direction.dart';

class RailStation extends Equatable {
  const RailStation({required this.id, required this.code, required this.name});

  final String id;
  final String code;
  final String name;

  @override
  List<Object> get props => [id, code, name];
}

class RailTrip extends Equatable {
  const RailTrip({
    required this.id,
    required this.directionId,
    required this.trainNo,
    required this.servicePeriod,
    required this.stopTimes,
  });

  final String id;
  final String directionId;
  final int trainNo;
  final String servicePeriod;
  final List<String> stopTimes;

  @override
  List<Object> get props => [
    id,
    directionId,
    trainNo,
    servicePeriod,
    stopTimes,
  ];
}

class RailSchedule extends Equatable {
  const RailSchedule({
    required this.stations,
    required this.directions,
    required this.trips,
  });

  final List<RailStation> stations;
  final List<RailDirection> directions;
  final List<RailTrip> trips;

  @override
  List<Object> get props => [stations, directions, trips];
}
