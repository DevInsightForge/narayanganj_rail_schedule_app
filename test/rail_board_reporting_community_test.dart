import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/application/models/rail_reporting.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/bloc/rail_board_cubit.dart';

import 'support/bundled_schedule_fixture.dart';
import 'support/community_fakes.dart';
import 'support/rail_board_reporting_harness.dart';

void main() {
  final bundledSchedule = loadBundledScheduleFixture();

  group('RailBoardCubit community reporting', () {
    test('builds ready community insights from aggregate overlay', () async {
      final session = seedRailBoardReportingSessions().first;
      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: FlakyArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(
          seed: {
            session.sessionId: railBoardReportingOverlayResult(
              sessionId: session.sessionId,
              fetchedAt: DateTime(2026, 3, 28, 4, 25),
              freshnessSeconds: 30,
            ),
          },
        ),
        deviceIdentityRepository: FixedDeviceIdentityRepository(),
        nowProvider: () => DateTime(2026, 3, 28, 4, 25),
      );

      final insightState = await waitForRailBoardState(
        cubit,
        (state) =>
            state.communityInsightStatus == RailCommunityInsightStatus.ready,
      );
      expect(insightState.sessionStatusSnapshot, isNotNull);
      expect(insightState.predictedStopTimes, isNotEmpty);
      await cubit.close();
    });

    test(
      'marks community insights error when overlay repository fails',
      () async {
        final overlayRepository = FakeCommunityOverlayRepository()
          ..failFetch = true;
        final cubit = buildRailBoardReportingCubit(
          bundledSchedule: bundledSchedule,
          arrivalReportRepository: FlakyArrivalReportRepository(),
          arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
          communityOverlayRepository: overlayRepository,
          deviceIdentityRepository: FixedDeviceIdentityRepository(),
          nowProvider: () => DateTime(2026, 3, 28, 4, 25),
        );

        final failedInsightState = await waitForRailBoardState(
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
        final session = seedRailBoardReportingSessions().first;
        final cubit = buildRailBoardReportingCubit(
          bundledSchedule: bundledSchedule,
          arrivalReportRepository: FlakyArrivalReportRepository(),
          arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
          communityOverlayRepository: FakeCommunityOverlayRepository(
            seed: {
              session.sessionId: railBoardReportingOverlayResult(
                sessionId: session.sessionId,
                fetchedAt: DateTime(2026, 3, 28, 4, 25),
                freshnessSeconds: 180,
              ),
            },
          ),
          deviceIdentityRepository: FixedDeviceIdentityRepository(),
          nowProvider: () => DateTime(2026, 3, 28, 4, 25),
        );

        final insightState = await waitForRailBoardState(
          cubit,
          (state) =>
              state.communityInsightStatus == RailCommunityInsightStatus.stale,
        );
        expect(insightState.sessionStatusSnapshot, isNotNull);
        await cubit.close();
      },
    );

    test(
      'marks community insights as expired when overlay freshness is too old',
      () async {
        final session = seedRailBoardReportingSessions().first;
        final cubit = buildRailBoardReportingCubit(
          bundledSchedule: bundledSchedule,
          arrivalReportRepository: FlakyArrivalReportRepository(),
          arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
          communityOverlayRepository: FakeCommunityOverlayRepository(
            seed: {
              session.sessionId: railBoardReportingOverlayResult(
                sessionId: session.sessionId,
                fetchedAt: DateTime(2026, 3, 28, 4, 25),
                freshnessSeconds: 360,
              ),
            },
          ),
          deviceIdentityRepository: FixedDeviceIdentityRepository(),
          nowProvider: () => DateTime(2026, 3, 28, 4, 25),
        );

        final insightState = await waitForRailBoardState(
          cubit,
          (state) =>
              state.communityInsightStatus ==
              RailCommunityInsightStatus.expired,
        );
        expect(insightState.sessionStatusSnapshot, isNull);
        expect(insightState.predictedStopTimes, isEmpty);
        await cubit.close();
      },
    );

    test('does not refetch community overlay on tick updates', () async {
      DateTime now = DateTime(2026, 3, 28, 4, 25);
      final session = seedRailBoardReportingSessions().first;
      final overlayRepository = FakeCommunityOverlayRepository(
        seed: {
          session.sessionId: railBoardReportingOverlayResult(
            sessionId: session.sessionId,
            fetchedAt: now,
            freshnessSeconds: 30,
          ),
        },
      );
      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: FlakyArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: overlayRepository,
        deviceIdentityRepository: FixedDeviceIdentityRepository(),
        nowProvider: () => now,
      );

      await waitForRailBoardState(
        cubit,
        (state) =>
            state.communityInsightStatus == RailCommunityInsightStatus.ready,
      );
      expect(overlayRepository.fetchCounts[session.sessionId], equals(1));

      now = DateTime(2026, 3, 28, 4, 26);
      await cubit.tick();
      await waitForRailBoardState(
        cubit,
        (state) =>
            state.status == RailBoardStatus.ready &&
            state.report.actionReason == RailReportActionReason.eligible,
      );
      expect(overlayRepository.fetchCounts[session.sessionId], equals(1));
      await cubit.close();
    });

    test(
      'ages community insight locally until it expires without extra reads',
      () async {
        DateTime now = DateTime(2026, 3, 28, 4, 25);
        final session = seedRailBoardReportingSessions().first;
        final overlayRepository = FakeCommunityOverlayRepository(
          seed: {
            session.sessionId: railBoardReportingOverlayResult(
              sessionId: session.sessionId,
              fetchedAt: now,
              freshnessSeconds: 30,
            ),
          },
        );
        final cubit = buildRailBoardReportingCubit(
          bundledSchedule: bundledSchedule,
          arrivalReportRepository: FlakyArrivalReportRepository(),
          arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
          communityOverlayRepository: overlayRepository,
          deviceIdentityRepository: FixedDeviceIdentityRepository(),
          nowProvider: () => now,
        );

        await waitForRailBoardState(
          cubit,
          (state) =>
              state.communityInsightStatus == RailCommunityInsightStatus.ready,
        );

        for (var i = 0; i < 10; i++) {
          now = now.add(const Duration(seconds: 30));
          await cubit.tick();
        }

        final expiredState = await waitForRailBoardState(
          cubit,
          (state) =>
              state.communityInsightStatus ==
              RailCommunityInsightStatus.expired,
        );
        expect(expiredState.sessionStatusSnapshot, isNull);
        expect(expiredState.predictedStopTimes, isEmpty);
        expect(overlayRepository.fetchCounts[session.sessionId], equals(1));
        await cubit.close();
      },
    );

    test('keeps reporting success local without refetching overlay', () async {
      final reports = FlakyArrivalReportRepository()..failSubmission = false;
      final ledger = FakeArrivalReportLedgerRepository();
      final overlayRepository = FakeCommunityOverlayRepository();
      final deviceIdentityRepository = FixedDeviceIdentityRepository();
      final session = seedRailBoardReportingSessions().first;
      final cubit = buildRailBoardReportingCubit(
        bundledSchedule: bundledSchedule,
        arrivalReportRepository: reports,
        arrivalReportLedgerRepository: ledger,
        communityOverlayRepository: overlayRepository,
        deviceIdentityRepository: deviceIdentityRepository,
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

      expect(
        success.communityInsightStatus,
        isNot(RailCommunityInsightStatus.error),
      );
      expect(overlayRepository.fetchCounts[session.sessionId], equals(1));
      await cubit.close();
    });

    test(
      'skips community reporting and insights when community features are disabled',
      () async {
        final reports = FlakyArrivalReportRepository();
        final cubit = buildRailBoardReportingCubit(
          bundledSchedule: bundledSchedule,
          arrivalReportRepository: reports,
          arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
          communityOverlayRepository: FakeCommunityOverlayRepository(),
          deviceIdentityRepository: FixedDeviceIdentityRepository(),
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
        final stored = await reports.fetchStopReports(
          sessionId: seedRailBoardReportingSessions().first.sessionId,
          serviceDate: seedRailBoardReportingSessions().first.serviceDate,
          stationId: 'dhaka',
        );
        expect(stored, isEmpty);
        await cubit.close();
      },
    );
  });
}
