import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../community/domain/entities/arrival_report.dart';
import '../../../community/domain/entities/arrival_report_submission.dart';
import '../../../community/domain/entities/data_origin.dart';
import '../../../community/domain/entities/community_overlay_result.dart';
import '../../../community/domain/entities/predicted_stop_time.dart';
import '../../../community/domain/entities/session_status_snapshot.dart';
import '../../../community/domain/entities/train_session.dart';
import '../../../community/domain/repositories/arrival_report_ledger_repository.dart';
import '../../../community/domain/repositories/arrival_report_repository.dart';
import '../../../community/domain/repositories/community_overlay_repository.dart';
import '../../../community/domain/repositories/device_identity_repository.dart';
import '../../../community/domain/repositories/session_repository.dart';
import '../../../community/domain/services/session_lifecycle_service.dart';
import '../../../../core/errors/error_report_context.dart';
import '../../../../core/errors/error_reporter.dart';
import '../models/rail_community_insight_result.dart';
import '../models/rail_reporting.dart';
import '../../domain/entities/rail_selection.dart';
import '../../domain/entities/rail_snapshot.dart';

class RailBoardUseCase {
  RailBoardUseCase({
    required SessionRepository sessionRepository,
    required ArrivalReportRepository arrivalReportRepository,
    required ArrivalReportLedgerRepository arrivalReportLedgerRepository,
    required CommunityOverlayRepository communityOverlayRepository,
    required DeviceIdentityRepository deviceIdentityRepository,
    required this.routeId,
    ErrorReporter? errorReporter,
    SessionLifecycleService? sessionLifecycleService,
    this.reportDedupeBucketMinutes = 2,
    this.reportDedupeRetentionMinutes = 10,
    this.staleInsightThresholdSeconds = 10 * 60,
  }) : _sessionRepository = sessionRepository,
       _arrivalReportRepository = arrivalReportRepository,
       _arrivalReportLedgerRepository = arrivalReportLedgerRepository,
       _communityOverlayRepository = communityOverlayRepository,
       _deviceIdentityRepository = deviceIdentityRepository,
       _errorReporter = errorReporter ?? const NoopErrorReporter(),
       _sessionLifecycleService =
           sessionLifecycleService ?? const SessionLifecycleService();

  final SessionRepository _sessionRepository;
  final ArrivalReportRepository _arrivalReportRepository;
  final ArrivalReportLedgerRepository _arrivalReportLedgerRepository;
  final CommunityOverlayRepository _communityOverlayRepository;
  final DeviceIdentityRepository _deviceIdentityRepository;
  final ErrorReporter _errorReporter;
  final SessionLifecycleService _sessionLifecycleService;
  final String routeId;
  final int reportDedupeBucketMinutes;
  final int reportDedupeRetentionMinutes;
  final int staleInsightThresholdSeconds;
  final Map<String, DateTime> _recentReportKeys = {};
  final Set<String> _inFlightSubmissionKeys = <String>{};
  final Set<String> _submittedSessionKeys = <String>{};

  Future<RailReportAvailabilityResult> resolveReportAvailability({
    required RailSelection selection,
    required RailServiceSnapshot? nextService,
    required DateTime now,
    String? attemptId,
  }) async {
    try {
      final session = await _findSessionForTrain(
        direction: selection.direction,
        trainNo: nextService?.trainNo,
        now: now,
      );
      final boardingStop = session == null
          ? null
          : _findStopForStation(
              session: session,
              stationId: selection.boardingStationId,
            );
      if (session == null || boardingStop == null || nextService == null) {
        return const RailReportAvailabilityResult(
          reason: RailReportActionReason.noSession,
        );
      }

      final boardingWindowState = _getBoardingWindowState(
        boardingAt: boardingStop.scheduledAt,
        now: now,
      );
      if (boardingWindowState == SessionLifecycleState.upcoming) {
        return const RailReportAvailabilityResult(
          reason: RailReportActionReason.beforeWindow,
        );
      }
      if (boardingWindowState == SessionLifecycleState.expired) {
        return const RailReportAvailabilityResult(
          reason: RailReportActionReason.afterWindow,
        );
      }
      final identity = await _deviceIdentityRepository.readOrCreateIdentity(
        attemptId: attemptId,
      );
      try {
        final hasSubmitted = await _hasSubmittedForSession(
          sessionId: session.sessionId,
          stationId: selection.boardingStationId,
          deviceId: identity.deviceId,
          now: now,
        );
        if (hasSubmitted) {
          return const RailReportAvailabilityResult(
            reason: RailReportActionReason.alreadySubmitted,
          );
        }
      } catch (error, stackTrace) {
        await _reportNonFatal(
          error,
          stackTrace,
          feature: 'rail_board_use_case',
          event: 'resolve_availability_ledger',
          attemptId: attemptId,
          sessionId: session.sessionId,
          stationId: selection.boardingStationId,
          uid: identity.deviceId,
        );
        return const RailReportAvailabilityResult(
          reason: RailReportActionReason.verificationLimitedEligible,
        );
      }

      try {
        final submissionCount = await _arrivalReportRepository
            .fetchStationSubmissionCount(
              sessionId: session.sessionId,
              stationId: selection.boardingStationId,
            );
        if (submissionCount >= 10) {
          return const RailReportAvailabilityResult(
            reason: RailReportActionReason.stationCapacityReached,
          );
        }
      } catch (error, stackTrace) {
        await _reportNonFatal(
          error,
          stackTrace,
          feature: 'rail_board_use_case',
          event: 'resolve_availability_station_count',
          attemptId: attemptId,
          sessionId: session.sessionId,
          stationId: selection.boardingStationId,
        );
      }

      return const RailReportAvailabilityResult(
        reason: RailReportActionReason.eligible,
      );
    } catch (error, stackTrace) {
      await _reportNonFatal(
        error,
        stackTrace,
        feature: 'rail_board_use_case',
        event: 'resolve_availability',
        attemptId: attemptId,
        stationId: selection.boardingStationId,
      );
      return const RailReportAvailabilityResult(
        reason: RailReportActionReason.temporarilyUnavailable,
      );
    }
  }

  Future<RailReportSubmissionResult> submitReport({
    required RailSelection selection,
    required RailServiceSnapshot? nextService,
    required String selectedStationName,
    required DateTime now,
    String? attemptId,
  }) async {
    final validationFailure = _validateSubmission(
      selection: selection,
      nextService: nextService,
      selectedStationName: selectedStationName,
    );
    if (validationFailure != null) {
      return validationFailure;
    }

    try {
      final session = await _findSessionForTrain(
        direction: selection.direction,
        trainNo: nextService?.trainNo,
        now: now,
      );
      final boardingStop = session == null
          ? null
          : _findStopForStation(
              session: session,
              stationId: selection.boardingStationId,
            );
      if (session == null || boardingStop == null || nextService == null) {
        return const RailReportSubmissionResult(
          outcome: RailReportSubmissionOutcome.error,
          reason: RailReportActionReason.noSession,
          feedbackMessage:
              'Arrival reporting is unavailable for the selected station.',
        );
      }

      final boardingWindowState = _getBoardingWindowState(
        boardingAt: boardingStop.scheduledAt,
        now: now,
      );
      if (boardingWindowState != SessionLifecycleState.active) {
        return RailReportSubmissionResult(
          outcome: RailReportSubmissionOutcome.error,
          reason: boardingWindowState == SessionLifecycleState.upcoming
              ? RailReportActionReason.beforeWindow
              : RailReportActionReason.afterWindow,
          feedbackMessage:
              'Arrival reporting is not open for this station at this time.',
        );
      }

      final authReadiness = await _deviceIdentityRepository.readAuthReadiness(
        attemptId: attemptId,
      );
      if (!authReadiness.isReady) {
        return const RailReportSubmissionResult(
          outcome: RailReportSubmissionOutcome.error,
          reason: RailReportActionReason.temporarilyUnavailable,
          feedbackMessage:
              'Sign in is not ready yet. Please try again shortly.',
          failureReason: RailReportSubmissionFailureReason.authNotReady,
        );
      }

      final identity = await _deviceIdentityRepository.readOrCreateIdentity(
        attemptId: attemptId,
      );

      final dedupeKey = _buildReportDedupeKey(
        sessionId: session.sessionId,
        stationId: selection.boardingStationId,
        deviceId: identity.deviceId,
        now: now,
      );
      final submissionKey = _buildSubmissionKey(
        sessionId: session.sessionId,
        stationId: selection.boardingStationId,
        deviceId: identity.deviceId,
      );
      var alreadySubmitted = _submittedSessionKeys.contains(submissionKey);
      if (!alreadySubmitted) {
        try {
          alreadySubmitted = await _arrivalReportLedgerRepository.hasSubmitted(
            sessionId: session.sessionId,
            stationId: selection.boardingStationId,
            deviceId: identity.deviceId,
            now: now,
          );
        } catch (error, stackTrace) {
          await _reportNonFatal(
            error,
            stackTrace,
            feature: 'rail_board_use_case',
            event: 'submit_ledger_read',
            attemptId: attemptId,
            sessionId: session.sessionId,
            stationId: selection.boardingStationId,
            uid: identity.deviceId,
          );
          alreadySubmitted = false;
        }
      }
      if (_inFlightSubmissionKeys.contains(submissionKey) ||
          _isDuplicateReport(dedupeKey: dedupeKey, now: now) ||
          alreadySubmitted) {
        return const RailReportSubmissionResult(
          outcome: RailReportSubmissionOutcome.success,
          reason: RailReportActionReason.alreadySubmitted,
          feedbackMessage: 'Arrival report already recorded for this train.',
        );
      }

      final report = ArrivalReport(
        reportId: 'report:${now.microsecondsSinceEpoch}',
        sessionId: session.sessionId,
        stationId: selection.boardingStationId,
        deviceId: identity.deviceId,
        observedArrivalAt: now,
        submittedAt: now,
      );
      _inFlightSubmissionKeys.add(submissionKey);
      try {
        await _arrivalReportRepository.submitArrivalReport(
          ArrivalReportSubmission(
            report: report,
            session: session,
            stationStop: boardingStop,
          ),
        );
        _submittedSessionKeys.add(submissionKey);
        _recentReportKeys[dedupeKey] = now;
        try {
          await _arrivalReportLedgerRepository.markSubmitted(
            sessionId: session.sessionId,
            stationId: selection.boardingStationId,
            deviceId: identity.deviceId,
            submittedAt: now,
          );
        } catch (error, stackTrace) {
          await _reportNonFatal(
            error,
            stackTrace,
            feature: 'rail_board_use_case',
            event: 'submit_ledger_write',
            attemptId: attemptId,
            sessionId: session.sessionId,
            stationId: selection.boardingStationId,
            uid: identity.deviceId,
          );
        }
        return RailReportSubmissionResult(
          outcome: RailReportSubmissionOutcome.success,
          reason: RailReportActionReason.alreadySubmitted,
          feedbackMessage:
              'Arrival reported for $selectedStationName. Thank you.',
        );
      } on FirebaseException catch (error, stackTrace) {
        final failureReason = _mapSubmissionFailureReason(error);
        await _reportNonFatal(
          error,
          stackTrace,
          feature: 'rail_board_use_case',
          event: 'submit_firestore',
          attemptId: attemptId,
          sessionId: session.sessionId,
          stationId: selection.boardingStationId,
          uid: identity.deviceId,
        );
        return _failureResult(
          failureReason: failureReason,
          reason: RailReportActionReason.temporarilyUnavailable,
        );
      } on ArrivalReportRepositoryException catch (error, stackTrace) {
        final failureReason =
            error.code == ArrivalReportRepositoryErrorCode.permissionDenied
            ? RailReportSubmissionFailureReason.permissionDenied
            : error.code ==
                  ArrivalReportRepositoryErrorCode.stationCapacityReached
            ? RailReportSubmissionFailureReason.stationCapacityReached
            : RailReportSubmissionFailureReason.invalidPayload;
        await _reportNonFatal(
          error,
          stackTrace,
          feature: 'rail_board_use_case',
          event: 'submit_repository',
          attemptId: attemptId,
          sessionId: session.sessionId,
          stationId: selection.boardingStationId,
          uid: identity.deviceId,
        );
        return _failureResult(
          failureReason: failureReason,
          reason:
              failureReason ==
                  RailReportSubmissionFailureReason.stationCapacityReached
              ? RailReportActionReason.stationCapacityReached
              : RailReportActionReason.temporarilyUnavailable,
        );
      } catch (error, stackTrace) {
        final failureReason = _mapSubmissionFailureReason(error);
        await _reportNonFatal(
          error,
          stackTrace,
          feature: 'rail_board_use_case',
          event: 'submit_failed',
          attemptId: attemptId,
          sessionId: session.sessionId,
          stationId: selection.boardingStationId,
          uid: identity.deviceId,
        );
        return _failureResult(
          failureReason: failureReason,
          reason: RailReportActionReason.temporarilyUnavailable,
        );
      } finally {
        _inFlightSubmissionKeys.remove(submissionKey);
      }
    } catch (error, stackTrace) {
      await _reportNonFatal(
        error,
        stackTrace,
        feature: 'rail_board_use_case',
        event: 'submit',
        attemptId: attemptId,
        stationId: selection.boardingStationId,
      );
      return _failureResult(
        failureReason: _mapSubmissionFailureReason(error),
        reason: RailReportActionReason.temporarilyUnavailable,
      );
    }
  }

  Future<RailCommunityInsightResult> loadCommunityInsights({
    required String direction,
    required RailServiceSnapshot? nextService,
    required DateTime now,
    bool forceRefresh = false,
    String? attemptId,
  }) async {
    try {
      final session = await _findSessionForTrain(
        direction: direction,
        trainNo: nextService?.trainNo,
        now: now,
      );
      if (session == null) {
        return const RailCommunityInsightResult(
          kind: RailCommunityInsightKind.empty,
          message: 'No active train estimate is available right now.',
        );
      }

      final overlay = await _communityOverlayRepository.fetchSessionOverlay(
        sessionId: session.sessionId,
        forceRefresh: forceRefresh,
      );
      final snapshot = _applyOverlayAge(overlay, now);
      if (snapshot == null && overlay.predictedStopTimes.isEmpty) {
        return const RailCommunityInsightResult(
          kind: RailCommunityInsightKind.empty,
          message:
              'No community reports are available for this train session yet.',
        );
      }

      final isStale =
          snapshot != null &&
          snapshot.freshnessSeconds > staleInsightThresholdSeconds;
      return RailCommunityInsightResult(
        kind: isStale
            ? RailCommunityInsightKind.stale
            : RailCommunityInsightKind.ready,
        sessionStatusSnapshot: snapshot,
        predictedStopTimes: snapshot == null
            ? overlay.predictedStopTimes
            : _buildPredictedStopTimes(session: session, snapshot: snapshot),
        message: overlay.fromCache
            ? 'Estimate loaded from local community cache.'
            : 'Estimate synchronized from the latest community aggregate.',
      );
    } catch (error, stackTrace) {
      await _errorReporter.reportNonFatal(
        error,
        stackTrace,
        reason: 'overlay_refresh_failed',
        context: _context(
          feature: 'rail_board_use_case',
          event: 'overlay_refresh',
          attemptId: attemptId,
        ),
      );
      return const RailCommunityInsightResult(
        kind: RailCommunityInsightKind.error,
        message:
            'Community estimate is temporarily unavailable. Official schedule remains available.',
      );
    }
  }

  SessionStatusSnapshot? _applyOverlayAge(
    CommunityOverlayResult overlay,
    DateTime now,
  ) {
    final snapshot = overlay.sessionStatusSnapshot;
    if (snapshot == null) {
      return null;
    }
    final ageSeconds = now.difference(overlay.fetchedAt).inSeconds;
    final adjustedFreshness =
        snapshot.freshnessSeconds + (ageSeconds < 0 ? 0 : ageSeconds);
    return SessionStatusSnapshot(
      sessionId: snapshot.sessionId,
      state: snapshot.state,
      delayMinutes: snapshot.delayMinutes,
      delayStatus: snapshot.delayStatus,
      confidence: snapshot.confidence,
      freshnessSeconds: adjustedFreshness,
      lastObservedAt: snapshot.lastObservedAt,
    );
  }

  List<PredictedStopTime> _buildPredictedStopTimes({
    required TrainSession session,
    required SessionStatusSnapshot snapshot,
  }) {
    if (session.stops.isEmpty) {
      return const <PredictedStopTime>[];
    }
    return session.stops
        .map(
          (stop) => PredictedStopTime(
            sessionId: session.sessionId,
            stationId: stop.stationId,
            predictedAt: stop.scheduledAt.add(
              Duration(minutes: snapshot.delayMinutes),
            ),
            referenceStationId: session.stops.first.stationId,
            origin: DataOrigin.inferred,
            confidence: snapshot.confidence,
          ),
        )
        .toList(growable: false);
  }

  RailReportSubmissionResult? _validateSubmission({
    required RailSelection selection,
    required RailServiceSnapshot? nextService,
    required String selectedStationName,
  }) {
    if (selection.direction.trim().isEmpty ||
        selection.boardingStationId.trim().isEmpty ||
        selectedStationName.trim().isEmpty ||
        nextService == null) {
      return _failureResult(
        failureReason: RailReportSubmissionFailureReason.invalidPayload,
        reason: RailReportActionReason.temporarilyUnavailable,
      );
    }
    return null;
  }

  RailReportSubmissionResult _failureResult({
    required RailReportSubmissionFailureReason failureReason,
    required RailReportActionReason reason,
  }) {
    return RailReportSubmissionResult(
      outcome: RailReportSubmissionOutcome.error,
      reason: reason,
      feedbackMessage: _failureMessage(failureReason),
      failureReason: failureReason,
    );
  }

  String _failureMessage(RailReportSubmissionFailureReason failureReason) {
    return switch (failureReason) {
      RailReportSubmissionFailureReason.authNotReady =>
        'Sign in is not ready yet. Please try again shortly.',
      RailReportSubmissionFailureReason.invalidPayload =>
        'Arrival report could not be submitted. Please check the selected station and try again.',
      RailReportSubmissionFailureReason.permissionDenied =>
        'You do not have permission to submit this arrival report.',
      RailReportSubmissionFailureReason.stationCapacityReached =>
        'Arrival reporting is full for this station on this train right now.',
    };
  }

  RailReportSubmissionFailureReason _mapSubmissionFailureReason(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return RailReportSubmissionFailureReason.permissionDenied;
    }
    if (error is StateError ||
        error is ArgumentError ||
        error is FormatException ||
        error is AssertionError) {
      return RailReportSubmissionFailureReason.invalidPayload;
    }
    return RailReportSubmissionFailureReason.invalidPayload;
  }

  Future<void> _reportNonFatal(
    Object error,
    StackTrace stackTrace, {
    required String feature,
    required String event,
    String? attemptId,
    String? sessionId,
    String? stationId,
    String? uid,
  }) async {
    await _errorReporter.reportNonFatal(
      error,
      stackTrace,
      reason: event,
      context: _context(
        feature: feature,
        event: event,
        attemptId: attemptId,
        sessionId: sessionId,
        stationId: stationId,
        uid: uid,
      ),
    );
  }

  ErrorReportContext _context({
    required String feature,
    required String event,
    String? attemptId,
    String? sessionId,
    String? stationId,
    String? uid,
  }) {
    return ErrorReportContext(
      feature: feature,
      event: event,
      attemptId: attemptId,
      sessionId: sessionId,
      stationId: stationId,
      uid: uid,
    );
  }

  Future<bool> _hasSubmittedForSession({
    required String sessionId,
    required String stationId,
    required String deviceId,
    required DateTime now,
  }) async {
    final submissionKey = _buildSubmissionKey(
      sessionId: sessionId,
      stationId: stationId,
      deviceId: deviceId,
    );
    if (_submittedSessionKeys.contains(submissionKey)) {
      return true;
    }
    _pruneRecentReportKeys(now);
    final dedupePrefix = '$sessionId:$stationId:$deviceId:';
    final hasRecent = _recentReportKeys.keys.any(
      (key) => key.startsWith(dedupePrefix),
    );
    if (hasRecent) {
      return true;
    }
    return _arrivalReportLedgerRepository.hasSubmitted(
      sessionId: sessionId,
      stationId: stationId,
      deviceId: deviceId,
      now: now,
    );
  }

  String _buildReportDedupeKey({
    required String sessionId,
    required String stationId,
    required String deviceId,
    required DateTime now,
  }) {
    final bucket =
        now.millisecondsSinceEpoch ~/
        Duration(minutes: reportDedupeBucketMinutes).inMilliseconds;
    return '$sessionId:$stationId:$deviceId:$bucket';
  }

  String _buildSubmissionKey({
    required String sessionId,
    required String stationId,
    required String deviceId,
  }) {
    return '$sessionId:$stationId:$deviceId';
  }

  bool _isDuplicateReport({required String dedupeKey, required DateTime now}) {
    _pruneRecentReportKeys(now);
    return _recentReportKeys.containsKey(dedupeKey);
  }

  void _pruneRecentReportKeys(DateTime now) {
    final cutoff = now.subtract(
      Duration(minutes: reportDedupeRetentionMinutes),
    );
    final expired = _recentReportKeys.entries
        .where((entry) => entry.value.isBefore(cutoff))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final key in expired) {
      _recentReportKeys.remove(key);
    }
  }

  Future<TrainSession?> _findSessionForTrain({
    required String direction,
    required int? trainNo,
    required DateTime now,
  }) async {
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

  SessionStop? _findStopForStation({
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

  SessionLifecycleState _getBoardingWindowState({
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
      routeId: routeId,
      serviceDate: today,
    );
    final tomorrowSessions = await _sessionRepository.fetchSessions(
      routeId: routeId,
      serviceDate: tomorrow,
    );
    final sessions = [...todaySessions, ...tomorrowSessions]
      ..sort((a, b) => a.departureAt.compareTo(b.departureAt));
    return sessions;
  }
}
