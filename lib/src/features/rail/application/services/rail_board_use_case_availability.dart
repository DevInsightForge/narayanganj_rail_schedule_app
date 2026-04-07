part of 'rail_board_use_case.dart';

extension RailBoardUseCaseAvailability on RailBoardUseCase {
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
}
