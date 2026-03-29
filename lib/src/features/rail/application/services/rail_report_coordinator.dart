import '../../../community/domain/entities/arrival_report.dart';
import '../../../community/domain/entities/device_identity.dart';
import '../../../community/domain/entities/session_status_snapshot.dart';
import '../../../community/domain/repositories/arrival_report_ledger_repository.dart';
import '../../../community/domain/repositories/arrival_report_repository.dart';
import '../../../community/domain/repositories/device_identity_repository.dart';
import '../../../community/domain/repositories/rate_limit_policy_repository.dart';
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
    this.rateLimitKey = 'arrival_report',
    this.reportDedupeBucketMinutes = 2,
    this.reportDedupeRetentionMinutes = 10,
  }) : _sessionResolver = sessionResolver,
       _arrivalReportRepository = arrivalReportRepository,
       _arrivalReportLedgerRepository = arrivalReportLedgerRepository,
       _deviceIdentityRepository = deviceIdentityRepository,
       _rateLimitPolicyRepository = rateLimitPolicyRepository;

  final RailSessionResolver _sessionResolver;
  final ArrivalReportRepository _arrivalReportRepository;
  final ArrivalReportLedgerRepository _arrivalReportLedgerRepository;
  final DeviceIdentityRepository _deviceIdentityRepository;
  final RateLimitPolicyRepository _rateLimitPolicyRepository;
  final String rateLimitKey;
  final int reportDedupeBucketMinutes;
  final int reportDedupeRetentionMinutes;
  final Map<String, DateTime> _recentReportKeys = {};
  final Set<String> _inFlightSubmissionKeys = <String>{};

  Future<RailReportAvailabilityResult> resolveAvailability({
    required RailSelection selection,
    required RailServiceSnapshot? nextService,
    required DateTime now,
  }) async {
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

    DeviceIdentity identity;
    try {
      identity = await _deviceIdentityRepository.readOrCreateIdentity();
    } catch (_) {
      return const RailReportAvailabilityResult(
        reason: RailReportActionReason.temporarilyUnavailable,
      );
    }

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
    } catch (_) {
      return const RailReportAvailabilityResult(
        reason: RailReportActionReason.verificationLimitedEligible,
      );
    }

    return const RailReportAvailabilityResult(
      reason: RailReportActionReason.eligible,
    );
  }

  Future<RailReportSubmissionResult> submit({
    required RailSelection selection,
    required RailServiceSnapshot? nextService,
    required String selectedStationName,
    required DateTime now,
  }) async {
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

    DeviceIdentity identity;
    try {
      identity = await _deviceIdentityRepository.readOrCreateIdentity();
    } catch (_) {
      return const RailReportSubmissionResult(
        outcome: RailReportSubmissionOutcome.error,
        reason: RailReportActionReason.temporarilyUnavailable,
        feedbackMessage: 'Could not prepare your arrival report right now.',
      );
    }

    await _deviceIdentityRepository.touchIdentity(now);
    final rateLimitDecision = await _rateLimitPolicyRepository.checkAllowance(
      key: rateLimitKey,
      now: now,
    );
    if (!rateLimitDecision.allowed) {
      return RailReportSubmissionResult(
        outcome: RailReportSubmissionOutcome.rateLimited,
        reason: RailReportActionReason.temporarilyUnavailable,
        retryAfterSeconds: rateLimitDecision.retryAfterSeconds,
        feedbackMessage:
            'Please wait ${rateLimitDecision.retryAfterSeconds}s before reporting again.',
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
    final alreadySubmitted = await _arrivalReportLedgerRepository.hasSubmitted(
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
      await _arrivalReportRepository.submitArrivalReport(report);
      await _arrivalReportLedgerRepository.markSubmitted(
        sessionId: session.sessionId,
        stationId: selection.boardingStationId,
        deviceId: identity.deviceId,
        submittedAt: now,
      );
      await _rateLimitPolicyRepository.recordEvent(key: rateLimitKey, now: now);
      _recentReportKeys[dedupeKey] = now;
      return RailReportSubmissionResult(
        outcome: RailReportSubmissionOutcome.success,
        reason: RailReportActionReason.alreadySubmitted,
        feedbackMessage:
            'Arrival reported for $selectedStationName. Thank you.',
      );
    } catch (_) {
      return const RailReportSubmissionResult(
        outcome: RailReportSubmissionOutcome.error,
        reason: RailReportActionReason.temporarilyUnavailable,
        feedbackMessage:
            'Arrival report could not be submitted. Please try again.',
      );
    } finally {
      _inFlightSubmissionKeys.remove(submissionKey);
    }
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
