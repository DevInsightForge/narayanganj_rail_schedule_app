import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/community_overlay.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/delay_status.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/freshness.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/report_confidence.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/application/models/rail_reporting.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/application/models/rail_widget_payload.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_selection.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_snapshot.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/bloc/rail_board_state.dart';

void main() {
  final fixedNow = DateTime(2026, 10, 27, 7, 10);

  const defaultSelection = RailSelection(
    direction: 'dhaka_to_narayanganj',
    boardingStationId: 'dhaka',
    destinationStationId: 'narayanganj',
  );

  const overdueService = RailServiceSnapshot(
    trainNo: 16,
    servicePeriod: 'early_morning',
    departureTime: '06:52',
    arrivalTime: '07:37',
    waitMinutes: 0,
    etaMinutes: 27,
    stops: [],
    isOverdue: true,
    overdueMinutes: 18,
  );

  const nextBoardableService = RailServiceSnapshot(
    trainNo: 2,
    servicePeriod: 'morning',
    departureTime: '07:30',
    arrivalTime: '08:15',
    waitMinutes: 20,
    etaMinutes: 65,
    stops: [],
  );

  test('returns null when board state is not ready', () {
    const loadingState = RailBoardState(status: RailBoardStatus.loading);
    expect(
      RailWidgetPayload.fromBoardState(loadingState, now: fixedNow),
      isNull,
    );
  });

  test(
    'uses nextDepartureService as primary and isolates distinct overdue report service',
    () {
      const state = RailBoardState(
        status: RailBoardStatus.ready,
        view: RailBoardViewState(
          selection: defaultSelection,
          snapshot: RailBoardSnapshot(
            selectedStationName: 'Dhaka',
            destinationStationName: 'Narayanganj',
            nextService: overdueService,
            upcomingServices: [overdueService, nextBoardableService],
            scheduleVersion: '2026.1',
          ),
        ),
        report: RailBoardReportState(
          visibility: RailReportVisibility.visible,
          submitEnabled: true,
          actionReason: RailReportActionReason.eligible,
        ),
        community: RailBoardCommunityState(
          featuresEnabled: true,
          insightStatus: RailCommunityInsightStatus.ready,
          overlay: CommunityOverlay(
            tripId: 'dhk-ngj-16',
            serviceDate: '2026-10-27',
            delayMinutes: 12,
            delayStatus: DelayStatus.minorDelay,
            freshness: Freshness.live,
            confidence: ReportConfidence(score: 0.9, sampleCount: 3),
            freshnessSeconds: 30,
            isReportingAvailable: true,
          ),
        ),
      );

      final payload = RailWidgetPayload.fromBoardState(state, now: fixedNow);
      expect(payload, isNotNull);
      expect(payload!.hasNextTrain, isTrue);
      expect(payload.nextTrainNo, 2);
      expect(payload.nextDepartureTime, '7:30 AM');
      expect(payload.nextArrivalTime, '8:15 AM');
      expect(payload.hasReportTarget, isTrue);
      expect(payload.reportTrainNo, 16);
      expect(payload.reportScheduledDeparture, '6:52 AM');
      expect(payload.isReportingAvailable, isTrue);
      expect(payload.reportStatusLabel, 'Report arrival');
      expect(payload.communityTripId, 'dhk-ngj-16');
      expect(payload.communityTrainNo, 16);
      expect(payload.communityStatusLabel, 'Live · Train #16 Delayed 12m');
    },
  );

  test('omits community status when overlay tripId does not match any displayed service', () {
    const state = RailBoardState(
      status: RailBoardStatus.ready,
      view: RailBoardViewState(
        selection: defaultSelection,
        snapshot: RailBoardSnapshot(
          selectedStationName: 'Dhaka',
          destinationStationName: 'Narayanganj',
          nextService: nextBoardableService,
          upcomingServices: [nextBoardableService],
          scheduleVersion: '2026.1',
        ),
      ),
      community: RailBoardCommunityState(
        featuresEnabled: true,
        insightStatus: RailCommunityInsightStatus.ready,
        overlay: CommunityOverlay(
          tripId: 'dhk-ngj-99',
          serviceDate: '2026-10-27',
          delayMinutes: 15,
          delayStatus: DelayStatus.majorDelay,
          freshness: Freshness.live,
          confidence: ReportConfidence(score: 0.8, sampleCount: 2),
          freshnessSeconds: 10,
          isReportingAvailable: false,
        ),
      ),
    );

    final payload = RailWidgetPayload.fromBoardState(state, now: fixedNow);
    expect(payload, isNotNull);
    expect(payload!.communityTripId, isNull);
    expect(payload.communityTrainNo, isNull);
    expect(payload.communityStatusLabel, isNull);
    expect(payload.hasReportTarget, isFalse);
  });

  test('distinguishes stale community overlay from live and omits expired overlay', () {
    const staleState = RailBoardState(
      status: RailBoardStatus.ready,
      view: RailBoardViewState(
        selection: defaultSelection,
        snapshot: RailBoardSnapshot(
          selectedStationName: 'Dhaka',
          destinationStationName: 'Narayanganj',
          nextService: nextBoardableService,
          upcomingServices: [nextBoardableService],
          scheduleVersion: '2026.1',
        ),
      ),
      community: RailBoardCommunityState(
        featuresEnabled: true,
        insightStatus: RailCommunityInsightStatus.stale,
        overlay: CommunityOverlay(
          tripId: 'dhk-ngj-2',
          serviceDate: '2026-10-27',
          delayMinutes: 0,
          delayStatus: DelayStatus.onTime,
          freshness: Freshness.stale,
          confidence: ReportConfidence(score: 0.7, sampleCount: 2),
          freshnessSeconds: 240,
          isReportingAvailable: false,
        ),
      ),
    );

    final stalePayload = RailWidgetPayload.fromBoardState(
      staleState,
      now: fixedNow,
    );
    expect(stalePayload!.communityFreshness, 'stale');
    expect(stalePayload.communityTrainNo, 2);
    expect(stalePayload.communityStatusLabel, 'Stale · Train #2 On time');

    final expiredState = staleState.copyWith(
      community: staleState.community.copyWith(
        insightStatus: RailCommunityInsightStatus.expired,
        overlay: staleState.community.overlay!.copyWith(freshnessSeconds: 1500),
      ),
    );
    final expiredPayload = RailWidgetPayload.fromBoardState(
      expiredState,
      now: fixedNow,
    );
    expect(expiredPayload!.communityStatusLabel, isNull);
    expect(expiredPayload.communityTrainNo, isNull);
  });

  test('handles no upcoming boardable train while keeping distinct overdue report target', () {
    const state = RailBoardState(
      status: RailBoardStatus.ready,
      view: RailBoardViewState(
        selection: defaultSelection,
        snapshot: RailBoardSnapshot(
          selectedStationName: 'Dhaka',
          destinationStationName: 'Narayanganj',
          nextService: overdueService,
          upcomingServices: [overdueService],
          scheduleVersion: '2026.1',
        ),
      ),
      report: RailBoardReportState(
        visibility: RailReportVisibility.visible,
        submitEnabled: false,
        actionReason: RailReportActionReason.afterWindow,
      ),
    );

    final payload = RailWidgetPayload.fromBoardState(state, now: fixedNow);
    expect(payload, isNotNull);
    expect(payload!.hasNextTrain, isFalse);
    expect(payload.nextTrainNo, isNull);
    expect(payload.hasReportTarget, isTrue);
    expect(payload.reportTrainNo, 16);
    expect(payload.isReportingAvailable, isFalse);
    expect(payload.reportStatusLabel, 'Reporting unavailable');
  });

  test('round-trips JSON and rejects invalid schema or incomplete payload', () {
    const state = RailBoardState(
      status: RailBoardStatus.ready,
      view: RailBoardViewState(
        selection: defaultSelection,
        snapshot: RailBoardSnapshot(
          selectedStationName: 'Dhaka',
          destinationStationName: 'Narayanganj',
          nextService: nextBoardableService,
          upcomingServices: [nextBoardableService],
          scheduleVersion: '2026.1',
        ),
      ),
    );

    final payload = RailWidgetPayload.fromBoardState(state, now: fixedNow)!;
    final jsonStr = payload.toJsonString();
    final parsed = RailWidgetPayload.tryParseJson(jsonStr);
    expect(parsed, equals(payload));

    expect(RailWidgetPayload.tryParseJson('{"schemaVersion":999}'), isNull);
    expect(RailWidgetPayload.tryParseJson('{"schemaVersion":1}'), isNull);
    expect(RailWidgetPayload.tryParseJson('not-json'), isNull);
  });
}
