import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../community/domain/entities/arrival_report.dart';
import '../../../community/domain/entities/train_session.dart';
import '../../../community/domain/repositories/arrival_report_repository.dart';
import '../../../community/domain/repositories/device_identity_repository.dart';
import '../../../community/domain/repositories/rate_limit_policy_repository.dart';
import '../../../community/domain/repositories/session_repository.dart';
import '../../../community/domain/services/session_lifecycle_service.dart';
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
    required DeviceIdentityRepository deviceIdentityRepository,
    required RateLimitPolicyRepository rateLimitPolicyRepository,
    DateTime Function()? nowProvider,
  }) : _boardService = boardService,
       _scheduleDataRepository = scheduleDataRepository,
       _selectionRepository = selectionRepository,
       _sessionRepository = sessionRepository,
       _arrivalReportRepository = arrivalReportRepository,
       _deviceIdentityRepository = deviceIdentityRepository,
       _rateLimitPolicyRepository = rateLimitPolicyRepository,
       _nowProvider = nowProvider ?? DateTime.now,
       _sessionLifecycleService = const SessionLifecycleService(),
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

  RailBoardService _boardService;
  final ScheduleDataRepository _scheduleDataRepository;
  final SelectionRepository _selectionRepository;
  final SessionRepository _sessionRepository;
  final ArrivalReportRepository _arrivalReportRepository;
  final DeviceIdentityRepository _deviceIdentityRepository;
  final RateLimitPolicyRepository _rateLimitPolicyRepository;
  final DateTime Function() _nowProvider;
  final SessionLifecycleService _sessionLifecycleService;
  final String _bundledVersion = StaticScheduleDataSource.version;
  final List<_PendingArrivalReport> _pendingReports = [];
  final Set<String> _sentReportKeys = {};
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

  void _onTicked(RailBoardTicked event, Emitter<RailBoardState> emit) {
    if (state.status == RailBoardStatus.ready) {
      emit(_buildState(state.selection));
    }
  }

  Future<void> _onArrivalReportRequested(
    RailBoardArrivalReportRequested event,
    Emitter<RailBoardState> emit,
  ) async {
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
    final rateLimitKey = 'arrival_report';
    final rateLimitDecision = await _rateLimitPolicyRepository.checkAllowance(
      key: rateLimitKey,
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
    if (_sentReportKeys.contains(dedupeKey)) {
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
      await _rateLimitPolicyRepository.recordEvent(key: rateLimitKey, now: now);
      _sentReportKeys.add(dedupeKey);
      _pendingReports.removeWhere((pending) => pending.dedupeKey == dedupeKey);
      emit(
        state.copyWith(
          reportSubmissionStatus: RailReportSubmissionStatus.success,
          reportFeedbackMessage:
              'Arrival reported for ${state.snapshot.selectedStationName}.',
          clearReportRetryAfter: true,
        ),
      );
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

  Future<TrainSession?> _findEligibleSession({
    required RailSelection selection,
    required DateTime now,
  }) async {
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

  String _buildReportDedupeKey({
    required String sessionId,
    required String stationId,
    required String deviceId,
    required DateTime now,
  }) {
    final bucket =
        now.millisecondsSinceEpoch ~/ const Duration(minutes: 2).inMilliseconds;
    return '$sessionId:$stationId:$deviceId:$bucket';
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
          .getSnapshot(selection: selection, now: DateTime.now())
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
    );
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await super.close();
  }

  static const _routeId = 'narayanganj_line';
}

class _PendingArrivalReport {
  const _PendingArrivalReport({required this.report, required this.dedupeKey});

  final ArrivalReport report;
  final String dedupeKey;
}
