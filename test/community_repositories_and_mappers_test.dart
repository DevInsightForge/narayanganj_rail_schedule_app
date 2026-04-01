import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/mappers/rail_schedule_template_mapper.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_arrival_report_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_device_identity_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_session_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/arrival_report.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/arrival_report_submission.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/delay_status.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/arrival_report_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/schedule_template.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/train_session.dart';
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
      final session = _buildSession(DateTime(2026, 3, 28));
      final report = ArrivalReport(
        reportId: 'r-1',
        sessionId: session.sessionId,
        stationId: 'dhaka',
        deviceId: 'dev-1',
        observedArrivalAt: DateTime(2026, 3, 28, 8, 2),
        submittedAt: DateTime(2026, 3, 28, 8, 2),
      );

      await repository.submitArrivalReport(
        ArrivalReportSubmission(
          report: report,
          session: session,
          stationStop: session.stops.first,
        ),
      );
      final reports = await repository.fetchStopReports(
        sessionId: session.sessionId,
        stationId: 'dhaka',
      );

      expect(reports.length, equals(1));
      expect(reports.first.reportId, equals('r-1'));
    });

    test(
      'second station submission updates the same aggregate session doc',
      () async {
        final repository = FakeArrivalReportRepository();
        final session = _buildSession(DateTime(2026, 3, 28));

        await repository.submitArrivalReport(
          ArrivalReportSubmission(
            report: ArrivalReport(
              reportId: 'r-1',
              sessionId: session.sessionId,
              stationId: 'dhaka',
              deviceId: 'dev-1',
              observedArrivalAt: DateTime(2026, 3, 28, 8, 2),
              submittedAt: DateTime(2026, 3, 28, 8, 2),
            ),
            session: session,
            stationStop: session.stops.first,
          ),
        );
        await repository.submitArrivalReport(
          ArrivalReportSubmission(
            report: ArrivalReport(
              reportId: 'r-2',
              sessionId: session.sessionId,
              stationId: 'narayanganj',
              deviceId: 'dev-2',
              observedArrivalAt: DateTime(2026, 3, 28, 8, 50),
              submittedAt: DateTime(2026, 3, 28, 8, 50),
            ),
            session: session,
            stationStop: session.stops.last,
          ),
        );

        final aggregate = repository.aggregateForSession(session.sessionId);

        expect(aggregate, isNotNull);
        expect(aggregate!.reportCount, equals(2));
        expect(aggregate.stationCount, equals(2));
        expect(aggregate.delayMinutes, equals(5));
        expect(aggregate.delayStatus, equals(DelayStatus.late));
      },
    );

    test(
      'repeated station submission updates the station bucket without inflating totals',
      () async {
        final repository = FakeArrivalReportRepository();
        final session = _buildSession(DateTime(2026, 3, 28));

        await repository.submitArrivalReport(
          ArrivalReportSubmission(
            report: ArrivalReport(
              reportId: 'r-1',
              sessionId: session.sessionId,
              stationId: 'dhaka',
              deviceId: 'dev-1',
              observedArrivalAt: DateTime(2026, 3, 28, 8, 2),
              submittedAt: DateTime(2026, 3, 28, 8, 2),
            ),
            session: session,
            stationStop: session.stops.first,
          ),
        );
        await repository.submitArrivalReport(
          ArrivalReportSubmission(
            report: ArrivalReport(
              reportId: 'r-2',
              sessionId: session.sessionId,
              stationId: 'dhaka',
              deviceId: 'dev-2',
              observedArrivalAt: DateTime(2026, 3, 28, 8, 4),
              submittedAt: DateTime(2026, 3, 28, 8, 4),
            ),
            session: session,
            stationStop: session.stops.first,
          ),
        );

        final aggregate = repository.aggregateForSession(session.sessionId);
        final bucket = aggregate!.bucketForStation('dhaka');

        expect(aggregate.reportCount, equals(2));
        expect(aggregate.stationCount, equals(1));
        expect(bucket, isNotNull);
        expect(bucket!.submissionCount, equals(2));
        expect(bucket.latestReportId, equals('r-2'));
        expect(bucket.latestDeviceId, equals('dev-2'));
        expect(bucket.delayMinutes, equals(4));
      },
    );

    test(
      'station bucket accepts at most ten submissions per session',
      () async {
        final repository = FakeArrivalReportRepository();
        final session = _buildSession(DateTime(2026, 3, 28));

        for (var i = 0; i < 10; i++) {
          await repository.submitArrivalReport(
            ArrivalReportSubmission(
              report: ArrivalReport(
                reportId: 'r-$i',
                sessionId: session.sessionId,
                stationId: 'dhaka',
                deviceId: 'dev-$i',
                observedArrivalAt: DateTime(2026, 3, 28, 8, 2),
                submittedAt: DateTime(2026, 3, 28, 8, 2 + i),
              ),
              session: session,
              stationStop: session.stops.first,
            ),
          );
        }

        await expectLater(
          repository.submitArrivalReport(
            ArrivalReportSubmission(
              report: ArrivalReport(
                reportId: 'r-10',
                sessionId: session.sessionId,
                stationId: 'dhaka',
                deviceId: 'dev-10',
                observedArrivalAt: DateTime(2026, 3, 28, 8, 2),
                submittedAt: DateTime(2026, 3, 28, 8, 12),
              ),
              session: session,
              stationStop: session.stops.first,
            ),
          ),
          throwsA(
            isA<ArrivalReportRepositoryException>().having(
              (error) => error.code,
              'code',
              ArrivalReportRepositoryErrorCode.stationCapacityReached,
            ),
          ),
        );

        final aggregate = repository.aggregateForSession(session.sessionId);

        expect(aggregate, isNotNull);
        expect(aggregate!.reportCount, equals(10));
        expect(aggregate.stationCount, equals(1));
        expect(
          aggregate.bucketForStation('dhaka')!.submissionCount,
          equals(10),
        );
      },
    );

    test(
      'service date stays scoped to the session id for aggregate lookups',
      () async {
        final repository = FakeArrivalReportRepository();
        final firstSession = _buildSession(DateTime(2026, 3, 28));
        final secondSession = _buildSession(DateTime(2026, 3, 29));

        await repository.submitArrivalReport(
          ArrivalReportSubmission(
            report: ArrivalReport(
              reportId: 'r-1',
              sessionId: firstSession.sessionId,
              stationId: 'dhaka',
              deviceId: 'dev-1',
              observedArrivalAt: DateTime(2026, 3, 28, 8, 2),
              submittedAt: DateTime(2026, 3, 28, 8, 2),
            ),
            session: firstSession,
            stationStop: firstSession.stops.first,
          ),
        );
        await repository.submitArrivalReport(
          ArrivalReportSubmission(
            report: ArrivalReport(
              reportId: 'r-2',
              sessionId: secondSession.sessionId,
              stationId: 'dhaka',
              deviceId: 'dev-1',
              observedArrivalAt: DateTime(2026, 3, 29, 8, 3),
              submittedAt: DateTime(2026, 3, 29, 8, 3),
            ),
            session: secondSession,
            stationStop: secondSession.stops.first,
          ),
        );

        expect(firstSession.sessionId, isNot(equals(secondSession.sessionId)));
        expect(
          repository.aggregateForSession(firstSession.sessionId),
          isNotNull,
        );
        expect(
          repository.aggregateForSession(secondSession.sessionId),
          isNotNull,
        );
        expect(
          repository.aggregateForSession(firstSession.sessionId)!.serviceDate,
          equals(DateTime(2026, 3, 28)),
        );
        expect(
          repository.aggregateForSession(secondSession.sessionId)!.serviceDate,
          equals(DateTime(2026, 3, 29)),
        );
      },
    );

    test('device identity repository persists identity', () async {
      final repository = FakeDeviceIdentityRepository();
      final identity = await repository.readOrCreateIdentity();
      final sameIdentity = await repository.readOrCreateIdentity();

      expect(identity.deviceId, equals(sameIdentity.deviceId));
      expect(identity.createdAt, equals(sameIdentity.createdAt));
    });
  });
}

TrainSession _buildSession(DateTime serviceDate) {
  return const TrainSessionFactory().create(
    template: ScheduleTemplate(
      templateId: 't-2',
      routeId: 'narayanganj_line',
      directionId: 'dhaka_to_narayanganj',
      trainNo: 2,
      servicePeriod: 'morning',
      stops: [
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
    ),
    serviceDate: serviceDate,
  );
}
