import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../community/domain/entities/arrival_report.dart';
import '../../../community/domain/entities/device_identity.dart';
import '../../../community/domain/entities/session_status_snapshot.dart';
import '../../../community/domain/repositories/arrival_report_ledger_repository.dart';
import '../../../community/domain/repositories/arrival_report_repository.dart';
import '../../../community/domain/repositories/device_identity_repository.dart';
import '../../../community/domain/repositories/rate_limit_policy_repository.dart';
import '../../../../core/errors/error_report_context.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/logging/debug_logger.dart';
import '../../domain/entities/rail_selection.dart';
import '../../domain/entities/rail_snapshot.dart';
import '../models/rail_reporting.dart';
import 'rail_session_resolver.dart';

class RailReportCoordinator {
  RailReportCoordinator({
    required RailSessionResolver sessionResolver,
    required ArrivalReportRepository arrivalReportRepository,
    required ArrivalReportLedgerRepository arrivalReportLedgerRepository,
    required DeviceIdentityRepository deviceIdentityRepository,
    required RateLimitPolicyRepository rateLimitPolicyRepository,
    ErrorReporter? errorReporter,
    DebugLogger? logger,
    this.rateLimitKey = 'arrival_report',
    this.reportDedupeBucketMinutes = 2,
    this.reportDedupeRetentionMinutes = 10,
  }) : _sessionResolver = sessionResolver,
       _arrivalReportRepository = arrivalReportRepository,
       _arrivalReportLedgerRepository = arrivalReportLedgerRepository,
       _deviceIdentityRepository = deviceIdentityRepository,
       _rateLimitPolicyRepository = rateLimitPolicyRepository,
       _errorReporter = errorReporter ?? const NoopErrorReporter(),
       _logger = logger ?? const DebugLogger('RailReportCoordinator');

  final RailSessionResolver _sessionResolver;
  final ArrivalReportRepository _arrivalReportRepository;
  final ArrivalReportLedgerRepository _arrivalReportLedgerRepository;
  final DeviceIdentityRepository _deviceIdentityRepository;
  final RateLimitPolicyRepository _rateLimitPolicyRepository;
  final ErrorReporter _errorReporter;
  final DebugLogger _logger;
  final String rateLimitKey;
  final int reportDedupeBucketMinutes;
  final int reportDedupeRetentionMinutes;
  final Map<String, DateTime> _recentReportKeys = {};
  final Set<String> _inFlightSubmissionKeys = <String>{};

  Future<RailReportAvailabilityResult> resolveAvailability({
    required RailSelection selection,
    required RailServiceSnapshot? nextService,
    required DateTime now,
    String? attemptId,
  }) async {
    _log(
      'availability_start',
      attemptId: attemptId,
      context: _context(
        attemptId: attemptId,
        stationId: selection.boardingStationId,
      ),
    );
    try {
      final session = await _sessionResolver.findSessionForTrain(
        direction: selection.direction,
        trainNo: nextService?.trainNo,
        now: now,
      );
      final boardingStop = session == null
          ? null
          : _sessionResolver.findStopForStation(
              session: session,
              stationId: selection.boardingStationId,
            );
      if (session == null || boardingStop == null || nextService == null) {
        _log(
          'availability_no_session',
          attemptId: attemptId,
          context: _context(
            attemptId: attemptId,
            sessionId: session?.sessionId,
            stationId: selection.boardingStationId,
          ),
        );
        return const RailReportAvailabilityResult(
          reason: RailReportActionReason.noSession,
        );
      }

      final boardingWindowState = _sessionResolver.getBoardingWindowState(
        boardingAt: boardingStop.scheduledAt,
        now: now,
      );
      if (boardingWindowState == SessionLifecycleState.upcoming) {
        return RailReportAvailabilityResult(
          reason: RailReportActionReason.beforeWindow,
          boardingAt: boardingStop.scheduledAt,
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

      _log(
        'availability_success',
        attemptId: attemptId,
        context: _context(
          attemptId: attemptId,
          sessionId: session.sessionId,
          stationId: selection.boardingStationId,
          uid: identity.deviceId,
        ),
      );
      return const RailReportAvailabilityResult(
        reason: RailReportActionReason.eligible,
      );
    } catch (error, stackTrace) {
      await _reportNonFatal(
        error,
        stackTrace,
        event: 'resolve_availability',
        attemptId: attemptId,
        stationId: selection.boardingStationId,
      );
      return const RailReportAvailabilityResult(
        reason: RailReportActionReason.temporarilyUnavailable,
      );
    }
  }

  Future<RailReportSubmissionResult> submit({
    required RailSelection selection,
    required RailServiceSnapshot? nextService,
    required String selectedStationName,
    required DateTime now,
    String? attemptId,
  }) async {
    _log(
      'submit_start',
      attemptId: attemptId,
      context: _context(
        attemptId: attemptId,
        stationId: selection.boardingStationId,
      ),
    );
    final validationFailure = _validateSubmission(
      selection: selection,
      nextService: nextService,
      selectedStationName: selectedStationName,
    );
    if (validationFailure != null) {
      return validationFailure;
    }

    try {
      final session = await _sessionResolver.findSessionForTrain(
        direction: selection.direction,
        trainNo: nextService?.trainNo,
        now: now,
      );
      final boardingStop = session == null
          ? null
          : _sessionResolver.findStopForStation(
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

      final boardingWindowState = _sessionResolver.getBoardingWindowState(
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
        return RailReportSubmissionResult(
          outcome: RailReportSubmissionOutcome.error,
          reason: RailReportActionReason.temporarilyUnavailable,
          feedbackMessage:
              'Sign in is not ready yet. Please try again shortly.',
          failureReason: RailReportSubmissionFailureReason.authNotReady,
        );
      }

      DeviceIdentity identity;
      try {
        identity = await _deviceIdentityRepository.readOrCreateIdentity(
          attemptId: attemptId,
        );
      } catch (error, stackTrace) {
        await _reportNonFatal(
          error,
          stackTrace,
          event: 'read_identity',
          attemptId: attemptId,
          sessionId: session.sessionId,
          stationId: selection.boardingStationId,
        );
        return RailReportSubmissionResult(
          outcome: RailReportSubmissionOutcome.error,
          reason: RailReportActionReason.temporarilyUnavailable,
          feedbackMessage:
              'Sign in is not ready yet. Please try again shortly.',
          failureReason: RailReportSubmissionFailureReason.authNotReady,
        );
      }

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
      final alreadySubmitted = await _arrivalReportLedgerRepository
          .hasSubmitted(
            sessionId: session.sessionId,
            stationId: selection.boardingStationId,
            deviceId: identity.deviceId,
          );
      if (_inFlightSubmissionKeys.contains(submissionKey) ||
          _isDuplicateReport(dedupeKey: dedupeKey, now: now) ||
          alreadySubmitted) {
        return const RailReportSubmissionResult(
          outcome: RailReportSubmissionOutcome.success,
          reason: RailReportActionReason.alreadySubmitted,
          feedbackMessage: 'Arrival report already recorded for this train.',
        );
      }

      try {
        await _deviceIdentityRepository.touchIdentity(
          now,
          attemptId: attemptId,
        );
        final report = ArrivalReport(
          reportId: 'report:${now.microsecondsSinceEpoch}',
          sessionId: session.sessionId,
          stationId: selection.boardingStationId,
          deviceId: identity.deviceId,
          observedArrivalAt: now,
          submittedAt: now,
        );
        _inFlightSubmissionKeys.add(submissionKey);
        await _arrivalReportRepository.submitArrivalReport(report);
        await _arrivalReportLedgerRepository.markSubmitted(
          sessionId: session.sessionId,
          stationId: selection.boardingStationId,
          deviceId: identity.deviceId,
          submittedAt: now,
        );
        await _rateLimitPolicyRepository.recordEvent(
          key: rateLimitKey,
          now: now,
        );
        _recentReportKeys[dedupeKey] = now;
        _log(
          'submit_success',
          attemptId: attemptId,
          context: _context(
            attemptId: attemptId,
            sessionId: session.sessionId,
            stationId: selection.boardingStationId,
            uid: identity.deviceId,
          ),
        );
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
            : RailReportSubmissionFailureReason.invalidPayload;
        await _reportNonFatal(
          error,
          stackTrace,
          event: 'submit_repository',
          attemptId: attemptId,
          sessionId: session.sessionId,
          stationId: selection.boardingStationId,
          uid: identity.deviceId,
        );
        return _failureResult(
          failureReason: failureReason,
          reason: RailReportActionReason.temporarilyUnavailable,
        );
      } catch (error, stackTrace) {
        final failureReason = _mapSubmissionFailureReason(error);
        await _reportNonFatal(
          error,
          stackTrace,
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
    int? retryAfterSeconds,
  }) {
    return RailReportSubmissionResult(
      outcome: RailReportSubmissionOutcome.error,
      reason: reason,
      feedbackMessage: _failureMessage(failureReason),
      retryAfterSeconds: retryAfterSeconds,
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
        attemptId: attemptId,
        sessionId: sessionId,
        stationId: stationId,
        uid: uid,
        event: event,
      ),
    );
  }

  void _log(String message, {String? attemptId, ErrorReportContext? context}) {
    if (!kDebugMode) {
      return;
    }
    _logger.log(
      message,
      context: context?.toMap() ?? <String, Object?>{'attemptId': attemptId},
    );
  }

  ErrorReportContext _context({
    String? attemptId,
    String? sessionId,
    String? stationId,
    String? uid,
    String? event,
  }) {
    return ErrorReportContext(
      feature: 'rail_report_coordinator',
      event: event ?? 'report',
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
}
