import 'dart:async';

import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/community_overlay.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/delay_status.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/freshness.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/report_confidence.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/community_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_schedule.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/entities/rail_selection.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/repositories/selection_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/domain/services/rail_board_service.dart';
import 'package:narayanganj_rail_schedule/src/features/rail/presentation/bloc/rail_board_cubit.dart';

RailBoardCubit buildRailBoardReportingCubit({
  required RailSchedule bundledSchedule,
  required CommunityRepository communityRepository,
  bool communityFeaturesEnabled = true,
  required DateTime Function() nowProvider,
}) {
  return RailBoardCubit(
    boardService: RailBoardService(schedule: bundledSchedule),
    selectionRepository: _InMemorySelectionRepository(
      const RailSelection(
        direction: 'dhaka_to_narayanganj',
        boardingStationId: 'dhaka',
        destinationStationId: 'narayanganj',
      ),
    ),
    communityRepository: communityRepository,
    communityFeaturesEnabled: communityFeaturesEnabled,
    nowProvider: nowProvider,
    enableTicker: false,
  );
}

CommunityOverlay railBoardReportingOverlayResult({
  required String sessionId,
  required DateTime fetchedAt,
  required int freshnessSeconds,
}) {
  return CommunityOverlay(
    tripId: sessionId,
    serviceDate: '2026-03-28',
    delayMinutes: 4,
    delayStatus: DelayStatus.minorDelay,
    freshness: Freshness.live,
    confidence: const ReportConfidence(score: 0.85, sampleCount: 3),
    lastReportedStation: 'dhaka',
    lastReportedAt:
        fetchedAt.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch ~/
        1000,
    freshnessSeconds: freshnessSeconds,
  );
}

Future<RailBoardState> waitForRailBoardState(
  RailBoardCubit cubit,
  bool Function(RailBoardState) predicate,
) async {
  final current = cubit.state;
  if (predicate(current)) {
    return current;
  }
  return cubit.stream.firstWhere(predicate);
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

class FlakyCommunityRepository implements CommunityRepository {
  bool failSubmission = true;
  ArrivalReportResult reportResult = const ArrivalReportResult.accepted();
  final List<Map<String, dynamic>> submitted = [];

  @override
  Future<CommunityOverlay?> fetchOverlay({
    required String tripId,
    String? serviceDate,
  }) async {
    return null;
  }

  @override
  Future<ArrivalReportResult> submitArrivalReport({
    required String tripId,
    required String stationId,
    int? delayMinutes,
    String? serviceDate,
  }) async {
    if (failSubmission) {
      throw StateError('offline');
    }
    submitted.add({
      'tripId': tripId,
      'stationId': stationId,
      'delayMinutes': delayMinutes,
      'serviceDate': serviceDate,
    });
    return reportResult;
  }
}
