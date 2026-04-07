import 'dart:async';

import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/arrival_report.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/arrival_report_submission.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/community_overlay_result.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/data_origin.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/delay_status.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/device_identity.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/firebase_auth_readiness.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/predicted_stop_time.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/report_confidence.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/schedule_template.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/session_status_snapshot.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/train_session.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/arrival_report_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/device_identity_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/services/train_session_factory.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/models/rail_schedule_document_parser.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/repositories/schedule_data_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_selection.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_schedule.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/repositories/selection_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/services/rail_board_service.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/bloc/rail_board_cubit.dart';

import 'community_fakes.dart';

RailBoardCubit buildRailBoardReportingCubit({
  required RailSchedule bundledSchedule,
  required ArrivalReportRepository arrivalReportRepository,
  required FakeArrivalReportLedgerRepository arrivalReportLedgerRepository,
  required FakeCommunityOverlayRepository communityOverlayRepository,
  required DeviceIdentityRepository deviceIdentityRepository,
  bool communityFeaturesEnabled = true,
  required DateTime Function() nowProvider,
}) {
  return RailBoardCubit(
    boardService: RailBoardService(schedule: bundledSchedule),
    scheduleDataRepository: _FakeScheduleDataRepository(),
    selectionRepository: _InMemorySelectionRepository(
      const RailSelection(
        direction: 'dhaka_to_narayanganj',
        boardingStationId: 'dhaka',
        destinationStationId: 'narayanganj',
      ),
    ),
    sessionRepository: FakeSessionRepository(
      seed: seedRailBoardReportingSessions(),
    ),
    arrivalReportRepository: arrivalReportRepository,
    arrivalReportLedgerRepository: arrivalReportLedgerRepository,
    communityOverlayRepository: communityOverlayRepository,
    deviceIdentityRepository: deviceIdentityRepository,
    communityFeaturesEnabled: communityFeaturesEnabled,
    nowProvider: nowProvider,
    enableTicker: false,
  );
}

CommunityOverlayResult railBoardReportingOverlayResult({
  required String sessionId,
  required DateTime fetchedAt,
  required int freshnessSeconds,
}) {
  return CommunityOverlayResult(
    sessionStatusSnapshot: SessionStatusSnapshot(
      sessionId: sessionId,
      state: SessionLifecycleState.active,
      delayMinutes: 4,
      delayStatus: DelayStatus.late,
      confidence: const ReportConfidence(
        score: 0.85,
        sampleSize: 3,
        freshnessSeconds: 30,
        agreementScore: 0.8,
      ),
      freshnessSeconds: freshnessSeconds,
      lastObservedAt: fetchedAt.subtract(const Duration(minutes: 1)),
    ),
    predictedStopTimes: [
      PredictedStopTime(
        sessionId: sessionId,
        stationId: 'narayanganj',
        predictedAt: fetchedAt.add(const Duration(minutes: 40)),
        referenceStationId: 'dhaka',
        origin: DataOrigin.community,
        confidence: const ReportConfidence(
          score: 0.8,
          sampleSize: 3,
          freshnessSeconds: 30,
          agreementScore: 0.75,
        ),
      ),
    ],
    fetchedAt: fetchedAt,
    fromCache: false,
  );
}

Future<RailBoardState> waitForRailBoardState(
  RailBoardCubit cubit,
  bool Function(RailBoardState) predicate,
) async {
  final current = cubit.state;
  if (predicate(current)) {
    return current;
  }
  return cubit.stream.firstWhere(predicate);
}

List<TrainSession> seedRailBoardReportingSessions() {
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

class FlakyArrivalReportRepository implements ArrivalReportRepository {
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
  Future<int> fetchStationSubmissionCount({
    required String sessionId,
    required String stationId,
  }) async {
    return submitted
        .where(
          (report) =>
              report.sessionId == sessionId && report.stationId == stationId,
        )
        .length;
  }

  @override
  Future<void> submitArrivalReport(ArrivalReportSubmission submission) async {
    if (failSubmission) {
      throw StateError('offline');
    }
    submitted.add(submission.report);
  }
}

class FixedDeviceIdentityRepository implements DeviceIdentityRepository {
  FixedDeviceIdentityRepository()
    : identity = DeviceIdentity(
        deviceId: 'device-1',
        createdAt: DateTime(2026, 3, 28, 4),
        lastSeenAt: DateTime(2026, 3, 28, 4),
      );

  final DeviceIdentity identity;

  @override
  Future<FirebaseAuthReadiness> readAuthReadiness({String? attemptId}) async {
    return FirebaseAuthReadiness.ready(identity.deviceId);
  }

  @override
  Future<DeviceIdentity> readOrCreateIdentity({String? attemptId}) async =>
      identity;
}

class ResolvingDeviceIdentityRepository implements DeviceIdentityRepository {
  ResolvingDeviceIdentityRepository({
    required Future<FirebaseAuthReadiness> readiness,
    required this.identity,
  }) : _readiness = readiness;

  final Future<FirebaseAuthReadiness> _readiness;
  final DeviceIdentity identity;

  @override
  Future<FirebaseAuthReadiness> readAuthReadiness({String? attemptId}) {
    return _readiness;
  }

  @override
  Future<DeviceIdentity> readOrCreateIdentity({String? attemptId}) async =>
      identity;
}
