import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../community/domain/entities/arrival_report.dart';
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
  final List<_PendingArrivalReport> _pendingReports = [];
  final Map<String, DateTime> _recentReportKeys = {};
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
    await _selectionRepository.write(selection);
    emit(_buildState(selection));
    if (!communityFeaturesEnabled) {
      return;
    }
    await _refreshCommunityInsights(selection: selection, emit: emit);
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
        return;
      }
      final now = _nowProvider();
      await _drainPendingReports(now: now);
      emit(_buildState(state.selection));
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

    emit(
      state.copyWith(
        reportSubmissionStatus: RailReportSubmissionStatus.submitting,
        clearReportFeedback: true,
        clearReportRetryAfter: true,
      ),
    );

    final now = _nowProvider();
    final selection = state.selection;
    final session = await _findEligibleSession(selection: selection, now: now);

    if (session == null ||
        !_sessionLifecycleService.isReportEligible(
          session: session,
          now: now,
        )) {
      emit(
        state.copyWith(
          reportSubmissionStatus: RailReportSubmissionStatus.error,
          reportFeedbackMessage:
              'No active report window for this trip right now.',
          clearReportRetryAfter: true,
        ),
      );
      return;
    }

    final identity = await _deviceIdentityRepository.readOrCreateIdentity();
    await _deviceIdentityRepository.touchIdentity(now);
    final rateLimitDecision = await _rateLimitPolicyRepository.checkAllowance(
      key: _reportRateLimitKey,
      now: now,
    );
    if (!rateLimitDecision.allowed) {
      emit(
        state.copyWith(
          reportSubmissionStatus: RailReportSubmissionStatus.rateLimited,
          reportRetryAfterSeconds: rateLimitDecision.retryAfterSeconds,
          reportFeedbackMessage:
              'Please wait ${rateLimitDecision.retryAfterSeconds}s before reporting again.',
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
          reportSubmissionStatus: RailReportSubmissionStatus.success,
          reportFeedbackMessage: 'Arrival already reported recently.',
          clearReportRetryAfter: true,
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
      _pendingReports.removeWhere((pending) => pending.dedupeKey == dedupeKey);
      emit(
        state.copyWith(
          reportSubmissionStatus: RailReportSubmissionStatus.success,
          reportFeedbackMessage:
              'Arrival reported for ${state.snapshot.selectedStationName}.',
          clearReportRetryAfter: true,
        ),
      );
      await _refreshCommunityInsights(selection: state.selection, emit: emit);
    } catch (_) {
      if (_pendingReports.every((pending) => pending.dedupeKey != dedupeKey)) {
        _pendingReports.add(
          _PendingArrivalReport(report: report, dedupeKey: dedupeKey),
        );
      }
      emit(
        state.copyWith(
          reportSubmissionStatus: RailReportSubmissionStatus.offlineQueue,
          reportFeedbackMessage:
              'Report queued locally and will sync when services recover.',
          clearReportRetryAfter: true,
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
        communityInsightStatus: RailCommunityInsightStatus.loading,
        clearCommunityMessage: true,
      ),
    );

    try {
      final now = _nowProvider();
      final session = await _findCommunitySession(
        selection: selection,
        now: now,
      );

      if (session == null) {
        emit(
          state.copyWith(
            communityInsightStatus: RailCommunityInsightStatus.empty,
            sessionStatusSnapshot: null,
            predictedStopTimes: const [],
            communityMessage:
                'No active or upcoming session insights right now.',
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
            communityInsightStatus: RailCommunityInsightStatus.empty,
            sessionStatusSnapshot: null,
            predictedStopTimes: const [],
            communityMessage:
                'No community reports yet for this train session.',
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
          communityInsightStatus: isStale
              ? RailCommunityInsightStatus.stale
              : RailCommunityInsightStatus.ready,
          sessionStatusSnapshot: status,
          predictedStopTimes: predictions,
          communityMessage: remotePredictions.isNotEmpty
              ? 'Estimate synchronized from Firebase session snapshot.'
              : 'Estimate based on ${referenceReports.length} report(s) at ${referenceStop.stationName}.',
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          communityInsightStatus: RailCommunityInsightStatus.error,
          clearSessionStatus: true,
          predictedStopTimes: const [],
          communityMessage:
              'Community data is temporarily unavailable. Schedule baseline remains available.',
        ),
      );
    }
  }

  Future<TrainSession?> _findEligibleSession({
    required RailSelection selection,
    required DateTime now,
  }) async {
    final sessions = await _fetchRouteSessions(now);
    for (final session in sessions) {
      final fromIndex = session.stops.indexWhere(
        (stop) => stop.stationId == selection.boardingStationId,
      );
      final toIndex = session.stops.indexWhere(
        (stop) => stop.stationId == selection.destinationStationId,
      );
      if (fromIndex < 0 || toIndex < 0 || fromIndex >= toIndex) {
        continue;
      }
      if (_sessionLifecycleService.isReportEligible(
        session: session,
        now: now,
      )) {
        return session;
      }
    }
    return null;
  }

  Future<TrainSession?> _findCommunitySession({
    required RailSelection selection,
    required DateTime now,
  }) async {
    final sessions = await _fetchRouteSessions(now);
    TrainSession? nextUpcoming;
    for (final session in sessions) {
      final fromIndex = session.stops.indexWhere(
        (stop) => stop.stationId == selection.boardingStationId,
      );
      final toIndex = session.stops.indexWhere(
        (stop) => stop.stationId == selection.destinationStationId,
      );
      if (fromIndex < 0 || toIndex < 0 || fromIndex >= toIndex) {
        continue;
      }
      final sessionState = _sessionLifecycleService.getState(
        session: session,
        now: now,
      );
      if (sessionState == SessionLifecycleState.active) {
        return session;
      }
      if (sessionState == SessionLifecycleState.upcoming &&
          session.departureAt.isAfter(now)) {
        nextUpcoming ??= session;
      }
    }
    return nextUpcoming;
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

  Future<void> _drainPendingReports({required DateTime now}) async {
    if (_pendingReports.isEmpty) {
      return;
    }
    _pruneRecentReportKeys(now);
    final sent = <String>{};
    for (final pending in List<_PendingArrivalReport>.from(_pendingReports)) {
      if (_isDuplicateReport(dedupeKey: pending.dedupeKey, now: now)) {
        sent.add(pending.dedupeKey);
        continue;
      }
      final decision = await _rateLimitPolicyRepository.checkAllowance(
        key: _reportRateLimitKey,
        now: now,
      );
      if (!decision.allowed) {
        continue;
      }
      try {
        await _arrivalReportRepository.submitArrivalReport(pending.report);
        await _rateLimitPolicyRepository.recordEvent(
          key: _reportRateLimitKey,
          now: now,
        );
        _recentReportKeys[pending.dedupeKey] = now;
        sent.add(pending.dedupeKey);
      } catch (_) {}
    }
    if (sent.isNotEmpty) {
      _pendingReports.removeWhere(
        (pending) => sent.contains(pending.dedupeKey),
      );
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
      errorMessage: null,
      reportSubmissionStatus: state.reportSubmissionStatus,
      reportFeedbackMessage: state.reportFeedbackMessage,
      reportRetryAfterSeconds: state.reportRetryAfterSeconds,
      communityInsightStatus: state.communityInsightStatus,
      sessionStatusSnapshot: state.sessionStatusSnapshot,
      predictedStopTimes: state.predictedStopTimes,
      communityMessage: state.communityMessage,
      communityFeaturesEnabled: communityFeaturesEnabled,
    );
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await super.close();
  }
}

class _PendingArrivalReport {
  const _PendingArrivalReport({required this.report, required this.dedupeKey});

  final ArrivalReport report;
  final String dedupeKey;
}
