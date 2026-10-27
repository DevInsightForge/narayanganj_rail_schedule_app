import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/community_overlay.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/delay_status.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/freshness.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/report_confidence.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/community_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/application/models/rail_report_deep_link.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/data/repositories/bundled_schedule_source.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_selection.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/repositories/selection_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/services/rail_board_service.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/bloc/rail_board_cubit.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/widgets/rail_board_texts.dart';

class _InMemorySelectionRepository implements SelectionRepository {
  _InMemorySelectionRepository([this.stored]);
  RailSelection? stored;

  @override
  Future<RailSelection?> read() async => stored;

  @override
  Future<void> write(RailSelection selection) async {
    stored = selection;
  }
}

class _ConfigurableCommunityRepository implements CommunityRepository {
  _ConfigurableCommunityRepository({this.overlay});

  CommunityOverlay? overlay;
  int submitCallCount = 0;

  @override
  Future<CommunityOverlay?> fetchOverlay({
    required String tripId,
    required String stationId,
  }) async {
    return overlay;
  }

  @override
  Future<ArrivalReportResult> submitArrivalReport({
    required String tripId,
    required String stationId,
  }) async {
    submitCallCount += 1;
    return const ArrivalReportResult.accepted();
  }
}

void main() {
  test('parses board, valid report, and malformed report URIs accurately', () {
    expect(RailReportDeepLink.parse(null).kind, RailDeepLinkKind.none);
    expect(RailReportDeepLink.parse(Uri.parse('')).kind, RailDeepLinkKind.none);
    expect(
      RailReportDeepLink.parse(
        Uri.parse('com.devinsightforge.narayanganjcommuter://board'),
      ).kind,
      RailDeepLinkKind.board,
    );
    expect(
      RailReportDeepLink.parse(
        Uri.parse('com.devinsightforge.narayanganjcommuter://report'),
      ).kind,
      RailDeepLinkKind.invalidReport,
    );
    expect(
      RailReportDeepLink.parse(
        Uri.parse(
          'com.devinsightforge.narayanganjcommuter://report?trainNo=abc&direction=dhaka_to_narayanganj&boardingStation=dhaka',
        ),
      ).kind,
      RailDeepLinkKind.invalidReport,
    );

    final valid = RailReportDeepLink.parse(
      RailReportDeepLink.buildReportUri(
        trainNo: 4,
        direction: 'dhaka_to_narayanganj',
        boardingStationId: 'dhaka',
      ),
    );
    expect(valid.kind, RailDeepLinkKind.report);
    expect(valid.trainNo, 4);
    expect(valid.direction, 'dhaka_to_narayanganj');
    expect(valid.boardingStationId, 'dhaka');
  });

  test(
    'cold start and warm report deep links validate route/session and never auto-submit',
    () async {
      final schedule = const BundledScheduleSource().loadSchedule();
      final communityRepo = _ConfigurableCommunityRepository(
        overlay: const CommunityOverlay(
          tripId: 'dhk-ngj-4',
          serviceDate: '2026-10-27',
          delayMinutes: 5,
          delayStatus: DelayStatus.minorDelay,
          freshness: Freshness.live,
          confidence: ReportConfidence(score: 0.9, sampleCount: 3),
          freshnessSeconds: 20,
          isReportingAvailable: true,
        ),
      );
      final selectionRepo = _InMemorySelectionRepository(
        const RailSelection(
          direction: 'dhaka_to_narayanganj',
          boardingStationId: 'dhaka',
          destinationStationId: 'narayanganj',
        ),
      );

      final cubit = RailBoardCubit(
        boardService: RailBoardService(schedule: schedule),
        selectionRepository: selectionRepo,
        communityRepository: communityRepo,
        communityFeaturesEnabled: true,
        enableTicker: false,
        nowProvider: () => DateTime(2026, 10, 27, 7, 10),
      );

      unawaited(
        cubit.handleWidgetLaunchUri(
          RailReportDeepLink.buildReportUri(
            trainNo: 4,
            direction: 'dhaka_to_narayanganj',
            boardingStationId: 'dhaka',
          ),
        ),
      );

      await cubit.stream
          .firstWhere((state) => state.report.focusRequestId > 0)
          .timeout(const Duration(seconds: 5));

      expect(communityRepo.submitCallCount, 0);
      expect(cubit.state.report.focusedTrainNo, 4);
      expect(
        cubit.state.report.feedbackMessage,
        RailBoardTexts.reportPromptForTrain(4, 'Dhaka'),
      );

      await cubit.handleWidgetLaunchUri(RailReportDeepLink.buildBoardUri());
      expect(cubit.state.report.focusRequestId, 1);

      await cubit.handleWidgetLaunchUri(
        Uri.parse(
          'com.devinsightforge.narayanganjcommuter://report?trainNo=invalid',
        ),
      );
      expect(cubit.state.report.focusRequestId, 2);
      expect(cubit.state.report.focusedTrainNo, isNull);
      expect(
        cubit.state.report.feedbackMessage,
        RailBoardTexts.reportLinkInvalid,
      );

      await cubit.handleWidgetLaunchUri(
        RailReportDeepLink.buildReportUri(
          trainNo: 4,
          direction: 'narayanganj_to_dhaka',
          boardingStationId: 'narayanganj',
        ),
      );
      expect(cubit.state.report.focusRequestId, 3);
      expect(cubit.state.selection.direction, 'dhaka_to_narayanganj');
      expect(
        cubit.state.report.feedbackMessage,
        RailBoardTexts.reportLinkRouteChanged,
      );

      await cubit.handleWidgetLaunchUri(
        RailReportDeepLink.buildReportUri(
          trainNo: 99,
          direction: 'dhaka_to_narayanganj',
          boardingStationId: 'dhaka',
        ),
      );
      expect(cubit.state.report.focusRequestId, 4);
      expect(
        cubit.state.report.feedbackMessage,
        RailBoardTexts.reportLinkExpiredForTrain(99),
      );

      communityRepo.overlay = communityRepo.overlay!.copyWith(
        isReportingAvailable: false,
      );
      await cubit.tick();
      await cubit.handleWidgetLaunchUri(
        RailReportDeepLink.buildReportUri(
          trainNo: 4,
          direction: 'dhaka_to_narayanganj',
          boardingStationId: 'dhaka',
        ),
      );
      expect(
        cubit.state.report.feedbackMessage,
        RailBoardTexts.reportLinkUnavailableForTrain(4),
      );
      expect(communityRepo.submitCallCount, 0);

      await cubit.close();
    },
  );
}
