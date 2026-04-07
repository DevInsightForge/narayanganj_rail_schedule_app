import 'dart:async';

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

typedef RailBoardStateReader = RailBoardState Function();
typedef RailBoardStateEmitter = void Function(RailBoardState state);

class RailBoardController {
  RailBoardController({
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
       _lastUpdatedAt = null;

  static const _fallbackErrorMessage =
      'Unable to load schedule data. Please try again.';
  static const _routeId = 'narayanganj_line';

  final ScheduleDataRepository _scheduleDataRepository;
  final SelectionRepository _selectionRepository;
  final DeviceIdentityRepository _deviceIdentityRepository;
  final DateTime Function() _nowProvider;
  final ErrorReporter _errorReporter;
  final AttemptIdFactory _attemptIdFactory;
  final bool communityFeaturesEnabled;
  final RailBoardUseCase _useCase;
  final String _initialScheduleVersion;
  int _reportAvailabilityRevision = 0;

  RailBoardService _boardService;
  ScheduleDataSource _activeSource;
  DateTime? _lastUpdatedAt;

  RailBoardService get boardService => _boardService;

  Future<void> start(
    RailBoardStateReader readState,
    RailBoardStateEmitter emit,
  ) async {
    await _loadBoard(readState, emit, showLoading: true);
  }

  Future<void> retry(
    RailBoardStateReader readState,
    RailBoardStateEmitter emit,
  ) async {
    await _loadBoard(
      readState,
      emit,
      showLoading: true,
      forceCommunityRefresh: true,
    );
  }

  Future<void> changeDirection(
    RailBoardStateReader readState,
    RailBoardStateEmitter emit,
    String direction,
  ) async {
    final selection = _boardService.changeDirection(direction);
    await _persistAndEmit(
      readState,
      emit,
      selection: selection,
    );
  }

  Future<void> changeBoarding(
    RailBoardStateReader readState,
    RailBoardStateEmitter emit,
    String stationId,
  ) async {
    final selection = _boardService.changeBoardingStation(
      readState().selection,
      stationId,
    );
    await _persistAndEmit(
      readState,
      emit,
      selection: selection,
    );
  }

  Future<void> changeDestination(
    RailBoardStateReader readState,
    RailBoardStateEmitter emit,
    String stationId,
  ) async {
    final selection = _boardService.changeDestinationStation(
      readState().selection,
      stationId,
    );
    await _persistAndEmit(
      readState,
      emit,
      selection: selection,
    );
  }

  Future<void> tick(
    RailBoardStateReader readState,
    RailBoardStateEmitter emit,
  ) async {
    final currentState = readState();
    if (currentState.status != RailBoardStatus.ready) {
      return;
    }
    emit(_buildState(currentState.selection, currentState));
    await _refreshReportAvailability(
      readState,
      emit,
      selection: currentState.selection,
      now: _nowProvider(),
      attemptId: _attemptIdFactory.next(),
    );
  }

  Future<void> submitArrivalReport(
    RailBoardStateReader readState,
    RailBoardStateEmitter emit,
  ) async {
    final currentState = readState();
    if (!communityFeaturesEnabled) {
      return;
    }
    if (currentState.status != RailBoardStatus.ready ||
        currentState.snapshot.nextService == null) {
      return;
    }

    final attemptId = _attemptIdFactory.next();
    await _refreshReportAvailability(
      readState,
      emit,
      selection: currentState.selection,
      attemptId: attemptId,
    );
    final refreshedState = readState();
    if (!refreshedState.report.submitEnabled) {
      if (refreshedState.report.visibility == RailReportVisibility.hidden) {
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
      emit(
        refreshedState.copyWith(
          report: refreshedState.report.copyWith(
            status: RailReportSubmissionStatus.error,
            feedbackMessage: _blockedReportMessage(
              refreshedState.report.actionReason,
            ),
          ),
        ),
      );
      return;
    }

    emit(
      refreshedState.copyWith(
        report: refreshedState.report.copyWith(
          status: RailReportSubmissionStatus.submitting,
          clearFeedback: true,
        ),
      ),
    );

    final submission = await _useCase.submitReport(
      selection: readState().selection,
      nextService: readState().snapshot.nextService,
      selectedStationName: readState().snapshot.selectedStationName,
      now: _nowProvider(),
      attemptId: attemptId,
    );

    final afterSubmissionState = readState();
    emit(
      afterSubmissionState.copyWith(
        report: _deriveReportActionState(
          afterSubmissionState.report.copyWith(
            status: switch (submission.outcome) {
              RailReportSubmissionOutcome.success =>
                RailReportSubmissionStatus.success,
              RailReportSubmissionOutcome.error =>
                RailReportSubmissionStatus.error,
            },
            feedbackMessage: submission.feedbackMessage,
          ),
          authReadiness: afterSubmissionState.report.authReadiness,
          reason: submission.reason,
        ),
      ),
    );

    if (submission.failureReason ==
        RailReportSubmissionFailureReason.authNotReady) {
      await _refreshReportAvailability(
        readState,
        emit,
        selection: readState().selection,
        attemptId: attemptId,
      );
    }

    if (submission.outcome == RailReportSubmissionOutcome.success) {
      await _refreshCommunityInsights(
        readState,
        emit,
        selection: readState().selection,
        forceRefresh: true,
        attemptId: attemptId,
      );
    }
  }

  Future<void> _loadBoard(
    RailBoardStateReader readState,
    RailBoardStateEmitter emit, {
    required bool showLoading,
    bool forceCommunityRefresh = false,
  }) async {
    final attemptId = _attemptIdFactory.next();
    if (showLoading) {
      emit(readState().copyWith(status: RailBoardStatus.loading, clearError: true));
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
        readState,
        emit,
        selection: selection,
        forceCommunityRefresh: forceCommunityRefresh,
      );

      final remoteSchedule = await _scheduleDataRepository.fetchRemoteSchedule();
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
        readState,
        emit,
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
      emit(
        readState().copyWith(
          status: RailBoardStatus.failure,
          errorMessage: _fallbackErrorMessage,
        ),
      );
    }
  }

  Future<void> _persistAndEmit(
    RailBoardStateReader readState,
    RailBoardStateEmitter emit, {
    required RailSelection selection,
    bool forceCommunityRefresh = false,
  }) async {
    final attemptId = _attemptIdFactory.next();
    final previousState = readState();
    final previousDirection = previousState.selection.direction;
    final previousTrainNo = previousState.snapshot.nextService?.trainNo;
    try {
      await _selectionRepository.write(selection);
      emit(_buildState(selection, readState()));
      await _refreshReportAvailability(
        readState,
        emit,
        selection: selection,
        attemptId: attemptId,
      );
      if (!communityFeaturesEnabled) {
        return;
      }
      final currentState = readState();
      final nextDirection = currentState.selection.direction;
      final nextTrainNo = currentState.snapshot.nextService?.trainNo;
      final trainContextChanged =
          previousDirection != nextDirection || previousTrainNo != nextTrainNo;
      if (trainContextChanged || forceCommunityRefresh) {
        await _refreshCommunityInsights(
          readState,
          emit,
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
      emit(
        readState().copyWith(
          status: RailBoardStatus.failure,
          errorMessage: _fallbackErrorMessage,
        ),
      );
    }
  }

  Future<void> _refreshCommunityInsights(
    RailBoardStateReader readState,
    RailBoardStateEmitter emit, {
    required RailSelection selection,
    bool forceRefresh = false,
    String? attemptId,
  }) async {
    emit(
      readState().copyWith(
        community: readState().community.copyWith(
          insightStatus: RailCommunityInsightStatus.loading,
        ),
      ),
    );

    final result = await _useCase.loadCommunityInsights(
      direction: selection.direction,
      nextService: readState().snapshot.nextService,
      now: _nowProvider(),
      forceRefresh: forceRefresh,
      attemptId: attemptId ?? _attemptIdFactory.next(),
    );
    final mappedStatus = _mapInsightKind(result.kind);
    final currentState = readState();
    emit(
      currentState.copyWith(
        community: currentState.community.copyWith(
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

  Future<void> _refreshReportAvailability(
    RailBoardStateReader readState,
    RailBoardStateEmitter emit, {
    required RailSelection selection,
    DateTime? now,
    String? attemptId,
  }) async {
    final revision = ++_reportAvailabilityRevision;
    final resolvedNow = now ?? _nowProvider();
    final currentState = readState();
    if (currentState.status != RailBoardStatus.ready ||
        !communityFeaturesEnabled) {
      final nextReport = _deriveReportActionState(
        currentState.report,
        authReadiness: const FirebaseAuthReadiness.unknown(),
        reason: RailReportActionReason.noSession,
      );
      if (revision == _reportAvailabilityRevision &&
          nextReport != currentState.report) {
        emit(currentState.copyWith(report: nextReport));
      }
      return;
    }

    final resolvingReport = currentState.report.copyWith(
      authReadiness: const FirebaseAuthReadiness.resolving(),
      visibility: RailReportVisibility.hidden,
      submitEnabled: false,
      actionReason: RailReportActionReason.noSession,
      hasReportedCurrentSession: false,
    );
    if (revision == _reportAvailabilityRevision &&
        resolvingReport != currentState.report) {
      emit(currentState.copyWith(report: resolvingReport));
    }

    final currentAttemptId = attemptId ?? _attemptIdFactory.next();
    final authReadiness = await _deviceIdentityRepository.readAuthReadiness(
      attemptId: currentAttemptId,
    );
    if (revision != _reportAvailabilityRevision) {
      return;
    }
    if (!authReadiness.isReady) {
      final nextReport = readState().report.copyWith(
        authReadiness: authReadiness,
        visibility: RailReportVisibility.hidden,
        submitEnabled: false,
        actionReason: RailReportActionReason.noSession,
        hasReportedCurrentSession: false,
      );
      if (nextReport != readState().report) {
        emit(readState().copyWith(report: nextReport));
      }
      return;
    }

    final availability = await _useCase.resolveReportAvailability(
      selection: selection,
      nextService: readState().snapshot.nextService,
      now: resolvedNow,
      attemptId: currentAttemptId,
    );
    if (revision != _reportAvailabilityRevision) {
      return;
    }
    final nextReport = _deriveReportActionState(
      readState().report,
      authReadiness: authReadiness,
      reason: availability.reason,
    );
    if (revision == _reportAvailabilityRevision &&
        nextReport != readState().report) {
      emit(readState().copyWith(report: nextReport));
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

  String _blockedReportMessage(RailReportActionReason reason) {
    return switch (reason) {
      RailReportActionReason.stationCapacityReached =>
        'Arrival reporting is full for this station on this train right now.',
      _ => 'Reporting is not available for this train yet.',
    };
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

  RailBoardState _buildState(RailSelection selection, RailBoardState state) {
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
}
