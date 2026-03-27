import '../../domain/entities/rail_direction.dart';
import '../../domain/entities/rail_schedule.dart';

class RailScheduleDocumentParser {
  RailSchedule parse(Map<String, dynamic> document) {
    final version = _parseVersion(document['version']);
    final stations = _parseStations(document['stations']);
    final directions = _parseDirections(document['directions']);
    final trips = _parseTrips(document['trips']);

    if (stations.isEmpty || directions.isEmpty || trips.isEmpty) {
      throw const FormatException('Invalid schedule document.');
    }

    if (!_hasConsistentStops(trips: trips, stationCount: stations.length)) {
      throw const FormatException('Schedule contains inconsistent stop counts.');
    }

    return RailSchedule(
      version: version,
      stations: stations,
      directions: directions,
      trips: trips,
    );
  }

  String _parseVersion(dynamic value) {
    final parsed = '$value'.trim();
    if (parsed.isEmpty || parsed == 'null') {
      return 'legacy';
    }

    return parsed;
  }

  bool _hasConsistentStops({
    required List<RailTrip> trips,
    required int stationCount,
  }) {
    return trips.every((trip) => trip.stopTimes.length == stationCount);
  }

  List<RailStation> _parseStations(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map(
          (entry) => RailStation(
            id: '${entry['id'] ?? ''}',
            code: '${entry['code'] ?? ''}',
            name: '${entry['name'] ?? ''}',
          ),
        )
        .where(
          (station) =>
              station.id.isNotEmpty &&
              station.code.isNotEmpty &&
              station.name.isNotEmpty,
        )
        .toList(growable: false);
  }

  List<RailDirection> _parseDirections(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map(
          (entry) => RailDirection(
            id: '${entry['id'] ?? ''}',
            directionKey: '${entry['directionKey'] ?? ''}',
            prefix: '${entry['prefix'] ?? ''}',
            label: '${entry['label'] ?? ''}',
            isForward: entry['isForward'] == true,
          ),
        )
        .where(
          (direction) =>
              direction.id.isNotEmpty &&
              direction.directionKey.isNotEmpty &&
              direction.prefix.isNotEmpty &&
              direction.label.isNotEmpty,
        )
        .toList(growable: false);
  }

  List<RailTrip> _parseTrips(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map((entry) {
          final stopTimes = (entry['stopTimes'] as List<dynamic>? ?? const [])
              .map((time) => '$time')
              .where((time) => time.isNotEmpty)
              .toList(growable: false);

          return RailTrip(
            id: '${entry['id'] ?? ''}',
            directionId: '${entry['directionId'] ?? ''}',
            trainNo: entry['trainNo'] is num
                ? (entry['trainNo'] as num).toInt()
                : int.tryParse('${entry['trainNo'] ?? ''}') ?? -1,
            servicePeriod:
                '${entry['timeCategory'] ?? entry['servicePeriod'] ?? ''}',
            stopTimes: stopTimes,
          );
        })
        .where(
          (trip) =>
              trip.id.isNotEmpty &&
              trip.directionId.isNotEmpty &&
              trip.trainNo >= 0 &&
              trip.servicePeriod.isNotEmpty &&
              trip.stopTimes.isNotEmpty,
        )
        .toList(growable: false);
  }
}
