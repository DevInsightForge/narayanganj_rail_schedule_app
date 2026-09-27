import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/application/models/rail_reporting.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/bloc/rail_board_cubit.dart';

import 'support/bundled_schedule_fixture.dart';
import 'support/community_fakes.dart';
import 'support/rail_board_reporting_harness.dart';

void main() {
  final bundledSchedule = loadBundledScheduleFixture();

  group('RailBoardCubit community reporting', () {
    test('builds ready community insights from overlay', () async {
      const tripId = 'dhk-ngj-2';
      final communityRepository = FakeCommunityRepository(
        seed: {
          tripId: railBoardReportingOverlayResult(
            sessionId: tripId,
            fetchedAt: DateTime(2026, 3, 28, 4, 25),
            freshnessSeconds: 30,
          ),
        },
      );
      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        communityRepository: communityRepository,
        nowProvider: () => DateTime(2026, 3, 28, 4, 25),
      );

      final insightState = await waitForRailBoardState(
        cubit,
        (state) =>
            state.communityInsightStatus == RailCommunityInsightStatus.ready,
      );
      expect(insightState.overlay, isNotNull);
      expect(insightState.predictedStopTimes, isNotEmpty);
      await cubit.close();
    });

    test(
      'marks community insights error when overlay repository fails',
      () async {
        final communityRepository = FakeCommunityRepository()..failFetch = true;
        final cubit = buildRailBoardReportingCubit(
          bundledSchedule: bundledSchedule,
          communityRepository: communityRepository,
          nowProvider: () => DateTime(2026, 3, 28, 4, 25),
        );

        final failedInsightState = await waitForRailBoardState(
          cubit,
          (state) =>
              state.communityInsightStatus == RailCommunityInsightStatus.error,
        );
        expect(failedInsightState.overlay, isNull);
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
        const tripId = 'dhk-ngj-2';
        final communityRepository = FakeCommunityRepository(
          seed: {
            tripId: railBoardReportingOverlayResult(
              sessionId: tripId,
              fetchedAt: DateTime(2026, 3, 28, 4, 25),
              freshnessSeconds: 240,
            ),
          },
        );
        final cubit = buildRailBoardReportingCubit(
          bundledSchedule: bundledSchedule,
          communityRepository: communityRepository,
          nowProvider: () => DateTime(2026, 3, 28, 4, 25),
        );

        final insightState = await waitForRailBoardState(
          cubit,
          (state) =>
              state.communityInsightStatus == RailCommunityInsightStatus.stale,
        );
        expect(insightState.overlay, isNotNull);
        await cubit.close();
      },
    );

    test(
      'marks community insights as expired when overlay freshness is too old',
      () async {
        const tripId = 'dhk-ngj-2';
        final communityRepository = FakeCommunityRepository(
          seed: {
            tripId: railBoardReportingOverlayResult(
              sessionId: tripId,
              fetchedAt: DateTime(2026, 3, 28, 4, 25),
              freshnessSeconds: 1300,
            ),
          },
        );
        final cubit = buildRailBoardReportingCubit(
          bundledSchedule: bundledSchedule,
          communityRepository: communityRepository,
          nowProvider: () => DateTime(2026, 3, 28, 4, 25),
        );

        final insightState = await waitForRailBoardState(
          cubit,
          (state) =>
              state.communityInsightStatus ==
              RailCommunityInsightStatus.expired,
        );
        expect(insightState.overlay, isNotNull);
        expect(insightState.predictedStopTimes, isNotEmpty);
        await cubit.close();
      },
    );

    test('refetches community overlay on foreground interval tick', () async {
      DateTime now = DateTime(2026, 3, 28, 4, 25);
      const tripId = 'dhk-ngj-2';
      final communityRepository = FakeCommunityRepository(
        seed: {
          tripId: railBoardReportingOverlayResult(
            sessionId: tripId,
            fetchedAt: now,
            freshnessSeconds: 30,
          ),
        },
      );
      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        communityRepository: communityRepository,
        nowProvider: () => now,
      );

      await waitForRailBoardState(
        cubit,
        (state) =>
            state.communityInsightStatus == RailCommunityInsightStatus.ready,
      );
      expect(communityRepository.fetchCounts[tripId], equals(1));

      now = DateTime(2026, 3, 28, 4, 26);
      await cubit.tick();
      await waitForRailBoardState(
        cubit,
        (state) =>
            state.status == RailBoardStatus.ready &&
            state.report.actionReason == RailReportActionReason.eligible,
      );
      expect(communityRepository.fetchCounts[tripId], equals(2));
      await cubit.close();
    });

    test('ages community insight locally when ticking', () async {
      final now = DateTime(2026, 3, 28, 4, 25);
      const tripId = 'dhk-ngj-2';
      final communityRepository = FakeCommunityRepository(
        seed: {
          tripId: railBoardReportingOverlayResult(
            sessionId: tripId,
            fetchedAt: now,
            freshnessSeconds: 30,
          ),
        },
      );
      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        communityRepository: communityRepository,
        nowProvider: () => now,
      );

      await waitForRailBoardState(
        cubit,
        (state) =>
            state.communityInsightStatus == RailCommunityInsightStatus.ready,
      );

      communityRepository.setOverlay(
        tripId,
        railBoardReportingOverlayResult(
          sessionId: tripId,
          fetchedAt: now,
          freshnessSeconds: 1300,
        ),
      );

      await cubit.tick();

      final expiredState = await waitForRailBoardState(
        cubit,
        (state) =>
            state.communityInsightStatus == RailCommunityInsightStatus.expired,
      );
      expect(expiredState.overlay, isNotNull);
      await cubit.close();
    });

    test('refreshes overlay on report submission success', () async {
      const tripId = 'dhk-ngj-2';
      final communityRepository = FakeCommunityRepository(
        seed: {
          tripId: railBoardReportingOverlayResult(
            sessionId: tripId,
            fetchedAt: DateTime(2026, 3, 28, 4, 25),
            freshnessSeconds: 10,
          ),
        },
      );
      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        communityRepository: communityRepository,
        nowProvider: () => DateTime(2026, 3, 28, 4, 25),
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

      expect(success.communityInsightStatus, RailCommunityInsightStatus.ready);
      expect(communityRepository.submissions, isNotEmpty);
      expect(
        communityRepository.submissions.first['tripId'],
        equals('dhk-ngj-2'),
      );
      await cubit.close();
    });

    test(
      'skips community reporting and insights when community features are disabled',
      () async {
        final communityRepository = FakeCommunityRepository();
        final cubit = buildRailBoardReportingCubit(
          bundledSchedule: bundledSchedule,
          communityRepository: communityRepository,
          communityFeaturesEnabled: false,
          nowProvider: () => DateTime(2026, 3, 28, 4, 25),
        );

        final ready = await waitForRailBoardState(
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
        expect(communityRepository.submissions, isEmpty);
        await cubit.close();
      },
    );
  });
}
