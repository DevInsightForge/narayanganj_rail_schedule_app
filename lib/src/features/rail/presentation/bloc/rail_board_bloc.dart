import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../community/domain/entities/arrival_report.dart';
import '../../../community/domain/entities/device_identity.dart';
import '../../../community/domain/entities/predicted_stop_time.dart';
import '../../../community/domain/entities/session_status_snapshot.dart';
import '../../../community/domain/entities/train_session.dart';
import '../../../community/domain/repositories/arrival_report_repository.dart';
import '../../../community/domain/repositories/device_identity_repository.dart';
import '../../../community/domain/repositories/prediction_repository.dart';
import '../../../community/domain/repositories/rate_limit_policy_repository.dart';
import '../../../community/domain/repositories/session_repository.dart';
import '../../../community/domain/services/delay_classifier_service.dart';
import '../../../community/domain/services/downstream_prediction_service.dart';
import '../../../community/domain/services/report_confidence_service.dart';
import '../../../community/domain/services/session_lifecycle_service.dart';
import '../../../community/domain/services/session_status_aggregation_service.dart';
import '../../data/datasources/static_schedule_data_source.dart';
import '../../data/repositories/schedule_data_repository.dart';
import '../../domain/entities/rail_selection.dart';
import '../../domain/entities/rail_snapshot.dart';
import '../../domain/repositories/selection_repository.dart';
import '../../domain/services/rail_board_service.dart';

part 'rail_board_event.dart';
part 'rail_board_state.dart';

class RailBoardBloc extends Bloc<RailBoardEvent, RailBoardState> {
  RailBoardBloc({
    required RailBoardService boardService,
    required ScheduleDataRepository scheduleDataRepository,
    required SelectionRepository selectionRepository,
    required SessionRepository sessionRepository,
    required ArrivalReportRepository arrivalReportRepository,
    required PredictionRepository predictionRepository,
    required DeviceIdentityRepository deviceIdentityRepository,
    required RateLimitPolicyRepository rateLimitPolicyRepository,
    this.communityFeaturesEnabled = true,
    DateTime Function()? nowProvider,
  }) : _boardService = boardService,
       _scheduleDataRepository = scheduleDataRepository,
       _selectionRepository = selectionRepository,
       _sessionRepository = sessionRepository,
       _arrivalReportRepository = arrivalReportRepository,
       _predictionRepository = predictionRepository,
       _deviceIdentityRepository = deviceIdentityRepository,
       _rateLimitPolicyRepository = rateLimitPolicyRepository,
       _nowProvider = nowProvider ?? DateTime.now,
       _sessionLifecycleService = const SessionLifecycleService(),
       _reportConfidenceService = const ReportConfidenceService(),
       _downstreamPredictionService = const DownstreamPredictionService(),
       _sessionStatusAggregationService = const SessionStatusAggregationService(
         delayClassifierService: DelayClassifierService(),
         confidenceService: ReportConfidenceService(),
       ),
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
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => add(const RailBoardTicked()),
    );
  }

  static const _fallbackErrorMessage =
      'Unable to load schedule data. Please try again.';
  static const _routeId = 'narayanganj_line';
  static const _staleInsightThresholdSeconds = 10 * 60;
  static const _reportRateLimitKey = 'arrival_report';
  static const _reportDedupeBucketMinutes = 2;
  static const _reportDedupeRetentionMinutes = 10;

  RailBoardService _boardService;
  final ScheduleDataRepository _scheduleDataRepository;
  final SelectionRepository _selectionRepository;
  final SessionRepository _sessionRepository;
  final ArrivalReportRepository _arrivalReportRepository;
  final PredictionRepository _predictionRepository;
  final DeviceIdentityRepository _deviceIdentityRepository;
  final RateLimitPolicyRepository _rateLimitPolicyRepository;
  final DateTime Function() _nowProvider;
  final bool communityFeaturesEnabled;
  final SessionLifecycleService _sessionLifecycleService;
  final ReportConfidenceService _reportConfidenceService;
  final DownstreamPredictionService _downstreamPredictionService;
  final SessionStatusAggregationService _sessionStatusAggregationService;
  final String _bundledVersion = StaticScheduleDataSource.version;
  final Map<String, DateTime> _recentReportKeys = {};
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
    await _loadBoard(emit: emit, showLoading: true);
  }

  Future<void> _loadBoard({
    required Emitter<RailBoardState> emit,
    required bool showLoading,
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

      await _persistAndEmit(selection: selection, emit: emit);

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
      await _persistAndEmit(selection: selection, emit: emit);
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
    if (trainContextChanged) {
      await _refreshCommunityInsights(selection: selection, emit: emit);
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
    if (state.status == RailBoardStatus.ready) {
      if (!communityFeaturesEnabled) {
        emit(_buildState(state.selection));
        await _refreshReportAvailability(
          selection: state.selection,
          emit: emit,
        );
        return;
      }
      final now = _nowProvider();
      emit(_buildState(state.selection));
      await _refreshReportAvailability(
        selection: state.selection,
        emit: emit,
        now: now,
      );
      await _refreshCommunityInsights(selection: state.selection, emit: emit);
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

    final now = _nowProvider();
    final selection = state.selection;
    final session = await _findSessionForCurrentTrain(
      direction: selection.direction,
      now: now,
    );
    final boardingStop = session == null
        ? null
        : _findSessionStopForStation(
            session: session,
            stationId: selection.boardingStationId,
          );

    if (session == null || boardingStop == null) {
      emit(
        state.copyWith(
          report: state.report.copyWith(
            status: RailReportSubmissionStatus.error,
            feedbackMessage:
                'Arrival reporting is unavailable for the selected station.',
            clearRetryAfter: true,
          ),
        ),
      );
      return;
    }
    final boardingWindowState = _getBoardingReportWindowState(
      boardingAt: boardingStop.scheduledAt,
      now: now,
    );
    if (boardingWindowState != SessionLifecycleState.active) {
      emit(
        state.copyWith(
          report: state.report.copyWith(
            status: RailReportSubmissionStatus.error,
            feedbackMessage:
                'Arrival reporting is not open for this station at this time.',
            clearRetryAfter: true,
          ),
        ),
      );
      return;
    }

    DeviceIdentity identity;
    try {
      identity = await _deviceIdentityRepository.readOrCreateIdentity();
    } catch (_) {
      emit(
        state.copyWith(
          report: _deriveReportActionState(
            state.report.copyWith(
              status: RailReportSubmissionStatus.error,
              feedbackMessage:
                  'Could not prepare your arrival report right now.',
              clearRetryAfter: true,
            ),
            reason: RailReportActionReason.temporarilyUnavailable,
          ),
        ),
      );
      return;
    }
    await _deviceIdentityRepository.touchIdentity(now);
    final rateLimitDecision = await _rateLimitPolicyRepository.checkAllowance(
      key: _reportRateLimitKey,
      now: now,
    );
    if (!rateLimitDecision.allowed) {
      emit(
        state.copyWith(
          report: state.report.copyWith(
            status: RailReportSubmissionStatus.rateLimited,
            retryAfterSeconds: rateLimitDecision.retryAfterSeconds,
            feedbackMessage:
                'Please wait ${rateLimitDecision.retryAfterSeconds}s before reporting again.',
          ),
        ),
      );
      return;
    }

    final dedupeKey = _buildReportDedupeKey(
      sessionId: session.sessionId,
      stationId: selection.boardingStationId,
      deviceId: identity.deviceId,
      now: now,
    );
    if (_isDuplicateReport(dedupeKey: dedupeKey, now: now)) {
      emit(
        state.copyWith(
          report: _deriveReportActionState(
            state.report.copyWith(
              status: RailReportSubmissionStatus.success,
              feedbackMessage:
                  'Arrival report already recorded for this train.',
              clearRetryAfter: true,
            ),
            reason: RailReportActionReason.alreadySubmitted,
          ),
        ),
      );
      return;
    }

    final report = ArrivalReport(
      reportId: 'report:${now.microsecondsSinceEpoch}',
      sessionId: session.sessionId,
      stationId: selection.boardingStationId,
      deviceId: identity.deviceId,
      observedArrivalAt: now,
      submittedAt: now,
    );
    try {
      await _arrivalReportRepository.submitArrivalReport(report);
      await _rateLimitPolicyRepository.recordEvent(
        key: _reportRateLimitKey,
        now: now,
      );
      _recentReportKeys[dedupeKey] = now;
      emit(
        state.copyWith(
          report: _deriveReportActionState(
            state.report.copyWith(
              status: RailReportSubmissionStatus.success,
              feedbackMessage:
                  'Arrival reported for ${state.snapshot.selectedStationName}. Thank you.',
              clearRetryAfter: true,
            ),
            reason: RailReportActionReason.alreadySubmitted,
          ),
        ),
      );
      await _refreshCommunityInsights(selection: state.selection, emit: emit);
    } catch (_) {
      emit(
        state.copyWith(
          report: _deriveReportActionState(
            state.report.copyWith(
              status: RailReportSubmissionStatus.error,
              feedbackMessage:
                  'Arrival report could not be submitted. Please try again.',
              clearRetryAfter: true,
            ),
            reason: RailReportActionReason.temporarilyUnavailable,
          ),
        ),
      );
    }
  }

  Future<void> _refreshCommunityInsights({
    required RailSelection selection,
    required Emitter<RailBoardState> emit,
  }) async {
    emit(
      state.copyWith(
        community: state.community.copyWith(
          insightStatus: RailCommunityInsightStatus.loading,
        ),
      ),
    );

    try {
      final now = _nowProvider();
      final session = await _findSessionForCurrentTrain(
        direction: selection.direction,
        now: now,
      );

      if (session == null) {
        emit(
          state.copyWith(
            community: state.community.copyWith(
              insightStatus: RailCommunityInsightStatus.empty,
              lastResolvedInsightStatus: RailCommunityInsightStatus.empty,
              clearSessionStatus: true,
              predictedStopTimes: const [],
              message: 'No active train estimate is available right now.',
            ),
          ),
        );
        return;
      }

      final reportsByStation = <String, List<ArrivalReport>>{};
      for (final stop in session.stops) {
        reportsByStation[stop.stationId] = await _arrivalReportRepository
            .fetchStopReports(
              sessionId: session.sessionId,
              stationId: stop.stationId,
            );
      }

      final observedStops =
          session.stops
              .where(
                (stop) =>
                    (reportsByStation[stop.stationId] ?? const []).isNotEmpty,
              )
              .toList(growable: false)
            ..sort((a, b) => b.sequence.compareTo(a.sequence));

      if (observedStops.isEmpty) {
        emit(
          state.copyWith(
            community: state.community.copyWith(
              insightStatus: RailCommunityInsightStatus.empty,
              lastResolvedInsightStatus: RailCommunityInsightStatus.empty,
              clearSessionStatus: true,
              predictedStopTimes: const [],
              message:
                  'No community reports are available for this train session yet.',
            ),
          ),
        );
        return;
      }

      final referenceStop = observedStops.first;
      final referenceReports =
          reportsByStation[referenceStop.stationId] ?? const [];
      final consensus = _sessionStatusAggregationService.buildStationConsensus(
        session: session,
        stationId: referenceStop.stationId,
        reports: referenceReports,
        now: now,
      );

      final sessionState = _sessionLifecycleService.getState(
        session: session,
        now: now,
      );
      final status = _sessionStatusAggregationService.buildSessionStatus(
        session: session,
        state: sessionState,
        stationId: referenceStop.stationId,
        reports: referenceReports,
        now: now,
      );

      final localPredictions = consensus.observedArrivalAt == null
          ? const <PredictedStopTime>[]
          : _downstreamPredictionService.predictFromObservation(
              session: session,
              observedStationId: referenceStop.stationId,
              observedArrivalAt: consensus.observedArrivalAt!,
              confidence: _reportConfidenceService.evaluate(
                reports: referenceReports,
                now: now,
              ),
            );
      final remotePredictions = await _predictionRepository.fetchPredictions(
        sessionId: session.sessionId,
      );
      final predictions = remotePredictions.isNotEmpty
          ? remotePredictions
          : localPredictions;

      final isStale = status.freshnessSeconds > _staleInsightThresholdSeconds;
      emit(
        state.copyWith(
          community: state.community.copyWith(
            insightStatus: isStale
                ? RailCommunityInsightStatus.stale
                : RailCommunityInsightStatus.ready,
            lastResolvedInsightStatus: isStale
                ? RailCommunityInsightStatus.stale
                : RailCommunityInsightStatus.ready,
            sessionStatusSnapshot: status,
            predictedStopTimes: predictions,
            message: remotePredictions.isNotEmpty
                ? 'Estimate synchronized from remote community snapshots.'
                : 'Estimate based on ${referenceReports.length} report(s) from ${referenceStop.stationName}.',
          ),
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          community: state.community.copyWith(
            insightStatus: RailCommunityInsightStatus.error,
            lastResolvedInsightStatus: RailCommunityInsightStatus.error,
            clearSessionStatus: true,
            predictedStopTimes: const [],
            message:
                'Community estimate is temporarily unavailable. Official schedule remains available.',
          ),
        ),
      );
    }
  }

  Future<TrainSession?> _findSessionForCurrentTrain({
    required String direction,
    required DateTime now,
  }) async {
    final trainNo = state.snapshot.nextService?.trainNo;
    if (trainNo == null) {
      return null;
    }
    final sessions = await _fetchRouteSessions(now);
    final candidates = sessions
        .where(
          (session) =>
              session.directionId == direction && session.trainNo == trainNo,
        )
        .toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }
    for (final session in candidates) {
      if (_sessionLifecycleService.getState(session: session, now: now) ==
          SessionLifecycleState.active) {
        return session;
      }
    }
    for (final session in candidates) {
      if (_sessionLifecycleService.getState(session: session, now: now) ==
          SessionLifecycleState.upcoming) {
        return session;
      }
    }
    return candidates.last;
  }

  SessionStop? _findSessionStopForStation({
    required TrainSession session,
    required String stationId,
  }) {
    for (final stop in session.stops) {
      if (stop.stationId == stationId) {
        return stop;
      }
    }
    return null;
  }

  SessionLifecycleState _getBoardingReportWindowState({
    required DateTime boardingAt,
    required DateTime now,
  }) {
    final eligibilityStart = boardingAt.subtract(
      Duration(minutes: _sessionLifecycleService.preDepartureMinutes),
    );
    final eligibilityEnd = boardingAt.add(
      Duration(minutes: _sessionLifecycleService.postDepartureMinutes),
    );
    if (now.isBefore(eligibilityStart)) {
      return SessionLifecycleState.upcoming;
    }
    if (now.isAfter(eligibilityEnd)) {
      return SessionLifecycleState.expired;
    }
    return SessionLifecycleState.active;
  }

  Future<List<TrainSession>> _fetchRouteSessions(DateTime now) async {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final todaySessions = await _sessionRepository.fetchSessions(
      routeId: _routeId,
      serviceDate: today,
    );
    final tomorrowSessions = await _sessionRepository.fetchSessions(
      routeId: _routeId,
      serviceDate: tomorrow,
    );
    final sessions = [...todaySessions, ...tomorrowSessions]
      ..sort((a, b) => a.departureAt.compareTo(b.departureAt));
    return sessions;
  }

  String _buildReportDedupeKey({
    required String sessionId,
    required String stationId,
    required String deviceId,
    required DateTime now,
  }) {
    final bucket =
        now.millisecondsSinceEpoch ~/
        const Duration(minutes: _reportDedupeBucketMinutes).inMilliseconds;
    return '$sessionId:$stationId:$deviceId:$bucket';
  }

  bool _isDuplicateReport({required String dedupeKey, required DateTime now}) {
    _pruneRecentReportKeys(now);
    return _recentReportKeys.containsKey(dedupeKey);
  }

  void _pruneRecentReportKeys(DateTime now) {
    final cutoff = now.subtract(
      const Duration(minutes: _reportDedupeRetentionMinutes),
    );
    final expired = _recentReportKeys.entries
        .where((entry) => entry.value.isBefore(cutoff))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final key in expired) {
      _recentReportKeys.remove(key);
    }
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

    final referenceNow = now ?? _nowProvider();
    final session = await _findSessionForCurrentTrain(
      direction: selection.direction,
      now: referenceNow,
    );
    final boardingStop = session == null
        ? null
        : _findSessionStopForStation(
            session: session,
            stationId: selection.boardingStationId,
          );

    if (session == null ||
        boardingStop == null ||
        state.snapshot.nextService == null) {
      final nextReport = _deriveReportActionState(
        state.report,
        reason: RailReportActionReason.noSession,
      );
      if (revision == _reportAvailabilityRevision &&
          nextReport != state.report) {
        emit(state.copyWith(report: nextReport));
      }
      return;
    }

    final boardingWindowState = _getBoardingReportWindowState(
      boardingAt: boardingStop.scheduledAt,
      now: referenceNow,
    );
    if (boardingWindowState == SessionLifecycleState.upcoming) {
      final nextReport = _deriveReportActionState(
        state.report,
        reason: RailReportActionReason.beforeWindow,
        now: referenceNow,
        boardingAt: boardingStop.scheduledAt,
      );
      if (revision == _reportAvailabilityRevision &&
          nextReport != state.report) {
        emit(state.copyWith(report: nextReport));
      }
      return;
    }
    if (boardingWindowState == SessionLifecycleState.expired) {
      final nextReport = _deriveReportActionState(
        state.report,
        reason: RailReportActionReason.afterWindow,
      );
      if (revision == _reportAvailabilityRevision &&
          nextReport != state.report) {
        emit(state.copyWith(report: nextReport));
      }
      return;
    }

    DeviceIdentity identity;
    try {
      identity = await _deviceIdentityRepository.readOrCreateIdentity();
    } catch (_) {
      final nextReport = _deriveReportActionState(
        state.report,
        reason: RailReportActionReason.temporarilyUnavailable,
      );
      if (revision == _reportAvailabilityRevision &&
          nextReport != state.report) {
        emit(state.copyWith(report: nextReport));
      }
      return;
    }
    bool hasSubmitted;
    try {
      hasSubmitted = await _hasSubmittedForSession(
        session: session,
        stationId: selection.boardingStationId,
        deviceId: identity.deviceId,
        now: referenceNow,
      );
    } catch (_) {
      final nextReport = _deriveReportActionState(
        state.report,
        reason: RailReportActionReason.verificationLimitedEligible,
      );
      if (revision == _reportAvailabilityRevision &&
          nextReport != state.report) {
        emit(state.copyWith(report: nextReport));
      }
      return;
    }

    if (hasSubmitted) {
      final nextReport = _deriveReportActionState(
        state.report,
        reason: RailReportActionReason.alreadySubmitted,
      );
      if (revision == _reportAvailabilityRevision &&
          nextReport != state.report) {
        emit(state.copyWith(report: nextReport));
      }
      return;
    }

    final nextReport = _deriveReportActionState(
      state.report,
      reason: RailReportActionReason.eligible,
    );
    if (revision == _reportAvailabilityRevision && nextReport != state.report) {
      emit(state.copyWith(report: nextReport));
    }
  }

  Future<bool> _hasSubmittedForSession({
    required TrainSession session,
    required String stationId,
    required String deviceId,
    required DateTime now,
  }) async {
    _pruneRecentReportKeys(now);
    final dedupePrefix = '${session.sessionId}:$stationId:$deviceId:';
    final hasRecent = _recentReportKeys.keys.any(
      (key) => key.startsWith(dedupePrefix),
    );
    if (hasRecent) {
      return true;
    }
    final reports = await _arrivalReportRepository.fetchStopReports(
      sessionId: session.sessionId,
      stationId: stationId,
    );
    return reports.any((report) => report.deviceId == deviceId);
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
          final eligibilityStart = boardingAt.subtract(
            Duration(minutes: _sessionLifecycleService.preDepartureMinutes),
          );
          final remainingMinutes = eligibilityStart
              .difference(now)
              .inMinutes
              .clamp(0, 9999);
          return 'Reporting opens in $remainingMinutes minute(s).';
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
                  ? _bundledVersion
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
