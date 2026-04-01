export 'rail_board_state.dart';

import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../community/domain/entities/firebase_auth_readiness.dart';
import '../../../community/domain/repositories/arrival_report_ledger_repository.dart';
import '../../../community/domain/repositories/arrival_report_repository.dart';
import '../../../community/domain/repositories/community_overlay_repository.dart';
import '../../../community/domain/repositories/device_identity_repository.dart';
import '../../../community/domain/repositories/session_repository.dart';
import '../../../../core/errors/error_report_context.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/tracing/attempt_id_factory.dart';
import '../../application/models/rail_community_insight_result.dart';
import '../../application/models/rail_reporting.dart';
import '../../application/services/rail_board_use_case.dart';
import '../../data/repositories/schedule_data_repository.dart';
import '../../domain/entities/rail_selection.dart';
import '../../domain/repositories/selection_repository.dart';
import '../../domain/services/rail_board_service.dart';
import 'rail_board_state.dart';

class RailBoardCubit extends Cubit<RailBoardState> {
  RailBoardCubit({
    required RailBoardService boardService,
    required ScheduleDataRepository scheduleDataRepository,
    required SelectionRepository selectionRepository,
    required SessionRepository sessionRepository,
    required ArrivalReportRepository arrivalReportRepository,
    required ArrivalReportLedgerRepository arrivalReportLedgerRepository,
    required CommunityOverlayRepository communityOverlayRepository,
    required DeviceIdentityRepository deviceIdentityRepository,
    ErrorReporter? errorReporter,
    AttemptIdFactory? attemptIdFactory,
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
       _useCase = RailBoardUseCase(
         sessionRepository: sessionRepository,
         arrivalReportRepository: arrivalReportRepository,
         arrivalReportLedgerRepository: arrivalReportLedgerRepository,
         communityOverlayRepository: communityOverlayRepository,
         deviceIdentityRepository: deviceIdentityRepository,
         routeId: _routeId,
         errorReporter: errorReporter,
       ),
       _initialScheduleVersion = boardService.schedule.version,
       _activeSource = ScheduleDataSource.bundled,
       _lastUpdatedAt = null,
       super(const RailBoardState()) {
    unawaited(start());
    if (enableTicker) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        unawaited(tick());
      });
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
  final bool communityFeaturesEnabled;
  final bool enableTicker;
  final RailBoardUseCase _useCase;
  final String _initialScheduleVersion;
  int _reportAvailabilityRevision = 0;
  Timer? _timer;

  ScheduleDataSource _activeSource;
  DateTime? _lastUpdatedAt;

  RailBoardService get boardService => _boardService;

  Future<void> start() async {
    await _loadBoard(showLoading: true);
  }

  Future<void> retry() async {
    await _loadBoard(showLoading: true, forceCommunityRefresh: true);
  }

  Future<void> _loadBoard({
    required bool showLoading,
    bool forceCommunityRefresh = false,
  }) async {
    final attemptId = _attemptIdFactory.next();
    if (showLoading) {
      _emitIfOpen(
        state.copyWith(status: RailBoardStatus.loading, clearError: true),
      );
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
        forceCommunityRefresh: forceCommunityRefresh,
      );
    } catch (error, stackTrace) {
      await _reportCubitGuard(
        error,
        stackTrace,
        event: 'load_board',
        attemptId: attemptId,
      );
      _emitIfOpen(
        state.copyWith(
          status: RailBoardStatus.failure,
          errorMessage: _fallbackErrorMessage,
        ),
      );
    }
  }

  Future<void> _persistAndEmit({
    required RailSelection selection,
    bool forceCommunityRefresh = false,
  }) async {
    final attemptId = _attemptIdFactory.next();
    final previousDirection = state.selection.direction;
    final previousTrainNo = state.snapshot.nextService?.trainNo;
    try {
      await _selectionRepository.write(selection);
      _emitIfOpen(_buildState(selection));
      await _refreshReportAvailability(
        selection: selection,
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
          forceRefresh: forceCommunityRefresh,
          attemptId: attemptId,
        );
      }
    } catch (error, stackTrace) {
      await _reportCubitGuard(
        error,
        stackTrace,
        event: 'persist_and_emit',
        attemptId: attemptId,
      );
      _emitIfOpen(
        state.copyWith(
          status: RailBoardStatus.failure,
          errorMessage: _fallbackErrorMessage,
        ),
      );
    }
  }

  Future<void> changeDirection(String direction) async {
    final selection = _boardService.changeDirection(direction);
    await _persistAndEmit(selection: selection);
  }

  Future<void> changeBoarding(String stationId) async {
    final selection = _boardService.changeBoardingStation(
      state.selection,
      stationId,
    );
    await _persistAndEmit(selection: selection);
  }

  Future<void> changeDestination(String stationId) async {
    final selection = _boardService.changeDestinationStation(
      state.selection,
      stationId,
    );
    await _persistAndEmit(selection: selection);
  }

  Future<void> tick() async {
    if (state.status != RailBoardStatus.ready) {
      return;
    }
    _emitIfOpen(_buildState(state.selection));
    final now = _nowProvider();
    await _refreshReportAvailability(
      selection: state.selection,
      now: now,
      attemptId: _attemptIdFactory.next(),
    );
  }

  Future<void> submitArrivalReport() async {
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
      attemptId: attemptId,
    );
    if (!state.report.submitEnabled) {
      if (state.report.visibility == RailReportVisibility.hidden) {
        await _reportCubitGuard(
          StateError('report_submit_hidden'),
          StackTrace.current,
          event: 'submit_guard_hidden',
          attemptId: attemptId,
        );
        return;
      }
      await _reportCubitGuard(
        StateError('report_submit_blocked'),
        StackTrace.current,
        event: 'submit_guard_blocked',
        attemptId: attemptId,
      );
      _emitIfOpen(
        state.copyWith(
          report: state.report.copyWith(
            status: RailReportSubmissionStatus.error,
            feedbackMessage: 'Reporting is not available for this train yet.',
          ),
        ),
      );
      return;
    }

    _emitIfOpen(
      state.copyWith(
        report: state.report.copyWith(
          status: RailReportSubmissionStatus.submitting,
          clearFeedback: true,
        ),
      ),
    );

    final submission = await _useCase.submitReport(
      selection: state.selection,
      nextService: state.snapshot.nextService,
      selectedStationName: state.snapshot.selectedStationName,
      now: _nowProvider(),
      attemptId: attemptId,
    );

    _emitIfOpen(
      state.copyWith(
        report: _deriveReportActionState(
          state.report.copyWith(
            status: switch (submission.outcome) {
              RailReportSubmissionOutcome.success =>
                RailReportSubmissionStatus.success,
              RailReportSubmissionOutcome.error =>
                RailReportSubmissionStatus.error,
            },
            feedbackMessage: submission.feedbackMessage,
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
        attemptId: attemptId,
      );
    }

    if (submission.outcome == RailReportSubmissionOutcome.success) {
      await _refreshCommunityInsights(
        selection: state.selection,
        forceRefresh: true,
        attemptId: attemptId,
      );
    }
  }

  Future<void> _refreshCommunityInsights({
    required RailSelection selection,
    bool forceRefresh = false,
    String? attemptId,
  }) async {
    _emitIfOpen(
      state.copyWith(
        community: state.community.copyWith(
          insightStatus: RailCommunityInsightStatus.loading,
        ),
      ),
    );

    final result = await _useCase.loadCommunityInsights(
      direction: selection.direction,
      nextService: state.snapshot.nextService,
      now: _nowProvider(),
      forceRefresh: forceRefresh,
      attemptId: attemptId ?? _attemptIdFactory.next(),
    );
    final mappedStatus = _mapInsightKind(result.kind);
    _emitIfOpen(
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
    DateTime? now,
    String? attemptId,
  }) async {
    final revision = ++_reportAvailabilityRevision;
    final resolvedNow = now ?? _nowProvider();
    if (state.status != RailBoardStatus.ready || !communityFeaturesEnabled) {
      final nextReport = _deriveReportActionState(
        state.report,
        authReadiness: const FirebaseAuthReadiness.unknown(),
        reason: RailReportActionReason.noSession,
      );
      if (revision == _reportAvailabilityRevision &&
          nextReport != state.report) {
        _emitIfOpen(state.copyWith(report: nextReport));
      }
      return;
    }

    final resolvingReport = state.report.copyWith(
      authReadiness: const FirebaseAuthReadiness.resolving(),
      visibility: RailReportVisibility.hidden,
      submitEnabled: false,
      actionReason: RailReportActionReason.noSession,
      hasReportedCurrentSession: false,
    );
    if (revision == _reportAvailabilityRevision &&
        resolvingReport != state.report) {
      _emitIfOpen(state.copyWith(report: resolvingReport));
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
        visibility: RailReportVisibility.hidden,
        submitEnabled: false,
        actionReason: RailReportActionReason.noSession,
        hasReportedCurrentSession: false,
      );
      if (nextReport != state.report) {
        _emitIfOpen(state.copyWith(report: nextReport));
      }
      return;
    }

    final availability = await _useCase.resolveReportAvailability(
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
    );
    if (revision == _reportAvailabilityRevision && nextReport != state.report) {
      _emitIfOpen(state.copyWith(report: nextReport));
    }
  }

  Future<void> _reportCubitGuard(
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
  }) {
    return base.copyWith(
      authReadiness: authReadiness,
      visibility: authReadiness.isReady
          ? RailReportVisibility.visible
          : RailReportVisibility.hidden,
      submitEnabled:
          authReadiness.isReady &&
          (reason == RailReportActionReason.eligible ||
              reason == RailReportActionReason.verificationLimitedEligible),
      actionReason: reason,
      hasReportedCurrentSession:
          reason == RailReportActionReason.alreadySubmitted,
    );
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

  void _emitIfOpen(RailBoardState nextState) {
    if (isClosed) {
      return;
    }
    emit(nextState);
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await super.close();
  }
}
