import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/data_origin.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/delay_status.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/firebase_auth_readiness.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/predicted_stop_time.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/report_confidence.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/session_status_snapshot.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/application/models/rail_reporting.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_selection.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/services/rail_board_service.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/bloc/rail_board_cubit.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/decision_panel.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/notice_panel.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/footer_panel.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/rail_primitives.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/timeline_panel.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/upcoming_panel.dart';

import 'support/bundled_schedule_fixture.dart';

void main() {
  testWidgets('timeline panel renders scheduled and estimated stops', (
    tester,
  ) async {
    final service = RailBoardService(schedule: loadBundledScheduleFixture());
    final snapshot = service.getSnapshot(
      selection: const RailSelection(
        direction: 'dhaka_to_narayanganj',
        boardingStationId: 'dhaka',
        destinationStationId: 'narayanganj',
      ),
      now: DateTime(2026, 3, 28, 4, 25),
    );

    await tester.pumpWidget(
      _PanelHarness(
        size: const Size(1100, 900),
        service: service,
        child: TimelinePanel(
          snapshot: snapshot,
          predictedStopTimes: [
            PredictedStopTime(
              sessionId: 'session-1',
              stationId: 'narayanganj',
              predictedAt: DateTime(2026, 3, 28, 5, 18),
              referenceStationId: 'dhaka',
              origin: DataOrigin.inferred,
              confidence: const ReportConfidence(
                score: 0.65,
                sampleSize: 2,
                freshnessSeconds: 120,
                agreementScore: 0.7,
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Journey trace'), findsOneWidget);
    expect(find.text('Scheduled and estimated stops'), findsOneWidget);
    expect(find.text('Board here'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('upcoming panel renders empty state without overflow', (
    tester,
  ) async {
    final service = RailBoardService(schedule: loadBundledScheduleFixture());
    final snapshot = service.getSnapshot(
      selection: const RailSelection(
        direction: 'dhaka_to_narayanganj',
        boardingStationId: 'dhaka',
        destinationStationId: 'narayanganj',
      ),
      now: DateTime(2026, 3, 28, 23, 58),
      limit: 1,
    );

    await tester.pumpWidget(
      _PanelHarness(
        size: const Size(390, 844),
        service: service,
        child: UpcomingPanel(snapshot: snapshot),
      ),
    );
    await tester.pump();

    expect(find.text('No later departure'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notice panel and state message support larger text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(1.5),
          ),
          child: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  NoticePanel(),
                  SizedBox(height: 12),
                  RailStateMessage(
                    title: 'Rail board unavailable',
                    message: 'Retry once your connection is back.',
                    icon: Icons.warning_rounded,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Travel note'), findsOneWidget);
    expect(find.text('Rail board unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('community signal stays concise and omits the action hint', (
    tester,
  ) async {
    final service = RailBoardService(schedule: loadBundledScheduleFixture());
    final snapshot = service.getSnapshot(
      selection: const RailSelection(
        direction: 'dhaka_to_narayanganj',
        boardingStationId: 'dhaka',
        destinationStationId: 'narayanganj',
      ),
      now: DateTime(2026, 3, 28, 4, 25),
    );

    await tester.pumpWidget(
      _PanelHarness(
        size: const Size(1100, 900),
        service: service,
        child: DecisionPanel(
          view: RailBoardViewState(
            selection: const RailSelection(
              direction: 'dhaka_to_narayanganj',
              boardingStationId: 'dhaka',
              destinationStationId: 'narayanganj',
            ),
            snapshot: snapshot,
          ),
          report: const RailBoardReportState(
            status: RailReportSubmissionStatus.idle,
            authReadiness: FirebaseAuthReadiness.ready('device-1'),
            visibility: RailReportVisibility.visible,
            submitEnabled: true,
            actionReason: RailReportActionReason.eligible,
          ),
          community: RailBoardCommunityState(
            featuresEnabled: true,
            insightStatus: RailCommunityInsightStatus.ready,
            sessionStatusSnapshot: SessionStatusSnapshot(
              sessionId: 'session-1',
              state: SessionLifecycleState.active,
              delayMinutes: 4,
              delayStatus: DelayStatus.late,
              confidence: const ReportConfidence(
                score: 0.8,
                sampleSize: 3,
                freshnessSeconds: 30,
                agreementScore: 0.75,
              ),
              freshnessSeconds: 45,
              lastObservedAt: DateTime(2026, 3, 28, 4, 24),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Rider reports merged into one delay signal'),
      findsOneWidget,
    );
    expect(find.textContaining('Reporting opens in'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'footer panel opens drawer with about content first and policy hyperlinks',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(390, 844)),
            child: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: FooterPanel(
                  dataSourceLabel: 'Bundled schedule',
                  lastUpdatedAt: null,
                  scheduleVersion: 'v1',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(find.text('App details'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(
        find.text(
          'Narayanganj Commuter helps riders check the Dhaka-Narayanganj commuter schedule quickly, with official timetable data kept as the baseline view.',
        ),
        findsOneWidget,
      );
      expect(find.text('Privacy: '), findsOneWidget);
      expect(find.text('Terms: '), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text('Terms of service'), findsOneWidget);
      expect(find.text('Open link'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}

class _PanelHarness extends StatelessWidget {
  const _PanelHarness({
    required this.size,
    required this.service,
    required this.child,
  });

  final Size size;
  final RailBoardService service;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        home: RepositoryProvider.value(
          value: service,
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
