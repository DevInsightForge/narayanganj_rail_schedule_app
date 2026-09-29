import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/community_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/application/models/rail_reporting.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/bloc/rail_board_cubit.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/rail_board_texts.dart';

import 'support/bundled_schedule_fixture.dart';
import 'support/community_fakes.dart';
import 'support/rail_board_reporting_harness.dart';

void main() {
  final bundledSchedule = loadBundledScheduleFixture();

  group('RailBoardCubit arrival reporting eligibility and submission', () {
    test(
      'enables reporting when overlay has isReportingAvailable true',
      () async {
        final repo = FakeCommunityRepository();
        repo.setOverlay(
          'dhk-ngj-2',
          railBoardReportingOverlayResult(
            sessionId: 'dhk-ngj-2',
            fetchedAt: DateTime(2026, 3, 28, 4, 25),
            freshnessSeconds: 10,
            isReportingAvailable: true,
          ),
        );

        final cubit = buildRailBoardReportingCubit(
          bundledSchedule: bundledSchedule,
          communityRepository: repo,
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
      },
    );

    test(
      'disables reporting when overlay has isReportingAvailable false',
      () async {
        final repo = FakeCommunityRepository();
        repo.setOverlay(
          'dhk-ngj-2',
          railBoardReportingOverlayResult(
            sessionId: 'dhk-ngj-2',
            fetchedAt: DateTime(2026, 3, 28, 4, 20),
            freshnessSeconds: 10,
            isReportingAvailable: false,
          ),
        );

        final cubit = buildRailBoardReportingCubit(
          bundledSchedule: bundledSchedule,
          communityRepository: repo,
          nowProvider: () => DateTime(2026, 3, 28, 4, 20),
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
      },
    );

    test(
      'enables reporting when overlay updates to isReportingAvailable true on tick',
      () async {
        final repo = FakeCommunityRepository();
        repo.setOverlay(
          'dhk-ngj-2',
          railBoardReportingOverlayResult(
            sessionId: 'dhk-ngj-2',
            fetchedAt: DateTime(2026, 3, 28, 4, 24),
            freshnessSeconds: 10,
            isReportingAvailable: false,
          ),
        );

        DateTime now = DateTime(2026, 3, 28, 4, 24);
        final cubit = buildRailBoardReportingCubit(
          bundledSchedule: bundledSchedule,
          communityRepository: repo,
          nowProvider: () => now,
        );

        final locked = await waitForRailBoardState(
          cubit,
          (state) =>
              state.status == RailBoardStatus.ready &&
              state.report.actionReason == RailReportActionReason.beforeWindow,
        );
        expect(locked.report.submitEnabled, isFalse);

        now = DateTime(2026, 3, 28, 4, 25);
        repo.setOverlay(
          'dhk-ngj-2',
          railBoardReportingOverlayResult(
            sessionId: 'dhk-ngj-2',
            fetchedAt: DateTime(2026, 3, 28, 4, 25),
            freshnessSeconds: 0,
            isReportingAvailable: true,
          ),
        );
        await cubit.tick();

        final unlocked = await waitForRailBoardState(
          cubit,
          (state) =>
              state.status == RailBoardStatus.ready &&
              state.report.actionReason == RailReportActionReason.eligible,
        );
        expect(unlocked.report.submitEnabled, isTrue);
        await cubit.close();
      },
    );

    test('hides reporting when community features are disabled', () async {
      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        communityRepository: FakeCommunityRepository(),
        communityFeaturesEnabled: false,
        nowProvider: () => DateTime(2026, 3, 28, 4, 25),
      );

      final state = await waitForRailBoardState(
        cubit,
        (state) => state.status == RailBoardStatus.ready,
      );
      expect(state.report.visibility, RailReportVisibility.hidden);
      expect(state.report.submitEnabled, isFalse);
      await cubit.close();
    });

    test(
      'submits report and transitions to success when API accepts',
      () async {
        final repo = FakeCommunityRepository();
        repo.setOverlay(
          'dhk-ngj-2',
          railBoardReportingOverlayResult(
            sessionId: 'dhk-ngj-2',
            fetchedAt: DateTime(2026, 3, 28, 4, 25),
            freshnessSeconds: 10,
            isReportingAvailable: true,
          ),
        );
        final cubit = buildRailBoardReportingCubit(
          bundledSchedule: bundledSchedule,
          communityRepository: repo,
          nowProvider: () => DateTime(2026, 3, 28, 4, 25),
        );

        await waitForRailBoardState(
          cubit,
          (state) =>
              state.status == RailBoardStatus.ready &&
              state.report.submitEnabled,
        );

        await cubit.submitArrivalReport();

        final successState = await waitForRailBoardState(
          cubit,
          (state) =>
              state.reportSubmissionStatus ==
              RailReportSubmissionStatus.success,
        );
        expect(successState.reportFeedbackMessage, contains('Arrival shared'));
        expect(repo.submissions.length, equals(1));
        expect(repo.submissions.first['tripId'], equals('dhk-ngj-2'));
        expect(repo.submissions.first['stationId'], equals('dhaka'));
        await cubit.close();
      },
    );

    test('displays cooldown message when API returns 429 cooldown', () async {
      final repo = FakeCommunityRepository(
        nextReportResult: const ArrivalReportResult.cooldown(
          retryAfterSeconds: 90,
        ),
      );
      repo.setOverlay(
        'dhk-ngj-2',
        railBoardReportingOverlayResult(
          sessionId: 'dhk-ngj-2',
          fetchedAt: DateTime(2026, 3, 28, 4, 25),
          freshnessSeconds: 10,
          isReportingAvailable: true,
        ),
      );

      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        communityRepository: repo,
        nowProvider: () => DateTime(2026, 3, 28, 4, 25),
      );

      await waitForRailBoardState(
        cubit,
        (state) =>
            state.status == RailBoardStatus.ready && state.report.submitEnabled,
      );

      await cubit.submitArrivalReport();

      final cooldownState = await waitForRailBoardState(
        cubit,
        (state) =>
            state.reportSubmissionStatus == RailReportSubmissionStatus.error,
      );
      expect(cooldownState.reportFeedbackMessage, contains('wait 90s'));
      await cubit.close();
    });

    test(
      'displays updates unavailable and disables submit when API returns 409 station cap reached',
      () async {
        final repo = FakeCommunityRepository(
          nextReportResult: const ArrivalReportResult.stationCapacityReached(),
        );
        repo.setOverlay(
          'dhk-ngj-2',
          railBoardReportingOverlayResult(
            sessionId: 'dhk-ngj-2',
            fetchedAt: DateTime(2026, 3, 28, 4, 25),
            freshnessSeconds: 10,
            isReportingAvailable: true,
          ),
        );

        final cubit = buildRailBoardReportingCubit(
          bundledSchedule: bundledSchedule,
          communityRepository: repo,
          nowProvider: () => DateTime(2026, 3, 28, 4, 25),
        );

        await waitForRailBoardState(
          cubit,
          (state) =>
              state.status == RailBoardStatus.ready &&
              state.report.submitEnabled,
        );

        await cubit.submitArrivalReport();

        final capState = await waitForRailBoardState(
          cubit,
          (state) =>
              state.reportSubmissionStatus ==
                  RailReportSubmissionStatus.error &&
              state.report.actionReason ==
                  RailReportActionReason.stationCapacityReached,
        );
        expect(capState.report.submitEnabled, isFalse);
        expect(
          capState.reportFeedbackMessage,
          equals(RailBoardTexts.updatesUnavailable),
        );
        await cubit.close();
      },
    );

    test('handles network failure gracefully', () async {
      final repo = FakeCommunityRepository()..failSubmission = true;
      repo.setOverlay(
        'dhk-ngj-2',
        railBoardReportingOverlayResult(
          sessionId: 'dhk-ngj-2',
          fetchedAt: DateTime(2026, 3, 28, 4, 25),
          freshnessSeconds: 10,
          isReportingAvailable: true,
        ),
      );

      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        communityRepository: repo,
        nowProvider: () => DateTime(2026, 3, 28, 4, 25),
      );

      await waitForRailBoardState(
        cubit,
        (state) =>
            state.status == RailBoardStatus.ready && state.report.submitEnabled,
      );

      await cubit.submitArrivalReport();

      final errorState = await waitForRailBoardState(
        cubit,
        (state) =>
            state.reportSubmissionStatus == RailReportSubmissionStatus.error,
      );
      expect(errorState.reportFeedbackMessage, contains('Unable to submit'));
      await cubit.close();
    });
  });
}
