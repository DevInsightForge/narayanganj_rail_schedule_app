import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/mappers/rail_schedule_template_mapper.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_arrival_report_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_device_identity_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_session_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/arrival_report.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/schedule_template.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/services/train_session_factory.dart';

import 'support/bundled_schedule_fixture.dart';

void main() {
  final bundledSchedule = loadBundledScheduleFixture();
  group('community repository contracts and mappers', () {
    test('maps rail schedule into session templates', () {
      const mapper = RailScheduleTemplateMapper();
      final templates = mapper.map(
        routeId: 'narayanganj_line',
        schedule: bundledSchedule,
      );

      expect(templates, isNotEmpty);
      expect(templates.first.routeId, equals('narayanganj_line'));
      expect(templates.first.stops, isNotEmpty);
    });

    test('session repository returns seeded sessions', () async {
      const sessionFactory = TrainSessionFactory();
      final template = ScheduleTemplate(
        templateId: 't-1',
        routeId: 'narayanganj_line',
        directionId: 'dhaka_to_narayanganj',
        trainNo: 2,
        servicePeriod: 'morning',
        stops: const [
          StationStop(
            stationId: 'dhaka',
            stationName: 'Dhaka',
            sequence: 0,
            scheduledTime: '08:00',
          ),
          StationStop(
            stationId: 'narayanganj',
            stationName: 'Narayanganj',
            sequence: 1,
            scheduledTime: '08:45',
          ),
        ],
      );
      final session = sessionFactory.create(
        template: template,
        serviceDate: DateTime(2026, 3, 28),
      );
      final repository = FakeSessionRepository(seed: [session]);

      final sessions = await repository.fetchSessions(
        routeId: 'narayanganj_line',
        serviceDate: DateTime(2026, 3, 28),
      );

      expect(sessions.length, equals(1));
      expect(sessions.first.sessionId, equals(session.sessionId));
    });

    test('arrival report repository stores and returns stop reports', () async {
      final repository = FakeArrivalReportRepository();
      final report = ArrivalReport(
        reportId: 'r-1',
        sessionId: 's-1',
        stationId: 'dhaka',
        deviceId: 'dev-1',
        observedArrivalAt: DateTime(2026, 3, 28, 8, 2),
        submittedAt: DateTime(2026, 3, 28, 8, 2),
      );

      await repository.submitArrivalReport(report);
      final reports = await repository.fetchStopReports(
        sessionId: 's-1',
        stationId: 'dhaka',
      );

      expect(reports.length, equals(1));
      expect(reports.first.reportId, equals('r-1'));
    });

    test('device identity repository persists identity', () async {
      final repository = FakeDeviceIdentityRepository();
      final identity = await repository.readOrCreateIdentity();
      final sameIdentity = await repository.readOrCreateIdentity();

      expect(identity.deviceId, equals(sameIdentity.deviceId));
      expect(identity.createdAt, equals(sameIdentity.createdAt));
    });
  });
}
