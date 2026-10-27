export 'rail_board_state.dart';

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/api/edge_hmac_client.dart';
import '../../../community/domain/entities/community_overlay.dart';
import '../../../community/domain/entities/predicted_stop_time.dart';
import '../../../community/domain/repositories/community_repository.dart';
import '../../application/models/rail_reporting.dart';
import '../../domain/entities/rail_selection.dart';
import '../../domain/entities/rail_snapshot.dart';
import '../../domain/repositories/selection_repository.dart';
import '../../domain/services/rail_board_service.dart';
import '../widgets/rail_board_texts.dart';
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
  int _communityRequestId = 0;

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

  Future<void> swapDirectionAndStations() async {
    final currentSelection = state.selection;
    final targetDirection = currentSelection.direction == 'dhaka_to_narayanganj'
        ? 'narayanganj_to_dhaka'
        : 'dhaka_to_narayanganj';

    final currentBoarding = currentSelection.boardingStationId;
    final currentDestination = currentSelection.destinationStationId;

    final targetBoardingOptions = _boardService.getBoardingOptions(
      targetDirection,
    );
    final targetBoardingValid = targetBoardingOptions.any(
      (opt) => opt.value == currentDestination && !opt.disabled,
    );
    final targetBoarding = targetBoardingValid
        ? currentDestination
        : targetBoardingOptions.firstWhere((opt) => !opt.disabled).value;

    final targetDestinationOptions = _boardService.getDestinationOptions(
      targetDirection,
      targetBoarding,
    );
    final targetDestValid = targetDestinationOptions.any(
      (opt) => opt.value == currentBoarding && !opt.disabled,
    );
    final targetDestination = targetDestValid
        ? currentBoarding
        : targetDestinationOptions.firstWhere((opt) => !opt.disabled).value;

    final newSelection = RailSelection(
      direction: targetDirection,
      boardingStationId: targetBoarding,
      destinationStationId: targetDestination,
    );
    await _applySelection(newSelection);
  }

  void previewService(int? trainNo) {
    if (state.view.previewTrainNo == trainNo) {
      return;
    }
    _safeEmit(
      state.copyWith(
        view: state.view.copyWith(
          previewTrainNo: trainNo,
          clearPreviewTrainNo: trainNo == null,
        ),
      ),
    );
  }

  void toggleTimelineExpansion() {
    _safeEmit(
      state.copyWith(
        view: state.view.copyWith(
          isTimelineCollapsed: !state.view.isTimelineCollapsed,
        ),
      ),
    );
  }

  Future<void> tick() async {
    if (state.status != RailBoardStatus.ready) {
      return;
    }

    final previousSession = _reportSessionIdentity(state);
    final refreshedState = _buildViewState(state.selection);
    _safeEmit(_resetSessionIfChanged(refreshedState, previousSession));
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

    final reportSession = _reportSessionIdentity(state);
    final selectedStationName = state.snapshot.selectedStationName;
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
      if (isClosed || reportSession != _reportSessionIdentity(state)) {
        return;
      }

      if (result.status == ArrivalReportResultStatus.accepted) {
        _safeEmit(
          state.copyWith(
            report: state.report.copyWith(
              status: RailReportSubmissionStatus.success,
              actionReason: RailReportActionReason.alreadySubmitted,
              hasReportedCurrentSession: true,
              submitEnabled: false,
              feedbackMessage: RailBoardTexts.arrivalConfirmedAt(
                selectedStationName,
              ),
            ),
          ),
        );
        await _refreshCommunityOverlay();
        return;
      }

      if (result.status == ArrivalReportResultStatus.stationCapacityReached) {
        _safeEmit(
          state.copyWith(
            report: state.report.copyWith(
              status: RailReportSubmissionStatus.error,
              actionReason: RailReportActionReason.stationCapacityReached,
              submitEnabled: false,
              feedbackMessage: RailBoardTexts.updatesUnavailable,
            ),
          ),
        );
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
              feedbackMessage: RailBoardTexts.cooldownWait(
                result.retryAfterSeconds,
              ),
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
                result.errorMessage ?? RailBoardTexts.reportSubmissionFailed,
          ),
        ),
      );
    } catch (_) {
      if (isClosed || reportSession != _reportSessionIdentity(state)) {
        return;
      }
      _safeEmit(
        state.copyWith(
          report: state.report.copyWith(
            status: RailReportSubmissionStatus.error,
            feedbackMessage: RailBoardTexts.reportSubmissionFailed,
          ),
        ),
      );
    }
  }

  Future<void> _applySelection(
    RailSelection selection, {
    bool forceCommunityRefresh = false,
  }) async {
    final previousSession = _reportSessionIdentity(state);

    try {
      await _selectionRepository.write(selection);
      final refreshedState = _buildViewState(selection);
      final sessionChanged =
          previousSession != _reportSessionIdentity(refreshedState);
      _safeEmit(_resetSessionIfChanged(refreshedState, previousSession));
      _refreshReportAvailability();

      if (!communityFeaturesEnabled) {
        return;
      }

      if (sessionChanged || forceCommunityRefresh) {
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

  RailBoardState _buildViewState(
    RailSelection selection, {
    int? knownDelayMinutes,
  }) {
    final effectiveDelay =
        knownDelayMinutes ??
        (selection.direction == state.selection.direction &&
                selection.boardingStationId == state.selection.boardingStationId
            ? state.community.overlay?.delayMinutes
            : null);
    final previousView = state.view;
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
          knownDelayMinutes: effectiveDelay,
        ),
        previewTrainNo: selection.direction == previousView.selection.direction
            ? previousView.previewTrainNo
            : null,
        isTimelineCollapsed: previousView.isTimelineCollapsed,
      ),
      report: state.report,
      community: state.community.copyWith(
        featuresEnabled: communityFeaturesEnabled,
      ),
    );
  }

  String _reportSessionIdentity(RailBoardState candidate) {
    final now = _nowProvider();
    final serviceDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final trainNo = candidate.snapshot.nextService?.trainNo;
    return '${candidate.selection.direction}|${candidate.selection.boardingStationId}|$trainNo|$serviceDate';
  }

  RailBoardState _resetSessionIfChanged(
    RailBoardState updatedState,
    String previousSession,
  ) {
    if (previousSession == _reportSessionIdentity(updatedState)) {
      return updatedState;
    }

    return updatedState.copyWith(
      report: const RailBoardReportState(),
      community: updatedState.community.copyWith(
        insightStatus: RailCommunityInsightStatus.idle,
        clearOverlay: true,
        predictedStopTimes: const [],
        clearMessage: true,
      ),
    );
  }

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

    final isAvailable = state.community.overlay?.isReportingAvailable ?? false;
    _safeEmit(
      state.copyWith(
        report: state.report.copyWith(
          visibility: RailReportVisibility.visible,
          submitEnabled: isAvailable,
          actionReason: isAvailable
              ? RailReportActionReason.eligible
              : (nextService.isOverdue
                    ? RailReportActionReason.afterWindow
                    : RailReportActionReason.beforeWindow),
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
    final mappedStatus = freshnessState == CommunityOverlayFreshness.fresh
        ? RailCommunityInsightStatus.ready
        : freshnessState == CommunityOverlayFreshness.staleButUsable
        ? RailCommunityInsightStatus.stale
        : RailCommunityInsightStatus.expired;

    _safeEmit(
      state.copyWith(
        community: state.community.copyWith(
          insightStatus: mappedStatus,
          overlay: agedOverlay,
          clearMessage: mappedStatus != RailCommunityInsightStatus.expired,
          message: mappedStatus == RailCommunityInsightStatus.expired
              ? RailBoardTexts.communityExpiredMessage
              : null,
        ),
      ),
    );
  }

  Future<void> _refreshCommunityOverlay() async {
    final requestId = ++_communityRequestId;
    final reportService = state.snapshot.nextService;
    if (!communityFeaturesEnabled || reportService == null) {
      return;
    }
    final requestSession = _reportSessionIdentity(state);
    final requestSelection = state.selection;
    final tripId = EdgeHmacClient.toCanonicalTripId(
      directionId: requestSelection.direction,
      trainNo: reportService.trainNo,
    );

    _safeEmit(
      state.copyWith(
        community: state.community.copyWith(
          insightStatus: RailCommunityInsightStatus.loading,
        ),
      ),
    );

    try {
      final overlay = await _communityRepository.fetchOverlay(
        tripId: tripId,
        stationId: requestSelection.boardingStationId,
      );
      if (!_isCurrentCommunityRequest(requestId, requestSession)) {
        return;
      }
      if (overlay == null) {
        final updatedSnapshot = _boardService.getSnapshot(
          selection: state.selection,
          now: _nowProvider(),
        );
        final updatedState = state.copyWith(
          view: state.view.copyWith(snapshot: updatedSnapshot),
          community: state.community.copyWith(
            insightStatus: RailCommunityInsightStatus.empty,
            clearOverlay: true,
            predictedStopTimes: const [],
            message: RailBoardTexts.communityNoDataMessage,
          ),
        );
        final sessionChanged =
            requestSession != _reportSessionIdentity(updatedState);
        _safeEmit(_resetSessionIfChanged(updatedState, requestSession));
        _refreshReportAvailability();
        if (sessionChanged) {
          await _refreshCommunityOverlay();
        }
        return;
      }

      final freshness = overlay.freshnessState;
      final status = freshness == CommunityOverlayFreshness.fresh
          ? RailCommunityInsightStatus.ready
          : freshness == CommunityOverlayFreshness.staleButUsable
          ? RailCommunityInsightStatus.stale
          : RailCommunityInsightStatus.expired;

      final updatedSnapshot = _boardService.getSnapshot(
        selection: state.selection,
        now: _nowProvider(),
        knownDelayMinutes: overlay.delayMinutes,
      );
      final effectiveNextService = updatedSnapshot.nextService ?? reportService;

      final predictedStops = _buildPredictedStopTimes(
        nextService: effectiveNextService,
        overlay: overlay,
        now: _nowProvider(),
      );

      final updatedState = state.copyWith(
        view: state.view.copyWith(snapshot: updatedSnapshot),
        community: state.community.copyWith(
          insightStatus: status,
          overlay: overlay,
          predictedStopTimes: predictedStops,
          clearMessage: status != RailCommunityInsightStatus.expired,
          message: status == RailCommunityInsightStatus.expired
              ? RailBoardTexts.communityExpiredMessage
              : null,
        ),
      );
      final sessionChanged =
          requestSession != _reportSessionIdentity(updatedState);
      if (sessionChanged) {
        _safeEmit(_resetSessionIfChanged(updatedState, requestSession));
        _refreshReportAvailability();
        await _refreshCommunityOverlay();
        return;
      }
      _safeEmit(updatedState);
      _refreshReportAvailability();
    } catch (_) {
      if (!_isCurrentCommunityRequest(requestId, requestSession)) {
        return;
      }
      final updatedSnapshot = _boardService.getSnapshot(
        selection: state.selection,
        now: _nowProvider(),
      );
      final updatedState = state.copyWith(
        view: state.view.copyWith(snapshot: updatedSnapshot),
        community: state.community.copyWith(
          insightStatus: RailCommunityInsightStatus.error,
          clearOverlay: true,
          predictedStopTimes: const [],
          message: RailBoardTexts.communityOfflineMessage,
        ),
      );
      final sessionChanged =
          requestSession != _reportSessionIdentity(updatedState);
      _safeEmit(_resetSessionIfChanged(updatedState, requestSession));
      _refreshReportAvailability();
      if (sessionChanged) {
        await _refreshCommunityOverlay();
      }
    }
  }

  bool _isCurrentCommunityRequest(int requestId, String requestSession) {
    return !isClosed &&
        requestId == _communityRequestId &&
        requestSession == _reportSessionIdentity(state);
  }

  List<PredictedStopTime> _buildPredictedStopTimes({
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
            stationId: stop.stationId,
            predictedAt: predictedAt,
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
