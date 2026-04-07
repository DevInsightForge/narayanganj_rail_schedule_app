import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/schedule_template.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/train_session.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/services/train_session_factory.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/models/rail_schedule_document_parser.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/repositories/schedule_data_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_selection.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/repositories/selection_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/services/rail_board_service.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/bloc/rail_board_cubit.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/pages/rail_board_page.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/decision_panel.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/footer_panel.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/header_panel.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/notice_panel.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/timeline_panel.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/upcoming_panel.dart';

import 'support/bundled_schedule_fixture.dart';
import 'support/community_fakes.dart';

void main() {
  testWidgets('compact and wide layouts keep the same panel stack', (
    tester,
  ) async {
    final compact = await _pumpBoard(tester, const Size(390, 844));
    final compactCounts = _panelCounts(tester);
    expect(
      compactCounts,
      equals({
        HeaderPanel: 1,
        DecisionPanel: 1,
        TimelinePanel: 1,
        UpcomingPanel: 1,
        NoticePanel: 1,
        FooterPanel: 1,
      }),
    );
    await compact.close();

    final wide = await _pumpBoard(tester, const Size(1280, 900));
    final wideCounts = _panelCounts(tester);
    expect(wideCounts, equals(compactCounts));
    expect(find.byType(DecisionPanel), findsOneWidget);
    expect(find.byType(TimelinePanel), findsOneWidget);
    expect(find.byType(UpcomingPanel), findsOneWidget);
    expect(find.byType(NoticePanel), findsOneWidget);
    expect(find.byType(FooterPanel), findsOneWidget);
    await wide.close();
  });
}

Future<RailBoardCubit> _pumpBoard(WidgetTester tester, Size size) async {
  final cubit = _buildCubit();
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        home: BlocProvider.value(value: cubit, child: const RailBoardPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return cubit;
}

Map<Type, int> _panelCounts(WidgetTester tester) {
  return {
    HeaderPanel: tester.widgetList(find.byType(HeaderPanel)).length,
    DecisionPanel: tester.widgetList(find.byType(DecisionPanel)).length,
    TimelinePanel: tester.widgetList(find.byType(TimelinePanel)).length,
    UpcomingPanel: tester.widgetList(find.byType(UpcomingPanel)).length,
    NoticePanel: tester.widgetList(find.byType(NoticePanel)).length,
    FooterPanel: tester.widgetList(find.byType(FooterPanel)).length,
  };
}

RailBoardCubit _buildCubit() {
  final bundledSchedule = loadBundledScheduleFixture();
  return RailBoardCubit(
    boardService: RailBoardService(schedule: bundledSchedule),
    scheduleDataRepository: _FakeScheduleDataRepository(),
    selectionRepository: _InMemorySelectionRepository(
      const RailSelection(
        direction: 'dhaka_to_narayanganj',
        boardingStationId: 'dhaka',
        destinationStationId: 'narayanganj',
      ),
    ),
    sessionRepository: FakeSessionRepository(seed: _seedSessions()),
    arrivalReportRepository: FakeArrivalReportRepository(),
    arrivalReportLedgerRepository: FakeArrivalReportLedgerRepository(),
    communityOverlayRepository: FakeCommunityOverlayRepository(),
    deviceIdentityRepository: FakeDeviceIdentityRepository(),
    enableTicker: false,
    nowProvider: () => DateTime(2026, 3, 28, 4, 25),
  );
}

List<TrainSession> _seedSessions() {
  const factory = TrainSessionFactory();
  final template = ScheduleTemplate(
    templateId: 'route:02',
    routeId: 'narayanganj_line',
    directionId: 'dhaka_to_narayanganj',
    trainNo: 2,
    servicePeriod: 'early_morning',
    stops: const [
      StationStop(
        stationId: 'dhaka',
        stationName: 'Dhaka',
        sequence: 0,
        scheduledTime: '04:30',
      ),
      StationStop(
        stationId: 'narayanganj',
        stationName: 'Narayanganj',
        sequence: 1,
        scheduledTime: '05:15',
      ),
    ],
  );
  return [
    factory.create(template: template, serviceDate: DateTime(2026, 3, 28)),
  ];
}

class _FakeScheduleDataRepository extends ScheduleDataRepository {
  _FakeScheduleDataRepository() : super(parser: RailScheduleDocumentParser());

  @override
  Future<ScheduleLoadResult?> readStoredSchedule() async => null;

  @override
  Future<ScheduleLoadResult?> fetchRemoteSchedule() async => null;
}

class _InMemorySelectionRepository implements SelectionRepository {
  _InMemorySelectionRepository(this._selection);

  RailSelection? _selection;

  @override
  Future<RailSelection?> read() async => _selection;

  @override
  Future<void> write(RailSelection selection) async {
    _selection = selection;
  }
}
