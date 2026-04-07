import '../entities/schedule_template.dart';
import '../entities/train_session.dart';

class TrainSessionFactory {
  const TrainSessionFactory();

  TrainSession create({
    required ScheduleTemplate template,
    required DateTime serviceDate,
  }) {
    final baseDate = DateTime(
      serviceDate.year,
      serviceDate.month,
      serviceDate.day,
    );
    var dayOffset = 0;
    var previousMinutes = -1;
    final stops = <SessionStop>[];

    for (final stop in template.stops) {
      final minutesOfDay = _parseMinutes(stop.scheduledTime);
      if (previousMinutes >= 0 && minutesOfDay < previousMinutes) {
        dayOffset += 1;
      }
      previousMinutes = minutesOfDay;
      final scheduledAt = baseDate.add(
        Duration(days: dayOffset, minutes: minutesOfDay),
      );
      stops.add(
        SessionStop(
          stationId: stop.stationId,
          stationName: stop.stationName,
          sequence: stop.sequence,
          scheduledAt: scheduledAt,
        ),
      );
    }

    final sessionDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
    final sessionId =
        '${template.routeId}:${template.directionId}:${template.trainNo}';

    return TrainSession(
      sessionId: sessionId,
      templateId: template.templateId,
      routeId: template.routeId,
      directionId: template.directionId,
      trainNo: template.trainNo,
      serviceDate: sessionDate,
      stops: stops,
    );
  }

  int _parseMinutes(String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return hour * 60 + minute;
  }
}
