import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/datasources/static_schedule_data_source.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/models/rail_schedule_document_parser.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/repositories/schedule_data_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_schedule.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_selection.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/repositories/selection_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/services/rail_board_service.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/bloc/rail_board_bloc.dart';

void main() {
  group('RailBoardBloc startup', () {
    test('loads bundled data when cached and remote are unavailable', () async {
      final bloc = RailBoardBloc(
        boardService: RailBoardService(schedule: StaticScheduleDataSource.schedule),
        scheduleDataRepository: _FakeScheduleDataRepository(),
        selectionRepository: _InMemorySelectionRepository(),
      );

      final state = await bloc.stream.firstWhere(
        (state) => state.status == RailBoardStatus.ready,
      );

      expect(state.snapshot.dataSourceLabel, equals('Bundled'));
      await bloc.close();
    });

    test('loads cached first, then remote when available', () async {
      final cachedSchedule = StaticScheduleDataSource.schedule;
      final remoteSchedule = RailSchedule(
        version: '2026.04.remote',
        stations: cachedSchedule.stations,
        directions: cachedSchedule.directions,
        trips: cachedSchedule.trips,
      );

      final bloc = RailBoardBloc(
        boardService: RailBoardService(schedule: StaticScheduleDataSource.schedule),
        scheduleDataRepository: _FakeScheduleDataRepository(
          stored: ScheduleLoadResult(
            schedule: cachedSchedule,
            source: ScheduleDataSource.cached,
            loadedAt: DateTime(2026, 3, 27, 8),
          ),
          remote: ScheduleLoadResult(
            schedule: remoteSchedule,
            source: ScheduleDataSource.remote,
            loadedAt: DateTime(2026, 3, 27, 9),
          ),
        ),
        selectionRepository: _InMemorySelectionRepository(),
      );

      final firstReady = await bloc.stream.firstWhere(
        (state) => state.status == RailBoardStatus.ready,
      );
      final secondReady = await bloc.stream.firstWhere(
        (state) => state.status == RailBoardStatus.ready &&
            state.snapshot.dataSourceLabel == 'Remote',
      );

      expect(firstReady.snapshot.dataSourceLabel, equals('Cached'));
      expect(secondReady.snapshot.scheduleVersion, equals('2026.04.remote'));
      await bloc.close();
    });
  });
}

class _FakeScheduleDataRepository extends ScheduleDataRepository {
  _FakeScheduleDataRepository({this.stored, this.remote})
      : super(parser: RailScheduleDocumentParser());

  final ScheduleLoadResult? stored;
  final ScheduleLoadResult? remote;

  @override
  Future<ScheduleLoadResult?> readStoredSchedule() async => stored;

  @override
  Future<ScheduleLoadResult?> fetchRemoteSchedule({String? url}) async => remote;
}

class _InMemorySelectionRepository implements SelectionRepository {
  RailSelection? _selection;

  @override
  Future<RailSelection?> read() async => _selection;

  @override
  Future<void> write(RailSelection selection) async {
    _selection = selection;
  }
}
