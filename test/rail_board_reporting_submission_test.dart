import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/device_identity.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/firebase_auth_readiness.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/application/models/rail_reporting.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/bloc/rail_board_cubit.dart';

import 'support/bundled_schedule_fixture.dart';
import 'support/community_fakes.dart';
import 'support/rail_board_reporting_harness.dart';

void main() {
  final bundledSchedule = loadBundledScheduleFixture();

  group('RailBoardCubit arrival reporting submission', () {
    test('submits one-tap arrival report when session is eligible', () async {
      final reports = FlakyArrivalReportRepository()..failSubmission = false;
      final ledger = FakeArrivalReportLedgerRepository();
      final deviceIdentityRepository = FixedDeviceIdentityRepository();
      final session = seedRailBoardReportingSessions().first;
      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: reports,
        arrivalReportLedgerRepository: ledger,
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: deviceIdentityRepository,
        nowProvider: () => DateTime(2026, 3, 28, 4, 25),
      );

      await waitForRailBoardState(
        cubit,
        (state) => state.status == RailBoardStatus.ready,
      );

      await cubit.submitArrivalReport();

      final reportState = await waitForRailBoardState(
        cubit,
        (state) =>
            state.reportSubmissionStatus == RailReportSubmissionStatus.success,
      );
      expect(reportState.reportFeedbackMessage, contains('Arrival reported'));
      expect(reportState.report.hasReportedCurrentSession, isTrue);
      expect(reportState.report.submitEnabled, isFalse);

      final stored = await reports.fetchStopReports(
        sessionId: session.sessionId,
        serviceDate: session.serviceDate,
        stationId: 'dhaka',
      );
      expect(stored, isNotEmpty);
      expect(
        await ledger.hasSubmitted(
          sessionId: session.sessionId,
          serviceDate: session.serviceDate,
          stationId: 'dhaka',
          deviceId: deviceIdentityRepository.identity.deviceId,
        ),
        isTrue,
      );

      await cubit.submitArrivalReport();
      final duplicateState = await waitForRailBoardState(
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
          sessionId: session.sessionId,
          serviceDate: session.serviceDate,
          stationId: 'dhaka',
        ),
        hasLength(1),
      );

      await cubit.close();
    });

    test('debug bypass submits outside the schedule window', () async {
      final reports = FlakyArrivalReportRepository()..failSubmission = false;
      final ledger = FakeArrivalReportLedgerRepository();
      final deviceIdentityRepository = FixedDeviceIdentityRepository();
      final session = seedRailBoardReportingSessions().first;
      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: reports,
        arrivalReportLedgerRepository: ledger,
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: deviceIdentityRepository,
        communityDebugBypassEnabled: true,
        nowProvider: () => DateTime(2026, 3, 28, 2, 0),
      );

      await waitForRailBoardState(
        cubit,
        (state) => state.status == RailBoardStatus.ready,
      );

      await cubit.submitArrivalReport();

      final success = await waitForRailBoardState(
        cubit,
        (state) =>
            state.reportSubmissionStatus == RailReportSubmissionStatus.success,
      );
      expect(success.reportFeedbackMessage, contains('Arrival reported'));
      expect(
        await reports.fetchStopReports(
          sessionId: session.sessionId,
          serviceDate: session.serviceDate,
          stationId: 'dhaka',
        ),
        hasLength(1),
      );
      await cubit.close();
    });

    test('hides reporting action while auth readiness is resolving', () async {
      final readinessCompleter = Completer<FirebaseAuthReadiness>();
      final deviceIdentityRepository = ResolvingDeviceIdentityRepository(
        readiness: readinessCompleter.future,
        identity: DeviceIdentity(
          deviceId: 'device-1',
          createdAt: DateTime(2026, 3, 28, 4),
          lastSeenAt: DateTime(2026, 3, 28, 4),
        ),
      );
      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: FlakyArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: deviceIdentityRepository,
        nowProvider: () => DateTime(2026, 3, 28, 4, 25),
      );

      final resolvingState = await waitForRailBoardState(
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
      final readyState = await waitForRailBoardState(
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
      final deviceIdentityRepository = ResolvingDeviceIdentityRepository(
        readiness: Future.value(const FirebaseAuthReadiness.failed()),
        identity: DeviceIdentity(
          deviceId: 'device-1',
          createdAt: DateTime(2026, 3, 28, 4),
          lastSeenAt: DateTime(2026, 3, 28, 4),
        ),
      );
      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: FlakyArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: deviceIdentityRepository,
        nowProvider: () => DateTime(2026, 3, 28, 4, 25),
      );

      final failedState = await waitForRailBoardState(
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

    test(
      'does not queue failed reports and retries only on explicit submit',
      () async {
        final reports = FlakyArrivalReportRepository();
        final ledger = FakeArrivalReportLedgerRepository();
        final deviceIdentityRepository = FixedDeviceIdentityRepository();
        final session = seedRailBoardReportingSessions().first;
        final cubit = buildRailBoardReportingCubit(
          bundledSchedule: bundledSchedule,
          arrivalReportRepository: reports,
          arrivalReportLedgerRepository: ledger,
          communityOverlayRepository: FakeCommunityOverlayRepository(),
          deviceIdentityRepository: deviceIdentityRepository,
          nowProvider: () => DateTime(2026, 3, 28, 4, 25),
        );

        await waitForRailBoardState(
          cubit,
          (state) => state.status == RailBoardStatus.ready,
        );

        await cubit.submitArrivalReport();
        await waitForRailBoardState(
          cubit,
          (state) =>
              state.reportSubmissionStatus == RailReportSubmissionStatus.error,
        );
        expect(reports.submitted, isEmpty);
        expect(
          await ledger.hasSubmitted(
            sessionId: session.sessionId,
            serviceDate: session.serviceDate,
            stationId: 'dhaka',
            deviceId: deviceIdentityRepository.identity.deviceId,
          ),
          isFalse,
        );

        reports.failSubmission = false;
        await cubit.submitArrivalReport();
        await waitForRailBoardState(
          cubit,
          (state) =>
              state.reportSubmissionStatus ==
              RailReportSubmissionStatus.success,
        );
        expect(reports.submitted, hasLength(1));
        await cubit.close();
      },
    );
  });
}
