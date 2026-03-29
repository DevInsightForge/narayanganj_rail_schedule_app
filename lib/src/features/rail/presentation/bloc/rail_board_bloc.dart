import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../community/domain/repositories/arrival_report_repository.dart';
import '../../../community/domain/repositories/arrival_report_ledger_repository.dart';
import '../../../community/domain/repositories/community_overlay_repository.dart';
import '../../../community/domain/repositories/device_identity_repository.dart';
import '../../../community/domain/repositories/rate_limit_policy_repository.dart';
import '../../../community/domain/repositories/session_repository.dart';
import '../../../community/domain/services/session_lifecycle_service.dart';
import '../../application/models/rail_community_insight_result.dart';
import '../../application/models/rail_reporting.dart';
import '../../application/services/rail_community_insight_coordinator.dart';
import '../../application/services/rail_report_coordinator.dart';
import '../../application/services/rail_session_resolver.dart';
import '../../data/repositories/schedule_data_repository.dart';
import '../../domain/entities/rail_selection.dart';
import '../../domain/entities/rail_snapshot.dart';
import '../../domain/repositories/selection_repository.dart';
import '../../domain/services/rail_board_service.dart';
import '../../../community/domain/entities/predicted_stop_time.dart';
import '../../../community/domain/entities/session_status_snapshot.dart';

part 'rail_board_event.dart';
part 'rail_board_state.dart';

class RailBoardBloc extends Bloc<RailBoardEvent, RailBoardState> {
  RailBoardBloc({
    required RailBoardService boardService,
    required ScheduleDataRepository scheduleDataRepository,
    required SelectionRepository selectionRepository,
    required SessionRepository sessionRepository,
    required ArrivalReportRepository arrivalReportRepository,
    required ArrivalReportLedgerRepository arrivalReportLedgerRepository,
    required CommunityOverlayRepository communityOverlayRepository,
    required DeviceIdentityRepository deviceIdentityRepository,
    required RateLimitPolicyRepository rateLimitPolicyRepository,
    this.communityFeaturesEnabled = true,
    this.enableTicker = true,
    DateTime Function()? nowProvider,
  }) : _boardService = boardService,
       _scheduleDataRepository = scheduleDataRepository,
       _selectionRepository = selectionRepository,
       _nowProvider = nowProvider ?? DateTime.now,
       _reportCoordinator = RailReportCoordinator(
         sessionResolver: RailSessionResolver(
           sessionRepository: sessionRepository,
           sessionLifecycleService: const SessionLifecycleService(),
           routeId: _routeId,
         ),
         arrivalReportRepository: arrivalReportRepository,
         arrivalReportLedgerRepository: arrivalReportLedgerRepository,
         deviceIdentityRepository: deviceIdentityRepository,
         rateLimitPolicyRepository: rateLimitPolicyRepository,
       ),
       _communityCoordinator = RailCommunityInsightCoordinator(
         sessionResolver: RailSessionResolver(
           sessionRepository: sessionRepository,
           sessionLifecycleService: const SessionLifecycleService(),
           routeId: _routeId,
         ),
         communityOverlayRepository: communityOverlayRepository,
       ),
       _initialScheduleVersion = boardService.schedule.version,
       _activeSource = ScheduleDataSource.bundled,
       _lastUpdatedAt = null,
       super(const RailBoardState()) {
    on<RailBoardStarted>(_onStarted);
    on<RailBoardRetryRequested>(_onRetryRequested);
    on<RailBoardDirectionChanged>(_onDirectionChanged);
    on<RailBoardBoardingChanged>(_onBoardingChanged);
    on<RailBoardDestinationChanged>(_onDestinationChanged);
    on<RailBoardTicked>(_onTicked);
    on<RailBoardArrivalReportRequested>(_onArrivalReportRequested);

    add(const RailBoardStarted());
    if (enableTicker) {
      _timer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => add(const RailBoardTicked()),
      );
    }
  }

  static const _fallbackErrorMessage =
      'Unable to load schedule data. Please try again.';
  static const _routeId = 'narayanganj_line';

  RailBoardService _boardService;
  final ScheduleDataRepository _scheduleDataRepository;
  final SelectionRepository _selectionRepository;
  final DateTime Function() _nowProvider;
  final bool communityFeaturesEnabled;
  final bool enableTicker;
  final RailReportCoordinator _reportCoordinator;
  final RailCommunityInsightCoordinator _communityCoordinator;
  final String _initialScheduleVersion;
  int _reportAvailabilityRevision = 0;
  Timer? _timer;

  ScheduleDataSource _activeSource;
  DateTime? _lastUpdatedAt;

  RailBoardService get boardService => _boardService;

  Future<void> _onStarted(
    RailBoardStarted event,
    Emitter<RailBoardState> emit,
  ) async {
    await _loadBoard(emit: emit, showLoading: true);
  }

  Future<void> _onRetryRequested(
    RailBoardRetryRequested event,
    Emitter<RailBoardState> emit,
  ) async {
    await _loadBoard(emit: emit, showLoading: true, forceCommunityRefresh: true);
  }

  Future<void> _loadBoard({
    required Emitter<RailBoardState> emit,
    required bool showLoading,
    bool forceCommunityRefresh = false,
  }) async {
    if (showLoading) {
      emit(state.copyWith(status: RailBoardStatus.loading, clearError: true));
    }

    try {
      final storedSelection = await _selectionRepository.read();
      final storedSchedule = await _scheduleDataRepository.readStoredSchedule();

      if (storedSchedule != null) {
        _boardService = RailBoardService(schedule: storedSchedule.schedule);
        _activeSource = storedSchedule.source;
        _lastUpdatedAt = storedSchedule.loadedAt;
      } else {
        _activeSource = ScheduleDataSource.bundled;
        _lastUpdatedAt = null;
      }

      var selection = _boardService.createSelection(
        direction: storedSelection?.direction,
        boardingStationId: storedSelection?.boardingStationId,
        destinationStationId: storedSelection?.destinationStationId,
      );

      await _persistAndEmit(
        selection: selection,
        emit: emit,
        forceCommunityRefresh: forceCommunityRefresh,
      );

      final remoteSchedule = await _scheduleDataRepository
          .fetchRemoteSchedule();
      if (remoteSchedule == null) {
        return;
      }

      _boardService = RailBoardService(schedule: remoteSchedule.schedule);
      _activeSource = remoteSchedule.source;
      _lastUpdatedAt = remoteSchedule.loadedAt;
      selection = _boardService.createSelection(
        direction: selection.direction,
        boardingStationId: selection.boardingStationId,
        destinationStationId: selection.destinationStationId,
      );
      await _persistAndEmit(
        selection: selection,
        emit: emit,
        forceCommunityRefresh: forceCommunityRefresh,
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: RailBoardStatus.failure,
          errorMessage: _fallbackErrorMessage,
        ),
      );
    }
  }

  Future<void> _persistAndEmit({
    required RailSelection selection,
    required Emitter<RailBoardState> emit,
    bool forceCommunityRefresh = false,
  }) async {
    final previousDirection = state.selection.direction;
    final previousTrainNo = state.snapshot.nextService?.trainNo;
    await _selectionRepository.write(selection);
    emit(_buildState(selection));
    await _refreshReportAvailability(selection: selection, emit: emit);
    if (!communityFeaturesEnabled) {
      return;
    }
    final nextDirection = state.selection.direction;
    final nextTrainNo = state.snapshot.nextService?.trainNo;
    final trainContextChanged =
        previousDirection != nextDirection || previousTrainNo != nextTrainNo;
    if (trainContextChanged || forceCommunityRefresh) {
      await _refreshCommunityInsights(
        selection: selection,
        emit: emit,
        forceRefresh: forceCommunityRefresh,
      );
    }
  }

  Future<void> _onDirectionChanged(
    RailBoardDirectionChanged event,
    Emitter<RailBoardState> emit,
  ) async {
    final selection = _boardService.changeDirection(event.direction);
    await _persistAndEmit(selection: selection, emit: emit);
  }

  Future<void> _onBoardingChanged(
    RailBoardBoardingChanged event,
    Emitter<RailBoardState> emit,
  ) async {
    final selection = _boardService.changeBoardingStation(
      state.selection,
      event.stationId,
    );
    await _persistAndEmit(selection: selection, emit: emit);
  }

  Future<void> _onDestinationChanged(
    RailBoardDestinationChanged event,
    Emitter<RailBoardState> emit,
  ) async {
    final selection = _boardService.changeDestinationStation(
      state.selection,
      event.stationId,
    );
    await _persistAndEmit(selection: selection, emit: emit);
  }

  Future<void> _onTicked(
    RailBoardTicked event,
    Emitter<RailBoardState> emit,
  ) async {
    if (state.status != RailBoardStatus.ready) {
      return;
    }
    emit(_buildState(state.selection));
    final now = _nowProvider();
    await _refreshReportAvailability(
      selection: state.selection,
      emit: emit,
      now: now,
    );
    if (!communityFeaturesEnabled) {
      return;
    }
  }

  Future<void> _onArrivalReportRequested(
    RailBoardArrivalReportRequested event,
    Emitter<RailBoardState> emit,
  ) async {
    if (!communityFeaturesEnabled) {
      return;
    }
    if (state.status != RailBoardStatus.ready ||
        state.snapshot.nextService == null) {
      return;
    }

    await _refreshReportAvailability(selection: state.selection, emit: emit);
    if (!state.report.isActionEnabled) {
      emit(
        state.copyWith(
          report: state.report.copyWith(
            status: RailReportSubmissionStatus.error,
            feedbackMessage:
                state.report.actionHint ??
                'Reporting is not available for this train yet.',
            clearRetryAfter: true,
          ),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        report: state.report.copyWith(
          status: RailReportSubmissionStatus.submitting,
          clearFeedback: true,
          clearRetryAfter: true,
        ),
      ),
    );

    final submission = await _reportCoordinator.submit(
      selection: state.selection,
      nextService: state.snapshot.nextService,
      selectedStationName: state.snapshot.selectedStationName,
      now: _nowProvider(),
    );

    emit(
      state.copyWith(
        report: _deriveReportActionState(
          state.report.copyWith(
            status: switch (submission.outcome) {
              RailReportSubmissionOutcome.success =>
                RailReportSubmissionStatus.success,
              RailReportSubmissionOutcome.rateLimited =>
                RailReportSubmissionStatus.rateLimited,
              RailReportSubmissionOutcome.error =>
                RailReportSubmissionStatus.error,
            },
            feedbackMessage: submission.feedbackMessage,
            retryAfterSeconds: submission.retryAfterSeconds,
          ),
          reason: submission.reason,
        ),
      ),
    );

    if (submission.outcome == RailReportSubmissionOutcome.success) {
      await _refreshCommunityInsights(
        selection: state.selection,
        emit: emit,
        forceRefresh: true,
      );
    }
  }

  Future<void> _refreshCommunityInsights({
    required RailSelection selection,
    required Emitter<RailBoardState> emit,
    bool forceRefresh = false,
  }) async {
    emit(
      state.copyWith(
        community: state.community.copyWith(
          insightStatus: RailCommunityInsightStatus.loading,
        ),
      ),
    );

    final result = await _communityCoordinator.load(
      direction: selection.direction,
      nextService: state.snapshot.nextService,
      now: _nowProvider(),
      forceRefresh: forceRefresh,
    );
    final mappedStatus = _mapInsightKind(result.kind);
    emit(
      state.copyWith(
        community: state.community.copyWith(
          insightStatus: mappedStatus,
          lastResolvedInsightStatus: mappedStatus,
          sessionStatusSnapshot: result.sessionStatusSnapshot,
          clearSessionStatus: result.sessionStatusSnapshot == null,
          predictedStopTimes: result.predictedStopTimes,
          message: result.message,
          clearMessage: result.message == null,
        ),
      ),
    );
  }

  Future<void> _refreshReportAvailability({
    required RailSelection selection,
    required Emitter<RailBoardState> emit,
    DateTime? now,
  }) async {
    final revision = ++_reportAvailabilityRevision;
    if (state.status != RailBoardStatus.ready || !communityFeaturesEnabled) {
      final nextReport = _deriveReportActionState(
        state.report.copyWith(clearActionHint: true),
        reason: RailReportActionReason.noSession,
      );
      if (revision == _reportAvailabilityRevision &&
          nextReport != state.report) {
        emit(state.copyWith(report: nextReport));
      }
      return;
    }

    final availability = await _reportCoordinator.resolveAvailability(
      selection: selection,
      nextService: state.snapshot.nextService,
      now: now ?? _nowProvider(),
    );
    final nextReport = _deriveReportActionState(
      state.report,
      reason: availability.reason,
      now: now ?? _nowProvider(),
      boardingAt: availability.boardingAt,
    );
    if (revision == _reportAvailabilityRevision && nextReport != state.report) {
      emit(state.copyWith(report: nextReport));
    }
  }

  RailBoardReportState _deriveReportActionState(
    RailBoardReportState base, {
    required RailReportActionReason reason,
    DateTime? now,
    DateTime? boardingAt,
  }) {
    final hint = _reportActionHint(
      reason: reason,
      now: now,
      boardingAt: boardingAt,
    );
    return base.copyWith(
      actionReason: reason,
      isActionEnabled:
          reason == RailReportActionReason.eligible ||
          reason == RailReportActionReason.verificationLimitedEligible,
      hasReportedCurrentSession:
          reason == RailReportActionReason.alreadySubmitted,
      actionHint: hint,
    );
  }

  String _reportActionHint({
    required RailReportActionReason reason,
    DateTime? now,
    DateTime? boardingAt,
  }) {
    switch (reason) {
      case RailReportActionReason.noSession:
        return 'No reportable train session is available right now.';
      case RailReportActionReason.beforeWindow:
        if (now != null && boardingAt != null) {
          final remainingMinutes = boardingAt
              .subtract(const Duration(minutes: 5))
              .difference(now)
              .inMinutes
              .clamp(0, 9999);
          return 'Reporting opens in ${_formatReportWindowWait(remainingMinutes)}.';
        }
        return 'Reporting is not open yet for this train.';
      case RailReportActionReason.afterWindow:
        return 'Reporting window has closed for this train.';
      case RailReportActionReason.alreadySubmitted:
        return 'You have already reported arrival for this train at this station.';
      case RailReportActionReason.temporarilyUnavailable:
        return 'Reporting is temporarily unavailable. Please try again shortly.';
      case RailReportActionReason.eligible:
        return 'Reporting is open for your selected boarding station.';
      case RailReportActionReason.verificationLimitedEligible:
        return 'Live verification is unavailable. You can still submit one arrival report for this station.';
    }
  }

  String _formatReportWindowWait(int remainingMinutes) {
    if (remainingMinutes < 60) {
      return '$remainingMinutes min';
    }
    final hours = remainingMinutes ~/ 60;
    final minutes = remainingMinutes % 60;
    if (minutes == 0) {
      return '$hours hr';
    }
    return '$hours hr $minutes min';
  }

  RailCommunityInsightStatus _mapInsightKind(RailCommunityInsightKind kind) {
    return switch (kind) {
      RailCommunityInsightKind.idle => RailCommunityInsightStatus.idle,
      RailCommunityInsightKind.loading => RailCommunityInsightStatus.loading,
      RailCommunityInsightKind.ready => RailCommunityInsightStatus.ready,
      RailCommunityInsightKind.stale => RailCommunityInsightStatus.stale,
      RailCommunityInsightKind.empty => RailCommunityInsightStatus.empty,
      RailCommunityInsightKind.error => RailCommunityInsightStatus.error,
    };
  }

  RailBoardState _buildState(RailSelection selection) {
    final sourceLabel = switch (_activeSource) {
      ScheduleDataSource.bundled => 'Bundled',
      ScheduleDataSource.cached => 'Cached',
      ScheduleDataSource.remote => 'Remote',
    };

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
        snapshot: _boardService
            .getSnapshot(selection: selection, now: _nowProvider())
            .copyWith(
              dataSourceLabel: sourceLabel,
              lastUpdatedAt: _lastUpdatedAt,
              scheduleVersion: _boardService.schedule.version.isEmpty
                  ? _initialScheduleVersion
                  : _boardService.schedule.version,
            ),
      ),
      report: state.report,
      community: state.community.copyWith(
        featuresEnabled: communityFeaturesEnabled,
      ),
    );
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await super.close();
  }
}
