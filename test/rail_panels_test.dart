import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/community_overlay.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/data_origin.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/delay_status.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/freshness.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/predicted_stop_time.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/report_confidence.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/application/models/rail_reporting.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_selection.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/services/rail_board_service.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/bloc/rail_board_cubit.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/decision_panel.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/rail_board_texts.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/notice_panel.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/footer_panel.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/header_panel_hero.dart';
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
              confidence: const ReportConfidence(score: 0.65, sampleCount: 2),
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text(RailBoardTexts.routeStopsEyebrow), findsOneWidget);
    expect(find.text(RailBoardTexts.scheduledStopsTitle), findsOneWidget);
    expect(find.text(RailBoardTexts.boardHere), findsOneWidget);
    expect(find.textContaining(RailBoardTexts.plannedLabel), findsWidgets);
    expect(find.textContaining(RailBoardTexts.liveEstimateLabel), findsWidgets);
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

    expect(find.text(RailBoardTexts.noMoreDeparturesTitle), findsOneWidget);
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
                    title: RailBoardTexts.boardUnavailableTitle,
                    message: RailBoardTexts.boardUnavailableMessage,
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

    expect(find.text(RailBoardTexts.noticeTitle), findsOneWidget);
    expect(find.text(RailBoardTexts.boardUnavailableTitle), findsOneWidget);
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
            visibility: RailReportVisibility.visible,
            submitEnabled: true,
            actionReason: RailReportActionReason.eligible,
          ),
          community: RailBoardCommunityState(
            featuresEnabled: true,
            insightStatus: RailCommunityInsightStatus.ready,
            overlay: CommunityOverlay(
              tripId: 'session-1',
              serviceDate: '2026-03-28',
              delayMinutes: 4,
              delayStatus: DelayStatus.minorDelay,
              freshness: Freshness.live,
              confidence: const ReportConfidence(score: 0.8, sampleCount: 3),
              freshnessSeconds: 45,
              lastReportedAt:
                  DateTime(2026, 3, 28, 4, 24).millisecondsSinceEpoch ~/ 1000,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(RailBoardTexts.liveRiderUpdatesReady), findsOneWidget);
    expect(find.textContaining('Reporting opens in'), findsNothing);
    expect(find.textContaining('Live update'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('departure hero keeps the route header free of ETA text', (
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
        size: const Size(390, 844),
        service: service,
        child: HeaderPanelHero(
          view: RailBoardViewState(
            selection: const RailSelection(
              direction: 'dhaka_to_narayanganj',
              boardingStationId: 'dhaka',
              destinationStationId: 'narayanganj',
            ),
            snapshot: snapshot,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Train 2'), findsWidgets);
    expect(find.textContaining('ETA'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'community report button stays disabled outside the boarding window',
    (tester) async {
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
              visibility: RailReportVisibility.visible,
              submitEnabled: false,
              actionReason: RailReportActionReason.afterWindow,
            ),
            community: RailBoardCommunityState(
              featuresEnabled: true,
              insightStatus: RailCommunityInsightStatus.ready,
            ),
          ),
        ),
      );
      await tester.pump();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
      expect(find.text(RailBoardTexts.reportingClosedNow), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'footer panel opens drawer with about content first and policy hyperlinks',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(390, 844)),
            child: Scaffold(
              body: Padding(padding: EdgeInsets.all(16), child: FooterPanel()),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text(RailBoardTexts.aboutButton));
      await tester.pumpAndSettle();

      expect(find.text(RailBoardTexts.aboutSheetEyebrow), findsOneWidget);
      expect(find.text(RailBoardTexts.footerAboutParagraphOne), findsOneWidget);
      expect(find.text(RailBoardTexts.appVersion), findsOneWidget);
      expect(find.text('${RailBoardTexts.privacyLabel}: '), findsOneWidget);
      expect(find.text('${RailBoardTexts.termsLabel}: '), findsOneWidget);
      expect(find.text(RailBoardTexts.privacyPolicyValue), findsOneWidget);
      expect(find.text(RailBoardTexts.termsOfServiceValue), findsOneWidget);
      expect(find.text(RailBoardTexts.openAction), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('timeline panel highlights passed and approaching stops', (
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
              stationId: 'dhaka',
              predictedAt: DateTime(2026, 3, 28, 4, 20),
              referenceStationId: 'dhaka',
              origin: DataOrigin.inferred,
              confidence: const ReportConfidence(score: 0.8, sampleCount: 3),
              isPassed: true,
            ),
            PredictedStopTime(
              sessionId: 'session-1',
              stationId: 'gandaria',
              predictedAt: DateTime(2026, 3, 28, 4, 35),
              referenceStationId: 'dhaka',
              origin: DataOrigin.inferred,
              confidence: const ReportConfidence(score: 0.8, sampleCount: 3),
              isPassed: false,
            ),
            PredictedStopTime(
              sessionId: 'session-1',
              stationId: 'narayanganj',
              predictedAt: DateTime(2026, 3, 28, 5, 18),
              referenceStationId: 'dhaka',
              origin: DataOrigin.inferred,
              confidence: const ReportConfidence(score: 0.8, sampleCount: 3),
              isPassed: false,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text(RailBoardTexts.departedHere), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(find.text(RailBoardTexts.nextStopHere), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'decision panel renders unified community telemetry and reported badge',
    (tester) async {
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
              status: RailReportSubmissionStatus.success,
              visibility: RailReportVisibility.visible,
              submitEnabled: false,
              actionReason: RailReportActionReason.eligible,
            ),
            community: RailBoardCommunityState(
              featuresEnabled: true,
              insightStatus: RailCommunityInsightStatus.ready,
              overlay: CommunityOverlay(
                tripId: 'session-1',
                serviceDate: '2026-03-28',
                delayMinutes: 4,
                delayStatus: DelayStatus.minorDelay,
                freshness: Freshness.live,
                confidence: const ReportConfidence(score: 0.85, sampleCount: 5),
                freshnessSeconds: 60,
                lastReportedAt:
                    DateTime(2026, 3, 28, 4, 24).millisecondsSinceEpoch ~/ 1000,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(RailBoardTexts.arrivalSharedThankYou), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.textContaining('85% confidence'), findsOneWidget);
      expect(find.textContaining('5 reports'), findsOneWidget);
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
