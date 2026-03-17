import '../entities/rail_direction.dart';
import '../entities/rail_schedule.dart';
import '../entities/rail_selection.dart';
import '../entities/rail_snapshot.dart';

class RailBoardService {
  RailBoardService({required this.schedule});

  final RailSchedule schedule;

  static const _minutesPerDay = 24 * 60;

  RailSelection createSelection({
    String? direction,
    String? boardingStationId,
    String? destinationStationId,
  }) {
    final resolvedDirection = _isValidDirection(direction)
        ? direction!
        : _defaultDirection();
    final stations = getStationsForDirection(resolvedDirection);
    final resolvedBoardingStationId =
        stations.any((station) => station.id == boardingStationId)
        ? boardingStationId!
        : stations.first.id;
    final downstreamStations = getDownstreamStations(
      direction: resolvedDirection,
      boardingStationId: resolvedBoardingStationId,
    );
    final resolvedDestinationStationId =
        downstreamStations.any((station) => station.id == destinationStationId)
        ? destinationStationId!
        : downstreamStations.first.id;

    return RailSelection(
      direction: resolvedDirection,
      boardingStationId: resolvedBoardingStationId,
      destinationStationId: resolvedDestinationStationId,
    );
  }

  RailSelection changeDirection(String direction) {
    return createSelection(direction: direction);
  }

  RailSelection changeBoardingStation(
    RailSelection selection,
    String boardingStationId,
  ) {
    final stations = getStationsForDirection(selection.direction);
    final boardingIndex = stations.indexWhere(
      (station) => station.id == boardingStationId,
    );

    if (boardingIndex < 0 || boardingIndex >= stations.length - 1) {
      return selection;
    }

    final downstreamStations = stations.sublist(boardingIndex + 1);
    final nextDestinationStationId =
        downstreamStations.any(
          (station) => station.id == selection.destinationStationId,
        )
        ? selection.destinationStationId
        : downstreamStations.first.id;

    return selection.copyWith(
      boardingStationId: boardingStationId,
      destinationStationId: nextDestinationStationId,
    );
  }

  RailSelection changeDestinationStation(
    RailSelection selection,
    String destinationStationId,
  ) {
    final downstreamStations = getDownstreamStations(
      direction: selection.direction,
      boardingStationId: selection.boardingStationId,
    );

    if (!downstreamStations.any(
      (station) => station.id == destinationStationId,
    )) {
      return selection;
    }

    return selection.copyWith(destinationStationId: destinationStationId);
  }

  List<RailSelectableOption> getDirectionOptions() {
    return schedule.directions
        .map(
          (direction) => RailSelectableOption(
            value: direction.directionKey,
            label:
                'From ${getStationsForDirection(direction.directionKey).first.name}',
          ),
        )
        .toList(growable: false);
  }

  List<RailSelectableOption> getBoardingOptions(String direction) {
    final stations = getStationsForDirection(direction);

    return List<RailSelectableOption>.generate(
      stations.length,
      (index) => RailSelectableOption(
        value: stations[index].id,
        label: stations[index].name,
        disabled: index == stations.length - 1,
      ),
      growable: false,
    );
  }

  List<RailSelectableOption> getDestinationOptions(
    String direction,
    String boardingStationId,
  ) {
    final downstreamIds = getDownstreamStations(
      direction: direction,
      boardingStationId: boardingStationId,
    ).map((station) => station.id).toSet();

    return getStationsForDirection(direction)
        .map(
          (station) => RailSelectableOption(
            value: station.id,
            label: station.name,
            disabled: !downstreamIds.contains(station.id),
          ),
        )
        .toList(growable: false);
  }

  RailBoardSnapshot getSnapshot({
    required RailSelection selection,
    required DateTime now,
    int limit = 5,
  }) {
    final nowMinutes = now.hour * 60 + now.minute;
    final upcomingServices =
        _getSchedulesForDirection(selection.direction)
            .map(
              (scheduleView) => _toServiceSnapshot(
                scheduleView: scheduleView,
                nowMinutes: nowMinutes,
                boardingStationId: selection.boardingStationId,
                destinationStationId: selection.destinationStationId,
              ),
            )
            .whereType<RailServiceSnapshot>()
            .toList()
          ..sort(
            (left, right) => left.waitMinutes.compareTo(right.waitMinutes),
          );

    final limitedServices = upcomingServices
        .take(limit)
        .toList(growable: false);

    return RailBoardSnapshot(
      direction: selection.direction,
      currentTime: formatTimeAmPm(_minutesToTime(nowMinutes)),
      selectedStationName: _stationName(selection.boardingStationId),
      destinationStationName: _stationName(selection.destinationStationId),
      nextService: limitedServices.isEmpty ? null : limitedServices.first,
      upcomingServices: limitedServices,
    );
  }

  List<RailStation> getStationsForDirection(String directionValue) {
    final direction = _directionFor(directionValue);

    if (direction == null) {
      return const [];
    }

    final stations = direction.isForward
        ? schedule.stations
        : schedule.stations.reversed.toList(growable: false);

    return List<RailStation>.unmodifiable(stations);
  }

  List<RailStation> getDownstreamStations({
    required String direction,
    required String boardingStationId,
  }) {
    final stations = getStationsForDirection(direction);
    final boardingIndex = stations.indexWhere(
      (station) => station.id == boardingStationId,
    );

    if (boardingIndex < 0) {
      return const [];
    }

    return stations.sublist(boardingIndex + 1);
  }

  String formatTimeAmPm(String time24) {
    final parts = time24.split(':');
    final hour24 = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  String getDurationLabel(int totalMinutes) {
    final safeMinutes = totalMinutes < 0 ? 0 : totalMinutes;
    final hours = safeMinutes ~/ 60;
    final minutes = safeMinutes % 60;

    if (hours == 0) {
      return '$minutes min';
    }

    if (minutes == 0) {
      return hours == 1 ? '1 hour' : '$hours hours';
    }

    if (hours == 1) {
      return '1 hour $minutes min';
    }

    return '$hours hours $minutes min';
  }

  String getWaitLabel(int waitMinutes) {
    if (waitMinutes <= 0) {
      return 'Now';
    }

    return 'In ${getDurationLabel(waitMinutes)}';
  }

  String getEtaLabel(int etaMinutes) {
    return getDurationLabel(etaMinutes);
  }

  String getDecision(int waitMinutes) {
    if (waitMinutes <= 5) {
      return 'Run now';
    }
    if (waitMinutes <= 15) {
      return 'Leave now';
    }
    if (waitMinutes <= 30) {
      return 'You can catch this';
    }
    return 'No need to rush';
  }

  String getServicePeriodLabel(String period) {
    return period.split('_').join(' ').toUpperCase();
  }

  String _stationName(String stationId) {
    return schedule.stations
        .firstWhere((station) => station.id == stationId)
        .name;
  }

  String _defaultDirection() {
    return schedule.directions.length > 1
        ? schedule.directions[1].directionKey
        : schedule.directions.first.directionKey;
  }

  bool _isValidDirection(String? direction) {
    if (direction == null) {
      return false;
    }

    return schedule.directions.any(
      (entry) => entry.directionKey == direction || entry.id == direction,
    );
  }

  RailDirection? _directionFor(String directionValue) {
    for (final direction in schedule.directions) {
      if (direction.directionKey == directionValue ||
          direction.id == directionValue) {
        return direction;
      }
    }

    return null;
  }

  List<_ScheduleView> _getSchedulesForDirection(String directionValue) {
    final direction = _directionFor(directionValue);

    if (direction == null) {
      return const [];
    }

    final stationSequence = getStationsForDirection(directionValue);
    final schedules =
        schedule.trips
            .where((trip) => trip.directionId == direction.id)
            .map(
              (trip) => _ScheduleView(
                scheduleId:
                    '${direction.prefix}-${trip.trainNo.toString().padLeft(2, '0')}',
                trainNo: trip.trainNo,
                servicePeriod: trip.servicePeriod,
                stops: List<RailStopSnapshot>.generate(
                  trip.stopTimes.length,
                  (index) => RailStopSnapshot(
                    stationId: stationSequence[index].id,
                    stationName: stationSequence[index].name,
                    time: trip.stopTimes[index],
                  ),
                  growable: false,
                ),
              ),
            )
            .toList()
          ..sort(
            (left, right) => _toMinutes(
              left.stops.first.time,
            ).compareTo(_toMinutes(right.stops.first.time)),
          );

    return schedules;
  }

  RailServiceSnapshot? _toServiceSnapshot({
    required _ScheduleView scheduleView,
    required int nowMinutes,
    required String boardingStationId,
    required String destinationStationId,
  }) {
    final boardingIndex = scheduleView.stops.indexWhere(
      (stop) => stop.stationId == boardingStationId,
    );
    final destinationIndex = scheduleView.stops.indexWhere(
      (stop) => stop.stationId == destinationStationId,
    );

    if (boardingIndex < 0 ||
        destinationIndex < 0 ||
        boardingIndex > destinationIndex) {
      return null;
    }

    final boardingStop = scheduleView.stops[boardingIndex];
    final destinationStop = scheduleView.stops[destinationIndex];
    final departureMinutes = _toMinutes(boardingStop.time);
    final arrivalMinutes = _toMinutes(destinationStop.time);
    final waitMinutes = _durationMinutes(nowMinutes, departureMinutes);
    final travelMinutes = _durationMinutes(departureMinutes, arrivalMinutes);

    return RailServiceSnapshot(
      scheduleId: scheduleView.scheduleId,
      trainNo: scheduleView.trainNo,
      servicePeriod: scheduleView.servicePeriod,
      departureTime: boardingStop.time,
      arrivalTime: destinationStop.time,
      waitMinutes: waitMinutes,
      etaMinutes: waitMinutes + travelMinutes,
      stops: scheduleView.stops.sublist(boardingIndex, destinationIndex + 1),
    );
  }

  int _toMinutes(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return hour * 60 + minute;
  }

  int _durationMinutes(int fromMinutes, int toMinutes) {
    if (toMinutes >= fromMinutes) {
      return toMinutes - fromMinutes;
    }

    return _minutesPerDay - fromMinutes + toMinutes;
  }

  String _minutesToTime(int minutes) {
    final safeMinutes = minutes % _minutesPerDay;
    final hour = safeMinutes ~/ 60;
    final minute = safeMinutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

class _ScheduleView {
  const _ScheduleView({
    required this.scheduleId,
    required this.trainNo,
    required this.servicePeriod,
    required this.stops,
  });

  final String scheduleId;
  final int trainNo;
  final String servicePeriod;
  final List<RailStopSnapshot> stops;
}
