import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_arrival_report_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_device_identity_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_prediction_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_rate_limit_policy_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_session_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/arrival_report.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/predicted_stop_time.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/rate_limit_policy.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/schedule_template.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/train_session.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/arrival_report_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/prediction_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/services/train_session_factory.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/datasources/static_schedule_data_source.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/models/rail_schedule_document_parser.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/repositories/schedule_data_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_selection.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/repositories/selection_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/services/rail_board_service.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/bloc/rail_board_bloc.dart';

void main() {
  group('RailBoardBloc arrival reporting', () {
    test('submits one-tap arrival report when session is eligible', () async {
      final reports = FakeArrivalReportRepository();
      final bloc = RailBoardBloc(
        boardService: RailBoardService(
          schedule: StaticScheduleDataSource.schedule,
        ),
        scheduleDataRepository: _FakeScheduleDataRepository(),
        selectionRepository: _InMemorySelectionRepository(
          const RailSelection(
            direction: 'dhaka_to_narayanganj',
            boardingStationId: 'dhaka',
            destinationStationId: 'narayanganj',
          ),
        ),
        sessionRepository: FakeSessionRepository(seed: _seedSessions()),
        arrivalReportRepository: reports,
        predictionRepository: FakePredictionRepository(),
        deviceIdentityRepository: FakeDeviceIdentityRepository(),
        rateLimitPolicyRepository: FakeRateLimitPolicyRepository(),
        nowProvider: () => DateTime(2026, 3, 28, 4, 25),
      );

      await bloc.stream.firstWhere(
        (state) => state.status == RailBoardStatus.ready,
      );
      bloc.add(const RailBoardArrivalReportRequested());

      final reportState = await bloc.stream.firstWhere(
        (state) =>
            state.reportSubmissionStatus == RailReportSubmissionStatus.success,
      );
      expect(reportState.reportFeedbackMessage, contains('Arrival reported'));
      final stored = await reports.fetchStopReports(
        sessionId: _seedSessions().first.sessionId,
        stationId: 'dhaka',
      );
      expect(stored, isNotEmpty);
      await bloc.close();
    });

    test('reports rate-limited when local policy blocks submission', () async {
      final bloc = RailBoardBloc(
        boardService: RailBoardService(
          schedule: StaticScheduleDataSource.schedule,
        ),
        scheduleDataRepository: _FakeScheduleDataRepository(),
        selectionRepository: _InMemorySelectionRepository(
          const RailSelection(
            direction: 'dhaka_to_narayanganj',
            boardingStationId: 'dhaka',
            destinationStationId: 'narayanganj',
          ),
        ),
        sessionRepository: FakeSessionRepository(seed: _seedSessions()),
        arrivalReportRepository: FakeArrivalReportRepository(),
        predictionRepository: FakePredictionRepository(),
        deviceIdentityRepository: FakeDeviceIdentityRepository(),
        rateLimitPolicyRepository: FakeRateLimitPolicyRepository(
          seed: const {
            'arrival_report': RateLimitPolicy(
              key: 'arrival_report',
              maxEvents: 0,
              windowSeconds: 60,
              coolDownSeconds: 30,
            ),
          },
        ),
        nowProvider: () => DateTime(2026, 3, 28, 4, 25),
      );

      await bloc.stream.firstWhere(
        (state) => state.status == RailBoardStatus.ready,
      );
      bloc.add(const RailBoardArrivalReportRequested());

      final reportState = await bloc.stream.firstWhere(
        (state) =>
            state.reportSubmissionStatus ==
            RailReportSubmissionStatus.rateLimited,
      );
      expect(reportState.reportRetryAfterSeconds, greaterThanOrEqualTo(0));
      await bloc.close();
    });

    test('fails gracefully when no active report window exists', () async {
      final bloc = RailBoardBloc(
        boardService: RailBoardService(
          schedule: StaticScheduleDataSource.schedule,
        ),
        scheduleDataRepository: _FakeScheduleDataRepository(),
        selectionRepository: _InMemorySelectionRepository(
          const RailSelection(
            direction: 'dhaka_to_narayanganj',
            boardingStationId: 'dhaka',
            destinationStationId: 'narayanganj',
          ),
        ),
        sessionRepository: FakeSessionRepository(seed: _seedSessions()),
        arrivalReportRepository: FakeArrivalReportRepository(),
        predictionRepository: FakePredictionRepository(),
        deviceIdentityRepository: FakeDeviceIdentityRepository(),
        rateLimitPolicyRepository: FakeRateLimitPolicyRepository(),
        nowProvider: () => DateTime(2026, 3, 28, 2, 0),
      );

      await bloc.stream.firstWhere(
        (state) => state.status == RailBoardStatus.ready,
      );
      bloc.add(const RailBoardArrivalReportRequested());

      final reportState = await bloc.stream.firstWhere(
        (state) =>
            state.reportSubmissionStatus == RailReportSubmissionStatus.error,
      );
      expect(
        reportState.reportFeedbackMessage,
        contains('No active report window'),
      );
      await bloc.close();
    });

    test('builds ready community insights from fresh reports', () async {
      final session = _seedSessions().first;
      final bloc = RailBoardBloc(
        boardService: RailBoardService(
          schedule: StaticScheduleDataSource.schedule,
        ),
        scheduleDataRepository: _FakeScheduleDataRepository(),
        selectionRepository: _InMemorySelectionRepository(
          const RailSelection(
            direction: 'dhaka_to_narayanganj',
            boardingStationId: 'dhaka',
            destinationStationId: 'narayanganj',
          ),
        ),
        sessionRepository: FakeSessionRepository(seed: [session]),
        arrivalReportRepository: FakeArrivalReportRepository(
          seed: [
            ArrivalReport(
              reportId: 'r1',
              sessionId: session.sessionId,
              stationId: 'dhaka',
              deviceId: 'dev-1',
              observedArrivalAt: DateTime(2026, 3, 28, 4, 32),
              submittedAt: DateTime(2026, 3, 28, 4, 33),
            ),
          ],
        ),
        predictionRepository: FakePredictionRepository(),
        deviceIdentityRepository: FakeDeviceIdentityRepository(),
        rateLimitPolicyRepository: FakeRateLimitPolicyRepository(),
        nowProvider: () => DateTime(2026, 3, 28, 4, 35),
      );

      final insightState = await bloc.stream.firstWhere(
        (state) =>
            state.communityInsightStatus == RailCommunityInsightStatus.ready,
      );
      expect(insightState.sessionStatusSnapshot, isNotNull);
      expect(insightState.predictedStopTimes, isNotEmpty);
      await bloc.close();
    });

    test(
      'retries offline-queued reports on tick when repository recovers',
      () async {
        final session = _seedSessions().first;
        final reports = _FlakyArrivalReportRepository();
        final bloc = RailBoardBloc(
          boardService: RailBoardService(
            schedule: StaticScheduleDataSource.schedule,
          ),
          scheduleDataRepository: _FakeScheduleDataRepository(),
          selectionRepository: _InMemorySelectionRepository(
            const RailSelection(
              direction: 'dhaka_to_narayanganj',
              boardingStationId: 'dhaka',
              destinationStationId: 'narayanganj',
            ),
          ),
          sessionRepository: FakeSessionRepository(seed: [session]),
          arrivalReportRepository: reports,
          predictionRepository: FakePredictionRepository(),
          deviceIdentityRepository: FakeDeviceIdentityRepository(),
          rateLimitPolicyRepository: FakeRateLimitPolicyRepository(),
          nowProvider: () => DateTime(2026, 3, 28, 4, 35),
        );

        await bloc.stream.firstWhere(
          (state) => state.status == RailBoardStatus.ready,
        );
        bloc.add(const RailBoardArrivalReportRequested());

        await bloc.stream.firstWhere(
          (state) =>
              state.reportSubmissionStatus ==
              RailReportSubmissionStatus.offlineQueue,
        );

        reports.failSubmission = false;
        bloc.add(const RailBoardTicked());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(reports.submitted.length, equals(2));

        await bloc.close();
      },
    );

    test('marks community insights error when repositories fail', () async {
      final session = _seedSessions().first;
      final bloc = RailBoardBloc(
        boardService: RailBoardService(
          schedule: StaticScheduleDataSource.schedule,
        ),
        scheduleDataRepository: _FakeScheduleDataRepository(),
        selectionRepository: _InMemorySelectionRepository(
          const RailSelection(
            direction: 'dhaka_to_narayanganj',
            boardingStationId: 'dhaka',
            destinationStationId: 'narayanganj',
          ),
        ),
        sessionRepository: FakeSessionRepository(seed: [session]),
        arrivalReportRepository: _ThrowingArrivalReportRepository(),
        predictionRepository: _ThrowingPredictionRepository(),
        deviceIdentityRepository: FakeDeviceIdentityRepository(),
        rateLimitPolicyRepository: FakeRateLimitPolicyRepository(),
        nowProvider: () => DateTime(2026, 3, 28, 4, 35),
      );

      final failedInsightState = await bloc.stream.firstWhere(
        (state) =>
            state.communityInsightStatus == RailCommunityInsightStatus.error,
      );
      expect(failedInsightState.sessionStatusSnapshot, isNull);
      expect(failedInsightState.predictedStopTimes, isEmpty);
      expect(
        failedInsightState.communityMessage,
        contains('temporarily unavailable'),
      );

      await bloc.close();
    });

    test('marks community insights as stale when reports are old', () async {
      final session = _seedSessions().first;
      final bloc = RailBoardBloc(
        boardService: RailBoardService(
          schedule: StaticScheduleDataSource.schedule,
        ),
        scheduleDataRepository: _FakeScheduleDataRepository(),
        selectionRepository: _InMemorySelectionRepository(
          const RailSelection(
            direction: 'dhaka_to_narayanganj',
            boardingStationId: 'dhaka',
            destinationStationId: 'narayanganj',
          ),
        ),
        sessionRepository: FakeSessionRepository(seed: [session]),
        arrivalReportRepository: FakeArrivalReportRepository(
          seed: [
            ArrivalReport(
              reportId: 'r2',
              sessionId: session.sessionId,
              stationId: 'dhaka',
              deviceId: 'dev-2',
              observedArrivalAt: DateTime(2026, 3, 28, 4, 0),
              submittedAt: DateTime(2026, 3, 28, 4, 1),
            ),
          ],
        ),
        predictionRepository: FakePredictionRepository(),
        deviceIdentityRepository: FakeDeviceIdentityRepository(),
        rateLimitPolicyRepository: FakeRateLimitPolicyRepository(),
        nowProvider: () => DateTime(2026, 3, 28, 4, 35),
      );

      final insightState = await bloc.stream.firstWhere(
        (state) =>
            state.communityInsightStatus == RailCommunityInsightStatus.stale,
      );
      expect(insightState.sessionStatusSnapshot, isNotNull);
      await bloc.close();
    });
  });
}

class _FakeScheduleDataRepository extends ScheduleDataRepository {
  _FakeScheduleDataRepository() : super(parser: RailScheduleDocumentParser());

  @override
  Future<ScheduleLoadResult?> readStoredSchedule() async => null;

  @override
  Future<ScheduleLoadResult?> fetchRemoteSchedule() async => null;
}

class _InMemorySelectionRepository implements SelectionRepository {
  _InMemorySelectionRepository(this._selection);

  RailSelection? _selection;

  @override
  Future<RailSelection?> read() async => _selection;

  @override
  Future<void> write(RailSelection selection) async {
    _selection = selection;
  }
}

List<TrainSession> _seedSessions() {
  const factory = TrainSessionFactory();
  final template = ScheduleTemplate(
    templateId: 'route:02',
    routeId: 'narayanganj_line',
    directionId: 'dhaka_to_narayanganj',
    trainNo: 2,
    servicePeriod: 'early_morning',
    stops: const [
      StationStop(
        stationId: 'dhaka',
        stationName: 'Dhaka',
        sequence: 0,
        scheduledTime: '04:30',
      ),
      StationStop(
        stationId: 'narayanganj',
        stationName: 'Narayanganj',
        sequence: 1,
        scheduledTime: '05:15',
      ),
    ],
  );
  return [
    factory.create(template: template, serviceDate: DateTime(2026, 3, 28)),
  ];
}

class _FlakyArrivalReportRepository implements ArrivalReportRepository {
  bool failSubmission = true;
  final List<ArrivalReport> submitted = [];

  @override
  Future<List<ArrivalReport>> fetchStopReports({
    required String sessionId,
    required String stationId,
  }) async {
    return submitted
        .where(
          (report) =>
              report.sessionId == sessionId && report.stationId == stationId,
        )
        .toList(growable: false);
  }

  @override
  Future<void> submitArrivalReport(ArrivalReport report) async {
    submitted.add(report);
    if (failSubmission) {
      throw StateError('offline');
    }
  }
}

class _ThrowingArrivalReportRepository implements ArrivalReportRepository {
  @override
  Future<List<ArrivalReport>> fetchStopReports({
    required String sessionId,
    required String stationId,
  }) {
    throw StateError('failed');
  }

  @override
  Future<void> submitArrivalReport(ArrivalReport report) async {}
}

class _ThrowingPredictionRepository implements PredictionRepository {
  @override
  Future<List<PredictedStopTime>> fetchPredictions({
    required String sessionId,
  }) {
    throw StateError('failed');
  }
}
