import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/schedule_template.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/train_session.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/services/train_session_factory.dart';
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
        sessionRepository: FakeSessionRepository(seed: _seedSessions()),
        arrivalReportRepository: FakeArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: FakeDeviceIdentityRepository(),
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
        sessionRepository: FakeSessionRepository(seed: _seedSessions()),
        arrivalReportRepository: FakeArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: FakeDeviceIdentityRepository(),
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

List<TrainSession> _seedSessions() {
  const sessionFactory = TrainSessionFactory();
  final template = ScheduleTemplate(
    templateId: 'route:1',
    routeId: 'narayanganj_line',
    directionId: 'dhaka_to_narayanganj',
    trainNo: 1,
    servicePeriod: 'morning',
    stops: const [
      StationStop(
        stationId: 'dhaka',
        stationName: 'Dhaka',
        sequence: 0,
        scheduledTime: '08:00',
      ),
      StationStop(
        stationId: 'narayanganj',
        stationName: 'Narayanganj',
        sequence: 1,
        scheduledTime: '08:45',
      ),
    ],
  );
  return [
    sessionFactory.create(
      template: template,
      serviceDate: DateTime(2026, 3, 28),
    ),
  ];
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
