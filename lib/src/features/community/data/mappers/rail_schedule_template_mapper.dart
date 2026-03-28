import '../../../rail/domain/entities/rail_schedule.dart';
import '../../domain/entities/schedule_template.dart';

class RailScheduleTemplateMapper {
  const RailScheduleTemplateMapper();

  List<ScheduleTemplate> map({
    required String routeId,
    required RailSchedule schedule,
  }) {
    final templates = <ScheduleTemplate>[];
    for (final trip in schedule.trips) {
      final direction = schedule.directions.firstWhere(
        (entry) => entry.id == trip.directionId,
      );
      final stations = direction.isForward
          ? schedule.stations
          : schedule.stations.reversed.toList(growable: false);
      final stops = List<StationStop>.generate(
        trip.stopTimes.length,
        (index) => StationStop(
          stationId: stations[index].id,
          stationName: stations[index].name,
          sequence: index,
          scheduledTime: trip.stopTimes[index],
        ),
        growable: false,
      );
      templates.add(
        ScheduleTemplate(
          templateId: trip.id,
          routeId: routeId,
          directionId: direction.directionKey,
          trainNo: trip.trainNo,
          servicePeriod: trip.servicePeriod,
          stops: stops,
        ),
      );
    }
    templates.sort((a, b) {
      final left = a.stops.first.scheduledTime;
      final right = b.stops.first.scheduledTime;
      return left.compareTo(right);
    });
    return templates;
  }
}
