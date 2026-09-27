import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_selection.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/repositories/selection_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/services/rail_board_service.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/bloc/rail_board_cubit.dart';

import 'support/bundled_schedule_fixture.dart';
import 'support/community_fakes.dart';

void main() {
  final bundledSchedule = loadBundledScheduleFixture();
  group('RailBoardCubit startup', () {
    test('loads bundled schedule on startup', () async {
      final cubit = RailBoardCubit(
        boardService: RailBoardService(schedule: bundledSchedule),
        selectionRepository: _InMemorySelectionRepository(),
        communityRepository: FakeCommunityRepository(),
      );

      final state = await cubit.stream.firstWhere(
        (state) => state.status == RailBoardStatus.ready,
      );

      expect(state.snapshot.scheduleVersion, equals(bundledSchedule.version));
      await cubit.close();
    });

    test('restores persisted selection on startup', () async {
      final repository = _InMemorySelectionRepository();
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
  });
}

class _InMemorySelectionRepository implements SelectionRepository {
  _InMemorySelectionRepository();

  RailSelection? _selection;

  @override
  Future<RailSelection?> read() async => _selection;

  @override
  Future<void> write(RailSelection selection) async {
    _selection = selection;
  }
}
