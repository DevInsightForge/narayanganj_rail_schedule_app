import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/mappers/firestore_community_mapper.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/models/firestore_models.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/delay_status.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/report_confidence.dart';

void main() {
  const mapper = FirestoreCommunityMapper();

  test('maps firestore session model into domain session', () {
    final model = FirestoreSessionModel(
      sessionId: 's1',
      templateId: 't1',
      routeId: 'route',
      directionId: 'dir',
      trainNo: 2,
      serviceDate: '2026-03-28',
      stops: [
        FirestoreSessionStopModel(
          stationId: 'a',
          stationName: 'A',
          sequence: 0,
          scheduledAt: Timestamp.fromDate(DateTime(2026, 3, 28, 4, 30)),
        ),
      ],
    );

    final session = mapper.toSession(model);

    expect(session.sessionId, equals('s1'));
    expect(session.stops.first.stationId, equals('a'));
  });

  test('maps aggregate model into domain aggregate', () {
    final aggregate = mapper.toCommunitySessionAggregate(
      FirestoreSessionAggregateModel(
        sessionId: 's1',
        routeId: 'route',
        directionId: 'dir',
        trainNo: 2,
        serviceDate: '2026-03-28',
        updatedAt: Timestamp.fromDate(DateTime(2026, 3, 28, 4, 32)),
        lastObservedAt: Timestamp.fromDate(DateTime(2026, 3, 28, 4, 31)),
        delayMinutes: 3,
        delayStatus: 'late',
        confidence: const {
          'score': 0.8,
          'sampleSize': 2,
          'freshnessSeconds': 30,
          'agreementScore': 0.9,
        },
        freshnessSeconds: 30,
        reportCount: 1,
        stationCount: 1,
        stationBuckets: {
          'a': FirestoreStationAggregateBucketModel(
            stationId: 'a',
            stationName: 'A',
            sequence: 0,
            scheduledAt: Timestamp.fromDate(DateTime(2026, 3, 28, 4, 30)),
            firstObservedAt: Timestamp.fromDate(DateTime(2026, 3, 28, 4, 31)),
            lastObservedAt: Timestamp.fromDate(DateTime(2026, 3, 28, 4, 31)),
            firstSubmittedAt: Timestamp.fromDate(DateTime(2026, 3, 28, 4, 32)),
            lastSubmittedAt: Timestamp.fromDate(DateTime(2026, 3, 28, 4, 32)),
            latestReportId: 'r1',
            latestDeviceId: 'uid',
            submissionCount: 1,
            delayMinutes: 1,
          ),
        },
      ),
    );

    expect(aggregate.sessionId, equals('s1'));
    expect(aggregate.delayStatus, equals(DelayStatus.late));
    expect(
      aggregate.confidence,
      equals(
        const ReportConfidence(
          score: 0.8,
          sampleSize: 2,
          freshnessSeconds: 30,
          agreementScore: 0.9,
        ),
      ),
    );
    expect(aggregate.stationBuckets.single.stationId, equals('a'));
  });
}
