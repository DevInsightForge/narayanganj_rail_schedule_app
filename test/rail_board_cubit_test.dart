import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_selection.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/services/rail_board_service.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/bloc/rail_board_cubit.dart';

import 'support/bundled_schedule_fixture.dart';
import 'support/community_fakes.dart';
import 'support/rail_board_reporting_harness.dart';

void main() {
  final bundledSchedule = loadBundledScheduleFixture();
  group('RailBoardCubit startup', () {
    test('loads bundled schedule on startup', () async {
      final cubit = RailBoardCubit(
        boardService: RailBoardService(schedule: bundledSchedule),
        selectionRepository: InMemorySelectionRepository(),
        communityRepository: FakeCommunityRepository(),
      );

      final state = await cubit.stream.firstWhere(
        (state) => state.status == RailBoardStatus.ready,
      );

      expect(state.snapshot.scheduleVersion, equals(bundledSchedule.version));
      await cubit.close();
    });

    test('restores persisted selection on startup', () async {
      final repository = InMemorySelectionRepository();
      await repository.write(
        const RailSelection(
          direction: 'narayanganj_to_dhaka',
          boardingStationId: 'chashara',
          destinationStationId: 'dhaka',
        ),
      );

      final cubit = RailBoardCubit(
        boardService: RailBoardService(schedule: bundledSchedule),
        selectionRepository: repository,
        communityRepository: FakeCommunityRepository(),
      );

      final state = await cubit.stream.firstWhere(
        (state) => state.status == RailBoardStatus.ready,
      );

      expect(state.selection.direction, equals('narayanganj_to_dhaka'));
      expect(state.selection.boardingStationId, equals('chashara'));
      expect(state.selection.destinationStationId, equals('dhaka'));
      await cubit.close();
    });

    test('swaps direction and stations smoothly', () async {
      final repository = InMemorySelectionRepository();
      final cubit = RailBoardCubit(
        boardService: RailBoardService(schedule: bundledSchedule),
        selectionRepository: repository,
        communityRepository: FakeCommunityRepository(),
      );

      await cubit.stream.firstWhere(
        (state) => state.status == RailBoardStatus.ready,
      );

      await cubit.changeDirection('dhaka_to_narayanganj');
      await cubit.changeBoarding('dhaka');
      await cubit.changeDestination('chashara');
      await cubit.swapDirectionAndStations();

      expect(cubit.state.selection.direction, equals('narayanganj_to_dhaka'));
      expect(cubit.state.selection.boardingStationId, equals('chashara'));
      expect(cubit.state.selection.destinationStationId, equals('dhaka'));
      await cubit.close();
    });

    test('previews upcoming train and resets cleanly', () async {
      final cubit = RailBoardCubit(
        boardService: RailBoardService(schedule: bundledSchedule),
        selectionRepository: InMemorySelectionRepository(),
        communityRepository: FakeCommunityRepository(),
      );

      final state = await cubit.stream.firstWhere(
        (state) => state.status == RailBoardStatus.ready,
      );

      final upcoming = state.snapshot.upcomingServices;
      if (upcoming.length > 1) {
        final secondTrainNo = upcoming[1].trainNo;
        cubit.previewService(secondTrainNo);
        expect(cubit.state.view.previewTrainNo, equals(secondTrainNo));
        expect(cubit.state.view.activeService?.trainNo, equals(secondTrainNo));
        expect(cubit.state.view.isPreviewingUpcoming, isTrue);

        cubit.previewService(null);
        expect(cubit.state.view.previewTrainNo, isNull);
        expect(
          cubit.state.view.activeService?.trainNo,
          equals(state.snapshot.nextService?.trainNo),
        );
        expect(cubit.state.view.isPreviewingUpcoming, isFalse);
      }

      await cubit.close();
    });

    test('toggles timeline expansion state', () async {
      final cubit = RailBoardCubit(
        boardService: RailBoardService(schedule: bundledSchedule),
        selectionRepository: InMemorySelectionRepository(),
        communityRepository: FakeCommunityRepository(),
      );

      await cubit.stream.firstWhere(
        (state) => state.status == RailBoardStatus.ready,
      );

      expect(cubit.state.view.isTimelineCollapsed, isFalse);
      cubit.toggleTimelineExpansion();
      expect(cubit.state.view.isTimelineCollapsed, isTrue);
      cubit.toggleTimelineExpansion();
      expect(cubit.state.view.isTimelineCollapsed, isFalse);
      await cubit.close();
    });
  });
}
