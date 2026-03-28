import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/arrival_report.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/delay_status.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/schedule_template.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/session_status_snapshot.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/services/delay_classifier_service.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/services/downstream_prediction_service.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/services/report_confidence_service.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/services/session_lifecycle_service.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/services/session_status_aggregation_service.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/services/train_session_factory.dart';

void main() {
  group('community domain foundation', () {
    const factory = TrainSessionFactory();
    const lifecycle = SessionLifecycleService();
    const delayClassifier = DelayClassifierService();
    const confidence = ReportConfidenceService();
    const predictions = DownstreamPredictionService();
    const aggregation = SessionStatusAggregationService(
      delayClassifierService: delayClassifier,
      confidenceService: confidence,
    );

    final overnightTemplate = ScheduleTemplate(
      templateId: 'route:15',
      routeId: 'narayanganj_line',
      directionId: 'narayanganj_to_dhaka',
      trainNo: 15,
      servicePeriod: 'late_night',
      stops: const [
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

    test('creates date-scoped sessions and handles overnight stops', () {
      final session = factory.create(
        template: overnightTemplate,
        serviceDate: DateTime(2026, 3, 28),
      );

      expect(session.sessionId, contains('20260328'));
      expect(session.stops.first.scheduledAt.day, equals(28));
      expect(session.stops.last.scheduledAt.day, equals(29));
    });

    test('applies tight session eligibility window', () {
      final session = factory.create(
        template: overnightTemplate,
        serviceDate: DateTime(2026, 3, 28),
      );
      final beforeWindow = DateTime(2026, 3, 28, 23, 44);
      final inWindow = DateTime(2026, 3, 28, 23, 46);
      final afterWindow = DateTime(2026, 3, 29, 0, 51);

      expect(
        lifecycle.getState(session: session, now: beforeWindow),
        SessionLifecycleState.upcoming,
      );
      expect(
        lifecycle.getState(session: session, now: inWindow),
        SessionLifecycleState.active,
      );
      expect(
        lifecycle.getState(session: session, now: afterWindow),
        SessionLifecycleState.expired,
      );
      expect(
        lifecycle.isReportEligible(session: session, now: afterWindow),
        isFalse,
      );
    });

    test('classifies early on-time and late status', () {
      final scheduled = DateTime(2026, 3, 28, 8, 0);

      expect(
        delayClassifier.classify(
          scheduledAt: scheduled,
          observedAt: DateTime(2026, 3, 28, 7, 56),
        ),
        DelayStatus.early,
      );
      expect(
        delayClassifier.classify(
          scheduledAt: scheduled,
          observedAt: DateTime(2026, 3, 28, 8, 1),
        ),
        DelayStatus.onTime,
      );
      expect(
        delayClassifier.classify(
          scheduledAt: scheduled,
          observedAt: DateTime(2026, 3, 28, 8, 5),
        ),
        DelayStatus.late,
      );
    });

    test('builds consensus with conflicting reports and confidence', () {
      final session = factory.create(
        template: overnightTemplate,
        serviceDate: DateTime(2026, 3, 28),
      );
      final now = DateTime(2026, 3, 28, 23, 56);
      final reports = [
        ArrivalReport(
          reportId: 'r1',
          sessionId: session.sessionId,
          stationId: 'narayanganj',
          deviceId: 'dev-1',
          observedArrivalAt: DateTime(2026, 3, 28, 23, 51),
          submittedAt: DateTime(2026, 3, 28, 23, 52),
        ),
        ArrivalReport(
          reportId: 'r2',
          sessionId: session.sessionId,
          stationId: 'narayanganj',
          deviceId: 'dev-2',
          observedArrivalAt: DateTime(2026, 3, 28, 23, 50),
          submittedAt: DateTime(2026, 3, 28, 23, 53),
        ),
        ArrivalReport(
          reportId: 'r3',
          sessionId: session.sessionId,
          stationId: 'narayanganj',
          deviceId: 'dev-3',
          observedArrivalAt: DateTime(2026, 3, 28, 23, 59),
          submittedAt: DateTime(2026, 3, 28, 23, 54),
        ),
      ];

      final consensus = aggregation.buildStationConsensus(
        session: session,
        stationId: 'narayanganj',
        reports: reports,
        now: now,
      );

      expect(consensus.primaryReports.length, equals(2));
      expect(consensus.conflictingReports.length, equals(1));
      expect(consensus.confidence.score, greaterThan(0));
    });

    test('predicts downstream times with bounded delay carry-forward', () {
      final session = factory.create(
        template: overnightTemplate,
        serviceDate: DateTime(2026, 3, 28),
      );
      final reports = [
        ArrivalReport(
          reportId: 'r1',
          sessionId: session.sessionId,
          stationId: 'narayanganj',
          deviceId: 'dev-1',
          observedArrivalAt: DateTime(2026, 3, 28, 23, 55),
          submittedAt: DateTime(2026, 3, 28, 23, 55),
        ),
      ];
      final confidenceScore = confidence.evaluate(
        reports: reports,
        now: DateTime(2026, 3, 28, 23, 56),
      );
      final predicted = predictions.predictFromObservation(
        session: session,
        observedStationId: 'narayanganj',
        observedArrivalAt: DateTime(2026, 3, 28, 23, 55),
        confidence: confidenceScore,
      );

      expect(predicted.length, equals(2));
      expect(predicted.last.stationId, equals('dhaka'));
      expect(predicted.last.predictedAt.hour, equals(0));
      expect(predicted.last.predictedAt.minute, equals(25));
    });
  });
}
