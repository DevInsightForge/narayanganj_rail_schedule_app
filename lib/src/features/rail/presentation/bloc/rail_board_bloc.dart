import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../community/domain/entities/firebase_auth_readiness.dart';
import '../../../community/domain/repositories/arrival_report_repository.dart';
import '../../../community/domain/repositories/arrival_report_ledger_repository.dart';
import '../../../community/domain/repositories/community_overlay_repository.dart';
import '../../../community/domain/repositories/device_identity_repository.dart';
import '../../../community/domain/repositories/rate_limit_policy_repository.dart';
import '../../../community/domain/repositories/session_repository.dart';
import '../../../../core/errors/error_report_context.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/logging/debug_logger.dart';
import '../../../../core/tracing/attempt_id_factory.dart';
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
    ErrorReporter? errorReporter,
    AttemptIdFactory? attemptIdFactory,
    DebugLogger? logger,
    this.communityFeaturesEnabled = true,
    this.enableTicker = true,
    DateTime Function()? nowProvider,
  }) : _boardService = boardService,
       _scheduleDataRepository = scheduleDataRepository,
       _selectionRepository = selectionRepository,
       _deviceIdentityRepository = deviceIdentityRepository,
       _nowProvider = nowProvider ?? DateTime.now,
       _errorReporter = errorReporter ?? const NoopErrorReporter(),
       _attemptIdFactory = attemptIdFactory ?? AttemptIdFactory(),
       _logger = logger ?? const DebugLogger('RailBoardBloc'),
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
         errorReporter: errorReporter,
       ),
       _communityCoordinator = RailCommunityInsightCoordinator(
         sessionResolver: RailSessionResolver(
           sessionRepository: sessionRepository,
           sessionLifecycleService: const SessionLifecycleService(),
           routeId: _routeId,
         ),
         communityOverlayRepository: communityOverlayRepository,
         errorReporter: errorReporter,
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
  final DeviceIdentityRepository _deviceIdentityRepository;
  final DateTime Function() _nowProvider;
  final ErrorReporter _errorReporter;
  final AttemptIdFactory _attemptIdFactory;
  final DebugLogger _logger;
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
    await _loadBoard(
      emit: emit,
      showLoading: true,
      forceCommunityRefresh: true,
    );
  }

  Future<void> _loadBoard({
    required Emitter<RailBoardState> emit,
    required bool showLoading,
    bool forceCommunityRefresh = false,
  }) async {
    final attemptId = _attemptIdFactory.next();
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
    } catch (error, stackTrace) {
      await _reportBlocGuard(
        error,
        stackTrace,
        event: 'load_board',
        attemptId: attemptId,
      );
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
    final attemptId = _attemptIdFactory.next();
    final previousDirection = state.selection.direction;
    final previousTrainNo = state.snapshot.nextService?.trainNo;
    try {
      await _selectionRepository.write(selection);
      emit(_buildState(selection));
      await _refreshReportAvailability(
        selection: selection,
        emit: emit,
        attemptId: attemptId,
      );
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
          attemptId: attemptId,
        );
      }
    } catch (error, stackTrace) {
      await _reportBlocGuard(
        error,
        stackTrace,
        event: 'persist_and_emit',
        attemptId: attemptId,
      );
      emit(
        state.copyWith(
          status: RailBoardStatus.failure,
          errorMessage: _fallbackErrorMessage,
        ),
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
      attemptId: _attemptIdFactory.next(),
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

    final attemptId = _attemptIdFactory.next();
    await _refreshReportAvailability(
      selection: state.selection,
      emit: emit,
      attemptId: attemptId,
    );
    if (!state.report.submitEnabled) {
      if (state.report.visibility == RailReportVisibility.hidden) {
        await _reportBlocGuard(
          StateError('report_submit_hidden'),
          StackTrace.current,
          event: 'submit_guard_hidden',
          attemptId: attemptId,
        );
        return;
      }
      await _reportBlocGuard(
        StateError('report_submit_blocked'),
        StackTrace.current,
        event: 'submit_guard_blocked',
        attemptId: attemptId,
      );
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
      attemptId: attemptId,
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
          authReadiness: state.report.authReadiness,
          reason: submission.reason,
        ),
      ),
    );

    if (submission.failureReason ==
        RailReportSubmissionFailureReason.authNotReady) {
      await _refreshReportAvailability(
        selection: state.selection,
        emit: emit,
        attemptId: attemptId,
      );
    }

    if (submission.outcome == RailReportSubmissionOutcome.success) {
      await _refreshCommunityInsights(
        selection: state.selection,
        emit: emit,
        forceRefresh: true,
        attemptId: attemptId,
      );
    }
  }

  Future<void> _refreshCommunityInsights({
    required RailSelection selection,
    required Emitter<RailBoardState> emit,
    bool forceRefresh = false,
    String? attemptId,
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
      attemptId: attemptId ?? _attemptIdFactory.next(),
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
    String? attemptId,
  }) async {
    final revision = ++_reportAvailabilityRevision;
    final resolvedNow = now ?? _nowProvider();
    if (state.status != RailBoardStatus.ready || !communityFeaturesEnabled) {
      final nextReport = _deriveReportActionState(
        state.report.copyWith(clearActionHint: true),
        authReadiness: const FirebaseAuthReadiness.unknown(),
        reason: RailReportActionReason.noSession,
      );
      if (revision == _reportAvailabilityRevision &&
          nextReport != state.report) {
        emit(state.copyWith(report: nextReport));
      }
      return;
    }

    final resolvingReport = state.report.copyWith(
      authReadiness: const FirebaseAuthReadiness.resolving(),
      guardOutcome: RailReportGuardOutcome.hiddenAuthPending,
      visibility: RailReportVisibility.hidden,
      submitEnabled: false,
      actionReason: RailReportActionReason.noSession,
      hasReportedCurrentSession: false,
      clearActionHint: true,
    );
    if (revision == _reportAvailabilityRevision &&
        resolvingReport != state.report) {
      emit(state.copyWith(report: resolvingReport));
    }

    final currentAttemptId = attemptId ?? _attemptIdFactory.next();
    final authReadiness = await _deviceIdentityRepository.readAuthReadiness(
      attemptId: currentAttemptId,
    );
    if (revision != _reportAvailabilityRevision) {
      return;
    }
    if (!authReadiness.isReady) {
      final nextReport = state.report.copyWith(
        authReadiness: authReadiness,
        guardOutcome: RailReportGuardOutcome.hiddenAuthPending,
        visibility: RailReportVisibility.hidden,
        submitEnabled: false,
        actionReason: RailReportActionReason.noSession,
        hasReportedCurrentSession: false,
        clearActionHint: true,
      );
      if (nextReport != state.report) {
        emit(state.copyWith(report: nextReport));
      }
      return;
    }

    final availability = await _reportCoordinator.resolveAvailability(
      selection: selection,
      nextService: state.snapshot.nextService,
      now: resolvedNow,
      attemptId: currentAttemptId,
    );
    if (revision != _reportAvailabilityRevision) {
      return;
    }
    final nextReport = _deriveReportActionState(
      state.report,
      authReadiness: authReadiness,
      reason: availability.reason,
      now: resolvedNow,
      boardingAt: availability.boardingAt,
    );
    if (revision == _reportAvailabilityRevision && nextReport != state.report) {
      emit(state.copyWith(report: nextReport));
    }
  }

  Future<void> _reportBlocGuard(
    Object error,
    StackTrace stackTrace, {
    required String event,
    required String attemptId,
  }) async {
    final context = ErrorReportContext(
      feature: 'rail_board',
      event: event,
      attemptId: attemptId,
    );
    _logger.log(event, context: context.toMap());
    await _errorReporter.reportNonFatal(
      error,
      stackTrace,
      reason: 'rail_board_$event',
      context: context,
    );
  }

  RailBoardReportState _deriveReportActionState(
    RailBoardReportState base, {
    required FirebaseAuthReadiness authReadiness,
    required RailReportActionReason reason,
    DateTime? now,
    DateTime? boardingAt,
  }) {
    final guardOutcome = _deriveGuardOutcome(
      authReadiness: authReadiness,
      reason: reason,
    );
    final hint = guardOutcome == RailReportGuardOutcome.hiddenAuthPending
        ? null
        : _reportActionHint(reason: reason, now: now, boardingAt: boardingAt);
    return base.copyWith(
      authReadiness: authReadiness,
      guardOutcome: guardOutcome,
      visibility: guardOutcome == RailReportGuardOutcome.hiddenAuthPending
          ? RailReportVisibility.hidden
          : RailReportVisibility.visible,
      submitEnabled: guardOutcome == RailReportGuardOutcome.visibleEnabled,
      actionReason: reason,
      hasReportedCurrentSession:
          reason == RailReportActionReason.alreadySubmitted,
      actionHint: hint,
    );
  }

  RailReportGuardOutcome _deriveGuardOutcome({
    required FirebaseAuthReadiness authReadiness,
    required RailReportActionReason reason,
  }) {
    if (!authReadiness.isReady) {
      return RailReportGuardOutcome.hiddenAuthPending;
    }
    if (reason == RailReportActionReason.alreadySubmitted) {
      return RailReportGuardOutcome.visibleBlockedAlreadyReported;
    }
    if (reason == RailReportActionReason.eligible ||
        reason == RailReportActionReason.verificationLimitedEligible) {
      return RailReportGuardOutcome.visibleEnabled;
    }
    return RailReportGuardOutcome.visibleBlockedWindow;
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
