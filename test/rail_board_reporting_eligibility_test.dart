import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/community_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/application/models/rail_reporting.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/bloc/rail_board_cubit.dart';

import 'support/bundled_schedule_fixture.dart';
import 'support/community_fakes.dart';
import 'support/rail_board_reporting_harness.dart';

void main() {
  final bundledSchedule = loadBundledScheduleFixture();

  group('RailBoardCubit arrival reporting eligibility and submission', () {
    test('enables reporting when active train service exists', () async {
      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        communityRepository: FakeCommunityRepository(),
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

    test(
      'disables reporting when scheduled train departure is outside window',
      () async {
        final cubit = buildRailBoardReportingCubit(
          bundledSchedule: bundledSchedule,
          communityRepository: FakeCommunityRepository(),
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
      'enables reporting when scheduled departure enters window on tick',
      () async {
        DateTime now = DateTime(2026, 3, 28, 4, 24);
        final cubit = buildRailBoardReportingCubit(
          bundledSchedule: bundledSchedule,
          communityRepository: FakeCommunityRepository(),
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
        expect(
          successState.reportFeedbackMessage,
          contains('Arrival confirmed'),
        );
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

    test('handles network failure gracefully', () async {
      final repo = FakeCommunityRepository()..failSubmission = true;

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
      expect(
        errorState.reportFeedbackMessage,
        contains('Failed to submit report'),
      );
      await cubit.close();
    });
  });
}
