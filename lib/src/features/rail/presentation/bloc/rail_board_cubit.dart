export 'rail_board_state.dart';

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/edge_hmac_client.dart';
import '../../../community/domain/entities/community_overlay.dart';
import '../../../community/domain/entities/data_origin.dart';
import '../../../community/domain/entities/predicted_stop_time.dart';
import '../../../community/domain/repositories/community_repository.dart';
import '../../application/models/rail_reporting.dart';
import '../../domain/entities/rail_selection.dart';
import '../../domain/entities/rail_snapshot.dart';
import '../../domain/repositories/selection_repository.dart';
import '../../domain/services/rail_board_service.dart';
import 'rail_board_state.dart';

class RailBoardCubit extends Cubit<RailBoardState> {
  RailBoardCubit({
    required RailBoardService boardService,
    required SelectionRepository selectionRepository,
    required CommunityRepository communityRepository,
    this.communityFeaturesEnabled = true,
    bool enableTicker = true,
    DateTime Function()? nowProvider,
  }) : _boardService = boardService,
       _selectionRepository = selectionRepository,
       _communityRepository = communityRepository,
       _nowProvider = nowProvider ?? DateTime.now,
       super(const RailBoardState()) {
    unawaited(start());
    if (enableTicker) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        unawaited(tick());
      });
    }
  }

  final RailBoardService _boardService;
  final SelectionRepository _selectionRepository;
  final CommunityRepository _communityRepository;
  final bool communityFeaturesEnabled;
  final DateTime Function() _nowProvider;
  Timer? _timer;

  static const _fallbackErrorMessage =
      'Unable to load schedule data. Please try again.';

  void _safeEmit(RailBoardState nextState) {
    if (isClosed) {
      return;
    }
    emit(nextState);
  }

  Future<void> start({bool showLoading = true}) async {
    if (showLoading) {
      _safeEmit(
        state.copyWith(status: RailBoardStatus.loading, clearError: true),
      );
    }

    try {
      final storedSelection = await _selectionRepository.read();
      final selection = _boardService.createSelection(
        direction: storedSelection?.direction,
        boardingStationId: storedSelection?.boardingStationId,
        destinationStationId: storedSelection?.destinationStationId,
      );

      await _applySelection(selection, forceCommunityRefresh: true);
    } catch (_) {
      _safeEmit(
        state.copyWith(
          status: RailBoardStatus.failure,
          errorMessage: _fallbackErrorMessage,
        ),
      );
    }
  }

  Future<void> retry() async {
    await start(showLoading: true);
  }

  Future<void> changeDirection(String direction) async {
    final selection = _boardService.changeDirection(direction);
    await _applySelection(selection);
  }

  Future<void> changeBoarding(String stationId) async {
    final selection = _boardService.changeBoardingStation(
      state.selection,
      stationId,
    );
    await _applySelection(selection);
  }

  Future<void> changeDestination(String stationId) async {
    final selection = _boardService.changeDestinationStation(
      state.selection,
      stationId,
    );
    await _applySelection(selection);
  }

  Future<void> tick() async {
    if (state.status != RailBoardStatus.ready) {
      return;
    }

    _safeEmit(_buildViewState(state.selection));
    _ageCommunityOverlay(elapsedSeconds: 30);
    _refreshReportAvailability();

    if (communityFeaturesEnabled && state.snapshot.nextService != null) {
      await _refreshCommunityOverlay();
    }
  }

  Future<void> submitArrivalReport() async {
    if (!communityFeaturesEnabled ||
        state.status != RailBoardStatus.ready ||
        state.snapshot.nextService == null ||
        state.report.isSubmissionLocked) {
      return;
    }

    _safeEmit(
      state.copyWith(
        report: state.report.copyWith(
          status: RailReportSubmissionStatus.submitting,
          clearFeedback: true,
        ),
      ),
    );

    final nextService = state.snapshot.nextService!;
    final tripId = EdgeHmacClient.toCanonicalTripId(
      directionId: state.selection.direction,
      trainNo: nextService.trainNo,
    );

    try {
      final result = await _communityRepository.submitArrivalReport(
        tripId: tripId,
        stationId: state.selection.boardingStationId,
      );

      if (result.status == ArrivalReportResultStatus.accepted) {
        _safeEmit(
          state.copyWith(
            report: state.report.copyWith(
              status: RailReportSubmissionStatus.success,
              actionReason: RailReportActionReason.alreadySubmitted,
              hasReportedCurrentSession: true,
              submitEnabled: false,
              feedbackMessage:
                  'Arrival confirmed at ${state.snapshot.selectedStationName}. Thank you!',
            ),
          ),
        );
        await _refreshCommunityOverlay();
        return;
      }

      if (result.status == ArrivalReportResultStatus.cooldown) {
        _safeEmit(
          state.copyWith(
            report: state.report.copyWith(
              status: RailReportSubmissionStatus.error,
              actionReason: RailReportActionReason.alreadySubmitted,
              hasReportedCurrentSession: true,
              submitEnabled: false,
              feedbackMessage:
                  'You reported recently. Please wait ${result.retryAfterSeconds}s before submitting again.',
            ),
          ),
        );
        return;
      }

      _safeEmit(
        state.copyWith(
          report: state.report.copyWith(
            status: RailReportSubmissionStatus.error,
            feedbackMessage:
                result.errorMessage ??
                'Failed to submit report. Please try again.',
          ),
        ),
      );
    } catch (_) {
      _safeEmit(
        state.copyWith(
          report: state.report.copyWith(
            status: RailReportSubmissionStatus.error,
            feedbackMessage: 'Failed to submit report. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _applySelection(
    RailSelection selection, {
    bool forceCommunityRefresh = false,
  }) async {
    final prevDirection = state.selection.direction;
    final prevTrainNo = state.snapshot.nextService?.trainNo;

    try {
      await _selectionRepository.write(selection);
      _safeEmit(_buildViewState(selection));
      _refreshReportAvailability();

      if (!communityFeaturesEnabled) {
        return;
      }

      final nextDirection = state.selection.direction;
      final nextTrainNo = state.snapshot.nextService?.trainNo;
      final trainContextChanged =
          prevDirection != nextDirection || prevTrainNo != nextTrainNo;

      if (trainContextChanged || forceCommunityRefresh) {
        await _refreshCommunityOverlay();
      }
    } catch (_) {
      _safeEmit(
        state.copyWith(
          status: RailBoardStatus.failure,
          errorMessage: _fallbackErrorMessage,
        ),
      );
    }
  }

  RailBoardState _buildViewState(RailSelection selection) {
    return RailBoardState(
      status: RailBoardStatus.ready,
      errorMessage: null,
      view: RailBoardViewState(
        selection: selection,
        directionOptions: _boardService.getDirectionOptions(),
        boardingStations: _boardService.getBoardingOptions(selection.direction),
        destinationStations: _boardService.getDestinationOptions(
          selection.direction,
          selection.boardingStationId,
        ),
        snapshot: _boardService.getSnapshot(
          selection: selection,
          now: _nowProvider(),
        ),
      ),
      report: state.report,
      community: state.community.copyWith(
        featuresEnabled: communityFeaturesEnabled,
      ),
    );
  }

  static const _reportingWindowMinutes = 5;

  void _refreshReportAvailability() {
    final nextService = state.snapshot.nextService;
    if (!communityFeaturesEnabled || nextService == null) {
      _safeEmit(
        state.copyWith(
          report: state.report.copyWith(
            visibility: communityFeaturesEnabled
                ? RailReportVisibility.visible
                : RailReportVisibility.hidden,
            submitEnabled: false,
            actionReason: RailReportActionReason.noSession,
          ),
        ),
      );
      return;
    }

    if (state.report.hasReportedCurrentSession) {
      _safeEmit(
        state.copyWith(
          report: state.report.copyWith(
            visibility: RailReportVisibility.visible,
            submitEnabled: false,
            actionReason: RailReportActionReason.alreadySubmitted,
          ),
        ),
      );
      return;
    }

    final isInRange = nextService.waitMinutes <= _reportingWindowMinutes;
    _safeEmit(
      state.copyWith(
        report: state.report.copyWith(
          visibility: RailReportVisibility.visible,
          submitEnabled: isInRange,
          actionReason: isInRange
              ? RailReportActionReason.eligible
              : RailReportActionReason.beforeWindow,
        ),
      ),
    );
  }

  void _ageCommunityOverlay({required int elapsedSeconds}) {
    if (elapsedSeconds <= 0) {
      return;
    }
    final overlay = state.community.overlay;
    if (overlay == null) {
      return;
    }
    final agedOverlay = overlay.copyWith(
      freshnessSeconds: overlay.freshnessSeconds + elapsedSeconds,
    );
    final freshnessState = agedOverlay.freshnessState;
    if (freshnessState == CommunityOverlayFreshness.expired) {
      _safeEmit(
        state.copyWith(
          community: state.community.copyWith(
            insightStatus: RailCommunityInsightStatus.expired,
            clearOverlay: true,
            predictedStopTimes: const [],
            message:
                'Live rider updates are a bit old right now. Showing timetable-only guidance until new updates arrive.',
            clearMessage: false,
          ),
        ),
      );
      return;
    }

    final mappedStatus = freshnessState == CommunityOverlayFreshness.fresh
        ? RailCommunityInsightStatus.ready
        : RailCommunityInsightStatus.stale;

    _safeEmit(
      state.copyWith(
        community: state.community.copyWith(
          insightStatus: mappedStatus,
          overlay: agedOverlay,
        ),
      ),
    );
  }

  Future<void> _refreshCommunityOverlay() async {
    final nextService = state.snapshot.nextService;
    if (!communityFeaturesEnabled || nextService == null) {
      return;
    }
    final tripId = EdgeHmacClient.toCanonicalTripId(
      directionId: state.selection.direction,
      trainNo: nextService.trainNo,
    );

    _safeEmit(
      state.copyWith(
        community: state.community.copyWith(
          insightStatus: RailCommunityInsightStatus.loading,
        ),
      ),
    );

    try {
      final overlay = await _communityRepository.fetchOverlay(tripId: tripId);
      if (overlay == null) {
        _safeEmit(
          state.copyWith(
            community: state.community.copyWith(
              insightStatus: RailCommunityInsightStatus.empty,
              clearOverlay: true,
              predictedStopTimes: const [],
              message: 'No rider updates are available for this train yet.',
            ),
          ),
        );
        return;
      }

      final freshness = overlay.freshnessState;
      if (freshness == CommunityOverlayFreshness.expired) {
        _safeEmit(
          state.copyWith(
            community: state.community.copyWith(
              insightStatus: RailCommunityInsightStatus.expired,
              clearOverlay: true,
              predictedStopTimes: const [],
              message:
                  'Live rider updates are a bit old right now. Showing timetable-only guidance until new updates arrive.',
            ),
          ),
        );
        return;
      }

      final status = freshness == CommunityOverlayFreshness.fresh
          ? RailCommunityInsightStatus.ready
          : RailCommunityInsightStatus.stale;

      final predictedStops = _buildPredictedStopTimes(
        tripId: tripId,
        nextService: nextService,
        overlay: overlay,
        now: _nowProvider(),
      );

      _safeEmit(
        state.copyWith(
          community: state.community.copyWith(
            insightStatus: status,
            overlay: overlay,
            predictedStopTimes: predictedStops,
            clearMessage: true,
          ),
        ),
      );
    } catch (_) {
      _safeEmit(
        state.copyWith(
          community: state.community.copyWith(
            insightStatus: RailCommunityInsightStatus.error,
            clearOverlay: true,
            predictedStopTimes: const [],
            message:
                'Live rider updates are temporarily unavailable. The timetable is still available.',
          ),
        ),
      );
    }
  }

  List<PredictedStopTime> _buildPredictedStopTimes({
    required String tripId,
    required RailServiceSnapshot nextService,
    required CommunityOverlay overlay,
    required DateTime now,
  }) {
    if (nextService.stops.isEmpty) {
      return const <PredictedStopTime>[];
    }
    return nextService.stops
        .map((stop) {
          final parts = stop.time.split(':');
          final hour = int.tryParse(parts[0]) ?? 0;
          final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
          final scheduledAt = DateTime(
            now.year,
            now.month,
            now.day,
            hour,
            minute,
          );
          final predictedAt = scheduledAt.add(
            Duration(minutes: overlay.delayMinutes),
          );
          return PredictedStopTime(
            sessionId: tripId,
            stationId: stop.stationId,
            predictedAt: predictedAt,
            referenceStationId: nextService.stops.first.stationId,
            origin: DataOrigin.inferred,
            confidence: overlay.confidence,
            isPassed: predictedAt.isBefore(now),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await super.close();
  }
}
