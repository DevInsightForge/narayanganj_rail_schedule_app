import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_arrival_report_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_arrival_report_ledger_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_community_overlay_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_device_identity_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_rate_limit_policy_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/fake/fake_session_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/schedule_template.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/train_session.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/services/train_session_factory.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/models/rail_schedule_document_parser.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/repositories/schedule_data_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_schedule.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_selection.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/repositories/selection_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/services/rail_board_service.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/bloc/rail_board_bloc.dart';

import 'support/bundled_schedule_fixture.dart';

void main() {
  final bundledSchedule = loadBundledScheduleFixture();
  group('RailBoardBloc startup', () {
    test('loads bundled data when cached and remote are unavailable', () async {
      final bloc = RailBoardBloc(
        boardService: RailBoardService(schedule: bundledSchedule),
        scheduleDataRepository: _FakeScheduleDataRepository(),
        selectionRepository: _InMemorySelectionRepository(),
        sessionRepository: FakeSessionRepository(seed: _seedSessions()),
        arrivalReportRepository: FakeArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: FakeDeviceIdentityRepository(),
        rateLimitPolicyRepository: FakeRateLimitPolicyRepository(),
      );

      final state = await bloc.stream.firstWhere(
        (state) => state.status == RailBoardStatus.ready,
      );

      expect(state.snapshot.dataSourceLabel, equals('Bundled'));
      await bloc.close();
    });

    test('loads cached first, then remote when available', () async {
      final cachedSchedule = bundledSchedule;
      final remoteSchedule = RailSchedule(
        version: '2026.04.remote',
        stations: cachedSchedule.stations,
        directions: cachedSchedule.directions,
        trips: cachedSchedule.trips,
      );

      final bloc = RailBoardBloc(
        boardService: RailBoardService(schedule: bundledSchedule),
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
        sessionRepository: FakeSessionRepository(seed: _seedSessions()),
        arrivalReportRepository: FakeArrivalReportRepository(),
        arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
        communityOverlayRepository: FakeCommunityOverlayRepository(),
        deviceIdentityRepository: FakeDeviceIdentityRepository(),
        rateLimitPolicyRepository: FakeRateLimitPolicyRepository(),
      );

      final firstReady = await bloc.stream.firstWhere(
        (state) => state.status == RailBoardStatus.ready,
      );
      final secondReady = await bloc.stream.firstWhere(
        (state) =>
            state.status == RailBoardStatus.ready &&
            state.snapshot.dataSourceLabel == 'Remote',
      );

      expect(firstReady.snapshot.dataSourceLabel, equals('Cached'));
      expect(secondReady.snapshot.scheduleVersion, equals('2026.04.remote'));
      await bloc.close();
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

class _FakeScheduleDataRepository extends ScheduleDataRepository {
  _FakeScheduleDataRepository({this.stored, this.remote})
    : super(parser: RailScheduleDocumentParser());

  final ScheduleLoadResult? stored;
  final ScheduleLoadResult? remote;

  @override
  Future<ScheduleLoadResult?> readStoredSchedule() async => stored;

  @override
  Future<ScheduleLoadResult?> fetchRemoteSchedule() async => remote;
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
