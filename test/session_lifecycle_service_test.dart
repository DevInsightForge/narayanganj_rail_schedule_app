import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/train_session.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/services/session_lifecycle_service.dart';

void main() {
  const service = SessionLifecycleService();
  final session = TrainSession(
    sessionId: 's1',
    templateId: 't1',
    routeId: 'route',
    directionId: 'dir',
    trainNo: 2,
    serviceDate: DateTime(2026, 3, 28),
    stops: [
      SessionStop(
        stationId: 'dhaka',
        stationName: 'Dhaka',
        sequence: 0,
        scheduledAt: DateTime(2026, 3, 28, 4, 30),
      ),
      SessionStop(
        stationId: 'narayanganj',
        stationName: 'Narayanganj',
        sequence: 1,
        scheduledAt: DateTime(2026, 3, 28, 5, 15),
      ),
    ],
  );

  test('marks scheduled time active until fifteen minutes after it starts', () {
    expect(
      service.isReportEligibleForScheduledAt(
        scheduledAt: session.stops.first.scheduledAt,
        now: DateTime(2026, 3, 28, 4, 45),
      ),
      isTrue,
    );
    expect(
      service.isReportEligibleForScheduledAt(
        scheduledAt: session.stops.first.scheduledAt,
        now: DateTime(2026, 3, 28, 4, 46),
      ),
      isFalse,
    );
  });
}
