import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/arrival_report.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/arrival_report_submission.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/application/models/rail_reporting.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/bloc/rail_board_cubit.dart';

import 'support/bundled_schedule_fixture.dart';
import 'support/community_fakes.dart';
import 'support/rail_board_reporting_harness.dart';

void main() {
  final bundledSchedule = loadBundledScheduleFixture();

  group('RailBoardCubit arrival reporting eligibility', () {
    test('fails gracefully when no active report window exists', () async {
      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: FlakyArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: FixedDeviceIdentityRepository(),
        nowProvider: () => DateTime(2026, 3, 28, 2, 0),
      );

      await waitForRailBoardState(
        cubit,
        (state) => state.status == RailBoardStatus.ready,
      );

      await cubit.submitArrivalReport();

      final reportState = await waitForRailBoardState(
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

    test('disables reporting before eligibility window opens', () async {
      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: FlakyArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: FixedDeviceIdentityRepository(),
        nowProvider: () => DateTime(2026, 3, 28, 4, 24),
      );

      final state = await waitForRailBoardState(
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
      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: FlakyArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: FixedDeviceIdentityRepository(),
        nowProvider: () => DateTime(2026, 3, 28, 4, 25),
      );

      final state = await waitForRailBoardState(
        cubit,
        (state) =>
            state.status == RailBoardStatus.ready &&
            state.report.actionReason == RailReportActionReason.eligible,
      );
      expect(state.report.visibility, RailReportVisibility.visible);
      expect(state.report.submitEnabled, isTrue);
      await cubit.close();
    });

    test('debug bypass keeps reporting enabled outside the window', () async {
      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: FlakyArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: FixedDeviceIdentityRepository(),
        communityDebugBypassEnabled: true,
        nowProvider: () => DateTime(2026, 3, 28, 2, 0),
      );

      final state = await waitForRailBoardState(
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
        final cubit = buildRailBoardReportingCubit(
          bundledSchedule: bundledSchedule,
          arrivalReportRepository: FlakyArrivalReportRepository(),
          arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
          communityOverlayRepository: FakeCommunityOverlayRepository(),
          deviceIdentityRepository: FixedDeviceIdentityRepository(),
          nowProvider: () => DateTime(2026, 3, 28, 5, 31),
        );

        final state = await waitForRailBoardState(
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
      final reports = FlakyArrivalReportRepository()..failSubmission = false;
      final session = seedRailBoardReportingSessions().first;
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

      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: reports,
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: FixedDeviceIdentityRepository(),
        nowProvider: () => DateTime(2026, 3, 28, 4, 25),
      );

      final state = await waitForRailBoardState(
        cubit,
        (state) =>
            state.status == RailBoardStatus.ready &&
            state.report.actionReason ==
                RailReportActionReason.stationCapacityReached,
      );
      expect(state.report.submitEnabled, isFalse);

      await cubit.submitArrivalReport();

      final blockedState = await waitForRailBoardState(
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
        final reports = FlakyArrivalReportRepository();
        reports.failSubmission = false;
        final ledger = FakeArrivalReportLedgerRepository();
        final deviceIdentityRepository = FixedDeviceIdentityRepository();
        final session = seedRailBoardReportingSessions().first;

        await ledger.markSubmitted(
          sessionId: session.sessionId,
          serviceDate: session.serviceDate,
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

        final cubit = buildRailBoardReportingCubit(
          bundledSchedule: bundledSchedule,
          arrivalReportRepository: reports,
          arrivalReportLedgerRepository: ledger,
          communityOverlayRepository: FakeCommunityOverlayRepository(),
          deviceIdentityRepository: deviceIdentityRepository,
          nowProvider: () => DateTime(2026, 3, 28, 4, 25),
        );

        final state = await waitForRailBoardState(
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
      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: FlakyArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: FixedDeviceIdentityRepository(),
        nowProvider: () => now,
      );

      await waitForRailBoardState(
        cubit,
        (state) =>
            state.status == RailBoardStatus.ready &&
            state.report.actionReason == RailReportActionReason.beforeWindow,
      );
      now = DateTime(2026, 3, 28, 4, 25);
      await cubit.tick();
      final unlocked = await waitForRailBoardState(
        cubit,
        (state) =>
            state.report.actionReason == RailReportActionReason.eligible &&
            state.report.submitEnabled,
      );
      expect(unlocked.report.visibility, RailReportVisibility.visible);
      expect(unlocked.report.submitEnabled, isTrue);
      await cubit.close();
    });
  });
}
