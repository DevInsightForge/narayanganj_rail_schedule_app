import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/local/generated_session_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/schedule_template.dart';

void main() {
  test('generates sessions for requested service date', () async {
    final repository = GeneratedSessionRepository(templates: [_template()]);

    final sessions = await repository.fetchSessions(
      routeId: 'narayanganj_line',
      serviceDate: DateTime(2026, 3, 28, 12, 30),
    );

    expect(sessions.length, equals(1));
    expect(
      sessions.first.sessionId,
      equals('narayanganj_line:dhaka_to_narayanganj:7'),
    );
  });

  test('finds next eligible session across day boundary', () async {
    final repository = GeneratedSessionRepository(
      templates: [_overnightTemplate()],
    );

    final session = await repository.fetchNextEligibleSession(
      routeId: 'narayanganj_line',
      fromStationId: 'narayanganj',
      toStationId: 'dhaka',
      now: DateTime(2026, 3, 28, 23, 55),
    );

    expect(session, isNotNull);
    expect(
      session!.sessionId,
      equals('narayanganj_line:narayanganj_to_dhaka:15'),
    );
  });
}

ScheduleTemplate _template() {
  return const ScheduleTemplate(
    templateId: 'route:7',
    routeId: 'narayanganj_line',
    directionId: 'dhaka_to_narayanganj',
    trainNo: 7,
    servicePeriod: 'morning',
    stops: [
      StationStop(
        stationId: 'dhaka',
        stationName: 'Dhaka',
        sequence: 0,
        scheduledTime: '05:00',
      ),
      StationStop(
        stationId: 'narayanganj',
        stationName: 'Narayanganj',
        sequence: 1,
        scheduledTime: '05:40',
      ),
    ],
  );
}

ScheduleTemplate _overnightTemplate() {
  return const ScheduleTemplate(
    templateId: 'route:15',
    routeId: 'narayanganj_line',
    directionId: 'narayanganj_to_dhaka',
    trainNo: 15,
    servicePeriod: 'late_night',
    stops: [
      StationStop(
        stationId: 'narayanganj',
        stationName: 'Narayanganj',
        sequence: 0,
        scheduledTime: '23:50',
      ),
      StationStop(
        stationId: 'dhaka',
        stationName: 'Dhaka',
        sequence: 1,
        scheduledTime: '00:20',
      ),
    ],
  );
}
