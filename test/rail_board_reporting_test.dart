import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_arrival_report_ledger_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_arrival_report_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_community_overlay_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_session_repository.dart';
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
import 'package:narayanganj_rail_schedule/src/features/rail/application/models/rail_reporting.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_selection.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/repositories/selection_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/services/rail_board_service.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/bloc/rail_board_cubit.dart';

import 'support/bundled_schedule_fixture.dart';

void main() {
  final bundledSchedule = loadBundledScheduleFixture();

  group('RailBoardCubit arrival reporting', () {
    test('submits one-tap arrival report when session is eligible', () async {
      final reports = FakeArrivalReportRepository();
      final ledger = FakeArrivalReportLedgerRepository();
      final deviceIdentityRepository = _FixedDeviceIdentityRepository();
      final cubit = _buildCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: reports,
        arrivalReportLedgerRepository: ledger,
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: deviceIdentityRepository,
        nowProvider: () => DateTime(2026, 3, 28, 4, 25),
      );

      await _waitForState(
        cubit,
        (state) => state.status == RailBoardStatus.ready,
      );

      await cubit.submitArrivalReport();

      final reportState = await _waitForState(
        cubit,
        (state) =>
            state.reportSubmissionStatus == RailReportSubmissionStatus.success,
      );
      expect(reportState.reportFeedbackMessage, contains('Arrival reported'));
      expect(reportState.report.hasReportedCurrentSession, isTrue);
      expect(reportState.report.submitEnabled, isFalse);

      final stored = await reports.fetchStopReports(
        sessionId: _seedSessions().first.sessionId,
        stationId: 'dhaka',
      );
      expect(stored, isNotEmpty);
      expect(
        await ledger.hasSubmitted(
          sessionId: _seedSessions().first.sessionId,
          stationId: 'dhaka',
          deviceId: deviceIdentityRepository.identity.deviceId,
        ),
        isTrue,
      );

      await cubit.submitArrivalReport();
      final duplicateState = await _waitForState(
        cubit,
        (state) =>
            state.reportSubmissionStatus == RailReportSubmissionStatus.error,
      );
      expect(
        duplicateState.reportFeedbackMessage,
        contains('Reporting is not available for this train yet.'),
      );
      expect(duplicateState.report.hasReportedCurrentSession, isTrue);
      expect(
        await reports.fetchStopReports(
          sessionId: _seedSessions().first.sessionId,
          stationId: 'dhaka',
        ),
        hasLength(1),
      );

      await cubit.close();
    });

    test('hides reporting action while auth readiness is resolving', () async {
      final readinessCompleter = Completer<FirebaseAuthReadiness>();
      final deviceIdentityRepository = _ResolvingDeviceIdentityRepository(
        readiness: readinessCompleter.future,
        identity: DeviceIdentity(
          deviceId: 'device-1',
          createdAt: DateTime(2026, 3, 28, 4),
          lastSeenAt: DateTime(2026, 3, 28, 4),
        ),
      );
      final cubit = _buildCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: FakeArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: deviceIdentityRepository,
        nowProvider: () => DateTime(2026, 3, 28, 4, 25),
      );

      final resolvingState = await _waitForState(
        cubit,
        (state) =>
            state.status == RailBoardStatus.ready &&
            state.report.authReadiness.status ==
                FirebaseAuthReadinessStatus.resolving,
      );
      expect(resolvingState.report.visibility, RailReportVisibility.hidden);
      expect(resolvingState.report.submitEnabled, isFalse);

      readinessCompleter.complete(
        const FirebaseAuthReadiness.ready('device-1'),
      );
      final readyState = await _waitForState(
        cubit,
        (state) =>
            state.status == RailBoardStatus.ready &&
            state.report.authReadiness.status ==
                FirebaseAuthReadinessStatus.ready,
      );
      expect(readyState.report.visibility, RailReportVisibility.visible);
      expect(readyState.report.submitEnabled, isTrue);
      await cubit.close();
    });

    test('hides reporting action when auth readiness fails', () async {
      final deviceIdentityRepository = _ResolvingDeviceIdentityRepository(
        readiness: Future.value(const FirebaseAuthReadiness.failed()),
        identity: DeviceIdentity(
          deviceId: 'device-1',
          createdAt: DateTime(2026, 3, 28, 4),
          lastSeenAt: DateTime(2026, 3, 28, 4),
        ),
      );
      final cubit = _buildCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: FakeArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: deviceIdentityRepository,
        nowProvider: () => DateTime(2026, 3, 28, 4, 25),
      );

      final failedState = await _waitForState(
        cubit,
        (state) =>
            state.status == RailBoardStatus.ready &&
            state.report.authReadiness.status ==
                FirebaseAuthReadinessStatus.failed,
      );
      expect(failedState.report.visibility, RailReportVisibility.hidden);
      expect(failedState.report.submitEnabled, isFalse);
      await cubit.close();
    });

    test('fails gracefully when no active report window exists', () async {
      final cubit = _buildCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: FakeArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: _FixedDeviceIdentityRepository(),
        nowProvider: () => DateTime(2026, 3, 28, 2, 0),
      );

      await _waitForState(
        cubit,
        (state) => state.status == RailBoardStatus.ready,
      );

      await cubit.submitArrivalReport();

      final reportState = await _waitForState(
        cubit,
        (state) =>
            state.reportSubmissionStatus == RailReportSubmissionStatus.error,
      );
      expect(
        reportState.reportFeedbackMessage,
        contains('Reporting is not available'),
      );
      await cubit.close();
    });

    test('builds ready community insights from aggregate overlay', () async {
      final session = _seedSessions().first;
      final cubit = _buildCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: FakeArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(
          seed: {
            session.sessionId: _overlayResult(
              sessionId: session.sessionId,
              fetchedAt: DateTime(2026, 3, 28, 4, 25),
              freshnessSeconds: 30,
            ),
          },
        ),
        deviceIdentityRepository: _FixedDeviceIdentityRepository(),
        nowProvider: () => DateTime(2026, 3, 28, 4, 25),
      );

      final insightState = await _waitForState(
        cubit,
        (state) =>
            state.communityInsightStatus == RailCommunityInsightStatus.ready,
      );
      expect(insightState.sessionStatusSnapshot, isNotNull);
      expect(insightState.predictedStopTimes, isNotEmpty);
      await cubit.close();
    });

    test(
      'does not queue failed reports and retries only on explicit submit',
      () async {
        final reports = _FlakyArrivalReportRepository();
        final ledger = FakeArrivalReportLedgerRepository();
        final deviceIdentityRepository = _FixedDeviceIdentityRepository();
        final cubit = _buildCubit(
          bundledSchedule: bundledSchedule,
          arrivalReportRepository: reports,
          arrivalReportLedgerRepository: ledger,
          communityOverlayRepository: FakeCommunityOverlayRepository(),
          deviceIdentityRepository: deviceIdentityRepository,
          nowProvider: () => DateTime(2026, 3, 28, 4, 25),
        );

        await _waitForState(
          cubit,
          (state) => state.status == RailBoardStatus.ready,
        );

        await cubit.submitArrivalReport();
        await _waitForState(
          cubit,
          (state) =>
              state.reportSubmissionStatus == RailReportSubmissionStatus.error,
        );
        expect(reports.submitted, isEmpty);
        expect(
          await ledger.hasSubmitted(
            sessionId: _seedSessions().first.sessionId,
            stationId: 'dhaka',
            deviceId: deviceIdentityRepository.identity.deviceId,
          ),
          isFalse,
        );

        reports.failSubmission = false;
        await cubit.submitArrivalReport();
        await _waitForState(
          cubit,
          (state) =>
              state.reportSubmissionStatus ==
              RailReportSubmissionStatus.success,
        );
        expect(reports.submitted, hasLength(1));
        await cubit.close();
      },
    );

    test(
      'marks community insights error when overlay repository fails',
      () async {
        final overlayRepository = FakeCommunityOverlayRepository()
          ..failFetch = true;
        final cubit = _buildCubit(
          bundledSchedule: bundledSchedule,
          arrivalReportRepository: FakeArrivalReportRepository(),
          arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
          communityOverlayRepository: overlayRepository,
          deviceIdentityRepository: _FixedDeviceIdentityRepository(),
          nowProvider: () => DateTime(2026, 3, 28, 4, 25),
        );

        final failedInsightState = await _waitForState(
          cubit,
          (state) =>
              state.communityInsightStatus == RailCommunityInsightStatus.error,
        );
        expect(failedInsightState.sessionStatusSnapshot, isNull);
        expect(failedInsightState.predictedStopTimes, isEmpty);
        expect(
          failedInsightState.communityMessage,
          contains('temporarily unavailable'),
        );

        await cubit.close();
      },
    );

    test(
      'marks community insights as stale when overlay freshness is old',
      () async {
        final session = _seedSessions().first;
        final cubit = _buildCubit(
          bundledSchedule: bundledSchedule,
          arrivalReportRepository: FakeArrivalReportRepository(),
          arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
          communityOverlayRepository: FakeCommunityOverlayRepository(
            seed: {
              session.sessionId: _overlayResult(
                sessionId: session.sessionId,
                fetchedAt: DateTime(2026, 3, 28, 4, 25),
                freshnessSeconds: 1200,
              ),
            },
          ),
          deviceIdentityRepository: _FixedDeviceIdentityRepository(),
          nowProvider: () => DateTime(2026, 3, 28, 4, 25),
        );

        final insightState = await _waitForState(
          cubit,
          (state) =>
              state.communityInsightStatus == RailCommunityInsightStatus.stale,
        );
        expect(insightState.sessionStatusSnapshot, isNotNull);
        await cubit.close();
      },
    );

    test('does not refetch community overlay on tick updates', () async {
      DateTime now = DateTime(2026, 3, 28, 4, 25);
      final session = _seedSessions().first;
      final overlayRepository = FakeCommunityOverlayRepository(
        seed: {
          session.sessionId: _overlayResult(
            sessionId: session.sessionId,
            fetchedAt: now,
            freshnessSeconds: 30,
          ),
        },
      );
      final cubit = _buildCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: FakeArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: overlayRepository,
        deviceIdentityRepository: _FixedDeviceIdentityRepository(),
        nowProvider: () => now,
      );

      await _waitForState(
        cubit,
        (state) =>
            state.communityInsightStatus == RailCommunityInsightStatus.ready,
      );
      expect(overlayRepository.fetchCounts[session.sessionId], equals(1));

      now = DateTime(2026, 3, 28, 4, 26);
      await cubit.tick();
      await _waitForState(
        cubit,
        (state) =>
            state.status == RailBoardStatus.ready &&
            state.report.actionReason == RailReportActionReason.eligible,
      );
      expect(overlayRepository.fetchCounts[session.sessionId], equals(1));
      await cubit.close();
    });

    test(
      'persists successful submission ledger across cubit restarts',
      () async {
        final ledger = FakeArrivalReportLedgerRepository();
        final reports = FakeArrivalReportRepository();
        final deviceIdentityRepository = _FixedDeviceIdentityRepository();
        final firstCubit = _buildCubit(
          bundledSchedule: bundledSchedule,
          arrivalReportRepository: reports,
          arrivalReportLedgerRepository: ledger,
          communityOverlayRepository: FakeCommunityOverlayRepository(),
          deviceIdentityRepository: deviceIdentityRepository,
          nowProvider: () => DateTime(2026, 3, 28, 4, 25),
        );

        await _waitForState(
          firstCubit,
          (state) => state.status == RailBoardStatus.ready,
        );
        await firstCubit.submitArrivalReport();
        await _waitForState(
          firstCubit,
          (state) =>
              state.reportSubmissionStatus ==
              RailReportSubmissionStatus.success,
        );
        await firstCubit.close();

        final secondCubit = _buildCubit(
          bundledSchedule: bundledSchedule,
          arrivalReportRepository: reports,
          arrivalReportLedgerRepository: ledger,
          communityOverlayRepository: FakeCommunityOverlayRepository(),
          deviceIdentityRepository: deviceIdentityRepository,
          nowProvider: () => DateTime(2026, 3, 28, 4, 26),
        );

        final readyState = await _waitForState(
          secondCubit,
          (state) =>
              state.status == RailBoardStatus.ready &&
              state.report.actionReason ==
                  RailReportActionReason.alreadySubmitted,
        );
        expect(readyState.report.hasReportedCurrentSession, isTrue);
        expect(
          await ledger.hasSubmitted(
            sessionId: _seedSessions().first.sessionId,
            stationId: 'dhaka',
            deviceId: deviceIdentityRepository.identity.deviceId,
          ),
          isTrue,
        );
        await secondCubit.close();
      },
    );

    test('disables reporting before eligibility window opens', () async {
      final cubit = _buildCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: FakeArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: _FixedDeviceIdentityRepository(),
        nowProvider: () => DateTime(2026, 3, 28, 4, 24),
      );

      final state = await _waitForState(
        cubit,
        (state) =>
            state.status == RailBoardStatus.ready &&
            state.report.actionReason == RailReportActionReason.beforeWindow,
      );
      expect(state.report.visibility, RailReportVisibility.visible);
      expect(state.report.submitEnabled, isFalse);
      await cubit.close();
    });

    test('enables reporting at eligibility window start boundary', () async {
      final cubit = _buildCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: FakeArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: _FixedDeviceIdentityRepository(),
        nowProvider: () => DateTime(2026, 3, 28, 4, 25),
      );

      final state = await _waitForState(
        cubit,
        (state) =>
            state.status == RailBoardStatus.ready &&
            state.report.actionReason == RailReportActionReason.eligible,
      );
      expect(state.report.visibility, RailReportVisibility.visible);
      expect(state.report.submitEnabled, isTrue);
      await cubit.close();
    });

    test(
      'marks reporting unavailable when matching train session is no longer next',
      () async {
        final cubit = _buildCubit(
          bundledSchedule: bundledSchedule,
          arrivalReportRepository: FakeArrivalReportRepository(),
          arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
          communityOverlayRepository: FakeCommunityOverlayRepository(),
          deviceIdentityRepository: _FixedDeviceIdentityRepository(),
          nowProvider: () => DateTime(2026, 3, 28, 5, 31),
        );

        final state = await _waitForState(
          cubit,
          (state) =>
              state.status == RailBoardStatus.ready &&
              state.report.actionReason == RailReportActionReason.noSession &&
              state.report.visibility == RailReportVisibility.visible,
        );
        expect(state.report.visibility, RailReportVisibility.visible);
        expect(state.report.submitEnabled, isFalse);
        await cubit.close();
      },
    );

    test('disables reporting when fetched station capacity is full', () async {
      final reports = FakeArrivalReportRepository();
      final session = _seedSessions().first;
      for (var i = 0; i < 10; i++) {
        await reports.submitArrivalReport(
          ArrivalReportSubmission(
            report: ArrivalReport(
              reportId: 'r-$i',
              sessionId: session.sessionId,
              stationId: 'dhaka',
              deviceId: 'dev-$i',
              observedArrivalAt: DateTime(2026, 3, 28, 4, 30),
              submittedAt: DateTime(2026, 3, 28, 4, 30, i),
            ),
            session: session,
            stationStop: session.stops.first,
          ),
        );
      }

      final cubit = _buildCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: reports,
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: _FixedDeviceIdentityRepository(),
        nowProvider: () => DateTime(2026, 3, 28, 4, 25),
      );

      final state = await _waitForState(
        cubit,
        (state) =>
            state.status == RailBoardStatus.ready &&
            state.report.actionReason ==
                RailReportActionReason.stationCapacityReached,
      );
      expect(state.report.submitEnabled, isFalse);

      await cubit.submitArrivalReport();

      final blockedState = await _waitForState(
        cubit,
        (state) =>
            state.reportSubmissionStatus == RailReportSubmissionStatus.error,
      );
      expect(
        blockedState.reportFeedbackMessage,
        contains('full for this station'),
      );
      await cubit.close();
    });

    test(
      'keeps already-submitted state ahead of station-capacity state',
      () async {
        final reports = FakeArrivalReportRepository();
        final ledger = FakeArrivalReportLedgerRepository();
        final deviceIdentityRepository = _FixedDeviceIdentityRepository();
        final session = _seedSessions().first;

        await ledger.markSubmitted(
          sessionId: session.sessionId,
          stationId: 'dhaka',
          deviceId: deviceIdentityRepository.identity.deviceId,
          submittedAt: DateTime(2026, 3, 28, 4, 25),
        );

        for (var i = 0; i < 10; i++) {
          await reports.submitArrivalReport(
            ArrivalReportSubmission(
              report: ArrivalReport(
                reportId: 'r-$i',
                sessionId: session.sessionId,
                stationId: 'dhaka',
                deviceId: 'dev-$i',
                observedArrivalAt: DateTime(2026, 3, 28, 4, 30),
                submittedAt: DateTime(2026, 3, 28, 4, 30, i),
              ),
              session: session,
              stationStop: session.stops.first,
            ),
          );
        }

        final cubit = _buildCubit(
          bundledSchedule: bundledSchedule,
          arrivalReportRepository: reports,
          arrivalReportLedgerRepository: ledger,
          communityOverlayRepository: FakeCommunityOverlayRepository(),
          deviceIdentityRepository: deviceIdentityRepository,
          nowProvider: () => DateTime(2026, 3, 28, 4, 25),
        );

        final state = await _waitForState(
          cubit,
          (state) =>
              state.status == RailBoardStatus.ready &&
              state.report.actionReason ==
                  RailReportActionReason.alreadySubmitted,
        );
        expect(state.report.hasReportedCurrentSession, isTrue);
        expect(state.report.submitEnabled, isFalse);
        await cubit.close();
      },
    );

    test('recomputes reporting eligibility on tick transition', () async {
      DateTime now = DateTime(2026, 3, 28, 4, 24);
      final cubit = _buildCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: FakeArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: _FixedDeviceIdentityRepository(),
        nowProvider: () => now,
      );

      await _waitForState(
        cubit,
        (state) =>
            state.status == RailBoardStatus.ready &&
            state.report.actionReason == RailReportActionReason.beforeWindow,
      );
      now = DateTime(2026, 3, 28, 4, 25);
      await cubit.tick();
      final unlocked = await _waitForState(
        cubit,
        (state) =>
            state.report.actionReason == RailReportActionReason.eligible &&
            state.report.submitEnabled,
      );
      expect(unlocked.report.visibility, RailReportVisibility.visible);
      expect(unlocked.report.submitEnabled, isTrue);
      await cubit.close();
    });

    test(
      'skips community reporting and insights when community features are disabled',
      () async {
        final reports = FakeArrivalReportRepository();
        final cubit = _buildCubit(
          bundledSchedule: bundledSchedule,
          arrivalReportRepository: reports,
          arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
          communityOverlayRepository: FakeCommunityOverlayRepository(),
          deviceIdentityRepository: _FixedDeviceIdentityRepository(),
          communityFeaturesEnabled: false,
          nowProvider: () => DateTime(2026, 3, 28, 4, 25),
        );

        final ready = await _waitForState(
          cubit,
          (state) => state.status == RailBoardStatus.ready,
        );
        expect(ready.communityFeaturesEnabled, isFalse);
        expect(ready.communityInsightStatus, RailCommunityInsightStatus.idle);

        await cubit.submitArrivalReport();

        expect(
          cubit.state.reportSubmissionStatus,
          RailReportSubmissionStatus.idle,
        );
        final stored = await reports.fetchStopReports(
          sessionId: _seedSessions().first.sessionId,
          stationId: 'dhaka',
        );
        expect(stored, isEmpty);
        await cubit.close();
      },
    );
  });
}

RailBoardCubit _buildCubit({
  required dynamic bundledSchedule,
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
    sessionRepository: FakeSessionRepository(seed: _seedSessions()),
    arrivalReportRepository: arrivalReportRepository,
    arrivalReportLedgerRepository: arrivalReportLedgerRepository,
    communityOverlayRepository: communityOverlayRepository,
    deviceIdentityRepository: deviceIdentityRepository,
    communityFeaturesEnabled: communityFeaturesEnabled,
    nowProvider: nowProvider,
    enableTicker: false,
  );
}

CommunityOverlayResult _overlayResult({
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

Future<RailBoardState> _waitForState(
  RailBoardCubit cubit,
  bool Function(RailBoardState) predicate,
) async {
  final current = cubit.state;
  if (predicate(current)) {
    return current;
  }
  return cubit.stream.firstWhere(predicate);
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

class _FixedDeviceIdentityRepository implements DeviceIdentityRepository {
  _FixedDeviceIdentityRepository()
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

class _ResolvingDeviceIdentityRepository implements DeviceIdentityRepository {
  _ResolvingDeviceIdentityRepository({
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
