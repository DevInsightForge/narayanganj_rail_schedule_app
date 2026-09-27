import 'package:equatable/equatable.dart';

class RailSelectableOption extends Equatable {
  const RailSelectableOption({
    required this.value,
    required this.label,
    this.disabled = false,
  });

  final String value;
  final String label;
  final bool disabled;

  @override
  List<Object> get props => [value, label, disabled];
}

class RailStopSnapshot extends Equatable {
  const RailStopSnapshot({
    required this.stationId,
    required this.stationName,
    required this.time,
  });

  final String stationId;
  final String stationName;
  final String time;

  @override
  List<Object> get props => [stationId, stationName, time];
}

class RailServiceSnapshot extends Equatable {
  const RailServiceSnapshot({
    required this.trainNo,
    required this.servicePeriod,
    required this.departureTime,
    required this.arrivalTime,
    required this.waitMinutes,
    required this.etaMinutes,
    required this.stops,
  });

  final int trainNo;
  final String servicePeriod;
  final String departureTime;
  final String arrivalTime;
  final int waitMinutes;
  final int etaMinutes;
  final List<RailStopSnapshot> stops;

  @override
  List<Object> get props => [
    trainNo,
    servicePeriod,
    departureTime,
    arrivalTime,
    waitMinutes,
    etaMinutes,
    stops,
  ];
}

class RailBoardSnapshot extends Equatable {
  const RailBoardSnapshot({
    required this.selectedStationName,
    required this.destinationStationName,
    required this.nextService,
    required this.upcomingServices,
    required this.scheduleVersion,
  });

  final String selectedStationName;
  final String destinationStationName;
  final RailServiceSnapshot? nextService;
  final List<RailServiceSnapshot> upcomingServices;
  final String scheduleVersion;

  RailBoardSnapshot copyWith({
    String? selectedStationName,
    String? destinationStationName,
    RailServiceSnapshot? nextService,
    List<RailServiceSnapshot>? upcomingServices,
    String? scheduleVersion,
  }) {
    return RailBoardSnapshot(
      selectedStationName: selectedStationName ?? this.selectedStationName,
      destinationStationName:
          destinationStationName ?? this.destinationStationName,
      nextService: nextService ?? this.nextService,
      upcomingServices: upcomingServices ?? this.upcomingServices,
      scheduleVersion: scheduleVersion ?? this.scheduleVersion,
    );
  }

  @override
  List<Object?> get props => [
    selectedStationName,
    destinationStationName,
    nextService,
    upcomingServices,
    scheduleVersion,
  ];
}
