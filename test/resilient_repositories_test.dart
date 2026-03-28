import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/resilient/resilient_arrival_report_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/resilient/resilient_device_identity_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/resilient/resilient_prediction_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/resilient/resilient_session_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/arrival_report.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/data_origin.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/device_identity.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/predicted_stop_time.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/report_confidence.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/schedule_template.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/train_session.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/arrival_report_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/device_identity_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/prediction_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/session_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/services/train_session_factory.dart';

void main() {
  test('resilient session repository falls back when primary fails', () async {
    final fallbackSession = _session();
    final repository = ResilientSessionRepository(
      primary: _ThrowingSessionRepository(),
      fallback: _InMemorySessionRepository([fallbackSession]),
    );

    final sessions = await repository.fetchSessions(
      routeId: 'route',
      serviceDate: DateTime(2026, 3, 28),
    );

    expect(sessions.length, equals(1));
    expect(sessions.first.sessionId, equals(fallbackSession.sessionId));
  });

  test(
    'resilient arrival repository always stores local fallback first',
    () async {
      final fallback = _InMemoryArrivalRepository();
      final repository = ResilientArrivalReportRepository(
        primary: _ThrowingArrivalRepository(),
        fallback: fallback,
      );
      final report = ArrivalReport(
        reportId: 'r1',
        sessionId: 's1',
        stationId: 'a',
        deviceId: 'd1',
        observedArrivalAt: DateTime(2026, 3, 28, 4, 30),
        submittedAt: DateTime(2026, 3, 28, 4, 30),
      );

      await repository.submitArrivalReport(report);
      final stored = await fallback.fetchStopReports(
        sessionId: 's1',
        stationId: 'a',
      );

      expect(stored.length, equals(1));
    },
  );

  test('resilient prediction repository falls back on failure', () async {
    final fallbackPrediction = PredictedStopTime(
      sessionId: 's1',
      stationId: 'a',
      predictedAt: DateTime(2026, 3, 28, 4, 40),
      referenceStationId: 'a',
      origin: DataOrigin.inferred,
      confidence: const ReportConfidence(
        score: 0.5,
        sampleSize: 1,
        freshnessSeconds: 10,
        agreementScore: 0.5,
      ),
    );
    final repository = ResilientPredictionRepository(
      primary: _ThrowingPredictionRepository(),
      fallback: _InMemoryPredictionRepository([fallbackPrediction]),
    );

    final predictions = await repository.fetchPredictions(sessionId: 's1');

    expect(predictions.length, equals(1));
  });

  test('resilient identity repository falls back when primary fails', () async {
    final fallback = _InMemoryIdentityRepository();
    final repository = ResilientDeviceIdentityRepository(
      primary: _ThrowingIdentityRepository(),
      fallback: fallback,
    );

    final identity = await repository.readOrCreateIdentity();

    expect(identity.deviceId, equals('fallback-user'));
  });
}

TrainSession _session() {
  const factory = TrainSessionFactory();
  final template = ScheduleTemplate(
    templateId: 't',
    routeId: 'route',
    directionId: 'dir',
    trainNo: 1,
    servicePeriod: 'morning',
    stops: const [
      StationStop(
        stationId: 'a',
        stationName: 'A',
        sequence: 0,
        scheduledTime: '04:30',
      ),
      StationStop(
        stationId: 'b',
        stationName: 'B',
        sequence: 1,
        scheduledTime: '04:40',
      ),
    ],
  );
  return factory.create(template: template, serviceDate: DateTime(2026, 3, 28));
}

class _ThrowingSessionRepository implements SessionRepository {
  @override
  Future<List<TrainSession>> fetchSessions({
    required String routeId,
    required DateTime serviceDate,
  }) async => throw StateError('fail');

  @override
  Future<TrainSession?> fetchNextEligibleSession({
    required String routeId,
    required String fromStationId,
    required String toStationId,
    required DateTime now,
  }) async => throw StateError('fail');
}

class _InMemorySessionRepository implements SessionRepository {
  _InMemorySessionRepository(this._sessions);

  final List<TrainSession> _sessions;

  @override
  Future<List<TrainSession>> fetchSessions({
    required String routeId,
    required DateTime serviceDate,
  }) async => _sessions;

  @override
  Future<TrainSession?> fetchNextEligibleSession({
    required String routeId,
    required String fromStationId,
    required String toStationId,
    required DateTime now,
  }) async => _sessions.isEmpty ? null : _sessions.first;
}

class _ThrowingArrivalRepository implements ArrivalReportRepository {
  @override
  Future<List<ArrivalReport>> fetchStopReports({
    required String sessionId,
    required String stationId,
  }) async => throw StateError('fail');

  @override
  Future<void> submitArrivalReport(ArrivalReport report) async {
    throw StateError('fail');
  }
}

class _InMemoryArrivalRepository implements ArrivalReportRepository {
  final List<ArrivalReport> _reports = [];

  @override
  Future<List<ArrivalReport>> fetchStopReports({
    required String sessionId,
    required String stationId,
  }) async {
    return _reports
        .where(
          (report) =>
              report.sessionId == sessionId && report.stationId == stationId,
        )
        .toList(growable: false);
  }

  @override
  Future<void> submitArrivalReport(ArrivalReport report) async {
    _reports.add(report);
  }
}

class _ThrowingPredictionRepository implements PredictionRepository {
  @override
  Future<List<PredictedStopTime>> fetchPredictions({
    required String sessionId,
  }) async => throw StateError('fail');
}

class _InMemoryPredictionRepository implements PredictionRepository {
  _InMemoryPredictionRepository(this._predictions);

  final List<PredictedStopTime> _predictions;

  @override
  Future<List<PredictedStopTime>> fetchPredictions({
    required String sessionId,
  }) async => _predictions;
}

class _ThrowingIdentityRepository implements DeviceIdentityRepository {
  @override
  Future<DeviceIdentity> readOrCreateIdentity() async {
    throw StateError('fail');
  }

  @override
  Future<void> touchIdentity(DateTime now) async {
    throw StateError('fail');
  }
}

class _InMemoryIdentityRepository implements DeviceIdentityRepository {
  @override
  Future<DeviceIdentity> readOrCreateIdentity() async {
    final now = DateTime(2026, 3, 28, 4);
    return DeviceIdentity(
      deviceId: 'fallback-user',
      createdAt: now,
      lastSeenAt: now,
    );
  }

  @override
  Future<void> touchIdentity(DateTime now) async {}
}
