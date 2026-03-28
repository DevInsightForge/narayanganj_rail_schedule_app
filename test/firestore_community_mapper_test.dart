import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/mappers/firestore_community_mapper.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/models/firestore_models.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/arrival_report.dart';

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

  test('maps arrival report both directions', () {
    final report = ArrivalReport(
      reportId: 'r1',
      sessionId: 's1',
      stationId: 'a',
      deviceId: 'uid',
      observedArrivalAt: DateTime(2026, 3, 28, 4, 31),
      submittedAt: DateTime(2026, 3, 28, 4, 32),
    );

    final firestoreModel = mapper.toFirestoreArrivalReport(
      report: report,
      routeId: 'route',
    );
    final restored = mapper.toArrivalReport(firestoreModel);

    expect(restored.reportId, equals(report.reportId));
    expect(restored.sessionId, equals(report.sessionId));
    expect(restored.stationId, equals(report.stationId));
  });
}
