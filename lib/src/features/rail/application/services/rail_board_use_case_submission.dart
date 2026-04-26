part of 'rail_board_use_case.dart';

extension RailBoardUseCaseSubmission on RailBoardUseCase {
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

      if (!communityDebugBypassEnabled) {
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
        serviceDate: session.serviceDate,
        stationId: selection.boardingStationId,
        deviceId: identity.deviceId,
        now: now,
      );
      final submissionKey = _buildSubmissionKey(
        sessionId: session.sessionId,
        serviceDate: session.serviceDate,
        stationId: selection.boardingStationId,
        deviceId: identity.deviceId,
      );
      var alreadySubmitted = _submittedSessionKeys.contains(submissionKey);
      if (!alreadySubmitted) {
        try {
          alreadySubmitted = await _arrivalReportLedgerRepository.hasSubmitted(
            sessionId: session.sessionId,
            serviceDate: session.serviceDate,
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
        final updatedAggregate = await _arrivalReportRepository.submitArrivalReport(
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
            serviceDate: session.serviceDate,
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
          communityInsightResult: _buildCommunityInsightFromAggregate(
            session: session,
            aggregate: updatedAggregate,
            now: now,
          ),
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

  RailCommunityInsightResult _buildCommunityInsightFromAggregate({
    required TrainSession session,
    required CommunitySessionAggregate aggregate,
    required DateTime now,
  }) {
    final snapshot = SessionStatusSnapshot(
      sessionId: aggregate.sessionId,
      state: SessionLifecycleState.active,
      delayMinutes: aggregate.delayMinutes,
      delayStatus: aggregate.delayStatus,
      confidence: aggregate.confidence,
      freshnessSeconds: aggregate.freshnessSeconds +
          (now.difference(aggregate.updatedAt).inSeconds < 0
              ? 0
              : now.difference(aggregate.updatedAt).inSeconds),
      lastObservedAt: aggregate.lastObservedAt,
    );
    final kind = switch (snapshot.freshnessState) {
      CommunityOverlayFreshness.fresh => RailCommunityInsightKind.ready,
      CommunityOverlayFreshness.staleButUsable =>
        RailCommunityInsightKind.stale,
      CommunityOverlayFreshness.expired => RailCommunityInsightKind.expired,
    };
    if (kind == RailCommunityInsightKind.expired) {
      return const RailCommunityInsightResult(
        kind: RailCommunityInsightKind.expired,
        message:
            'Live rider updates are a bit old right now. Showing timetable-only guidance until new updates arrive.',
      );
    }
    return RailCommunityInsightResult(
      kind: kind,
      sessionStatusSnapshot: snapshot,
      predictedStopTimes: _buildPredictedStopTimes(
        session: session,
        snapshot: snapshot,
      ),
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
    required DateTime serviceDate,
    required String stationId,
    required String deviceId,
    required DateTime now,
  }) async {
    final submissionKey = _buildSubmissionKey(
      sessionId: sessionId,
      serviceDate: serviceDate,
      stationId: stationId,
      deviceId: deviceId,
    );
    if (_submittedSessionKeys.contains(submissionKey)) {
      return true;
    }
    _pruneRecentReportKeys(now);
    final dedupePrefix =
        '$sessionId:${serviceDayKey(serviceDate)}:$stationId:$deviceId:';
    final hasRecent = _recentReportKeys.keys.any(
      (key) => key.startsWith(dedupePrefix),
    );
    if (hasRecent) {
      return true;
    }
    return _arrivalReportLedgerRepository.hasSubmitted(
      sessionId: sessionId,
      serviceDate: serviceDate,
      stationId: stationId,
      deviceId: deviceId,
      now: now,
    );
  }

  String _buildReportDedupeKey({
    required String sessionId,
    required DateTime serviceDate,
    required String stationId,
    required String deviceId,
    required DateTime now,
  }) {
    final bucket =
        now.millisecondsSinceEpoch ~/
        Duration(minutes: reportDedupeBucketMinutes).inMilliseconds;
    return '$sessionId:${serviceDayKey(serviceDate)}:$stationId:$deviceId:$bucket';
  }

  String _buildSubmissionKey({
    required String sessionId,
    required DateTime serviceDate,
    required String stationId,
    required String deviceId,
  }) {
    return '$sessionId:${serviceDayKey(serviceDate)}:$stationId:$deviceId';
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
