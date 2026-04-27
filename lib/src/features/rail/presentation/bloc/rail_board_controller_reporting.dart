part of 'rail_board_controller.dart';

class RailBoardControllerReporting {
  static Future<void> submitArrivalReport(
    RailBoardController controller,
    RailBoardStateReader readState,
    RailBoardStateEmitter emit,
  ) async {
    final currentState = readState();
    if (!controller.communityFeaturesEnabled) {
      return;
    }
    if (currentState.status != RailBoardStatus.ready ||
        currentState.snapshot.nextService == null) {
      return;
    }

    final attemptId = controller._attemptIdFactory.next();
    await refreshReportAvailability(
      controller,
      readState,
      emit,
      selection: currentState.selection,
      attemptId: attemptId,
    );
    final refreshedState = readState();
    if (refreshedState.report.isSubmissionLocked) {
      if (refreshedState.report.visibility == RailReportVisibility.hidden) {
        await reportCubitGuard(
          controller,
          StateError('report_submit_hidden'),
          StackTrace.current,
          event: 'submit_guard_hidden',
          attemptId: attemptId,
        );
        return;
      }
      await reportCubitGuard(
        controller,
        StateError('report_submit_blocked'),
        StackTrace.current,
        event: 'submit_guard_blocked',
        attemptId: attemptId,
      );
      emit(
        refreshedState.copyWith(
          report: refreshedState.report.copyWith(
            status: RailReportSubmissionStatus.error,
            feedbackMessage: blockedReportMessage(
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

    final submission = await controller._useCase.submitReport(
      selection: readState().selection,
      nextService: readState().snapshot.nextService,
      selectedStationName: readState().snapshot.selectedStationName,
      now: controller._nowProvider(),
      attemptId: attemptId,
    );

    final afterSubmissionState = readState();
    emit(
      afterSubmissionState.copyWith(
        report: deriveReportActionState(
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

    if (submission.communityInsightResult != null) {
      RailBoardControllerCommunity.applyCommunityInsightResult(
        readState,
        emit,
        submission.communityInsightResult!,
      );
    }

    if (submission.failureReason ==
        RailReportSubmissionFailureReason.authNotReady) {
      await refreshReportAvailability(
        controller,
        readState,
        emit,
        selection: readState().selection,
        attemptId: attemptId,
      );
    }
  }

  static Future<void> refreshReportAvailability(
    RailBoardController controller,
    RailBoardStateReader readState,
    RailBoardStateEmitter emit, {
    required RailSelection selection,
    DateTime? now,
    String? attemptId,
  }) async {
    final revision = ++controller._reportAvailabilityRevision;
    final resolvedNow = now ?? controller._nowProvider();
    final currentState = readState();
    if (currentState.status != RailBoardStatus.ready ||
        !controller.communityFeaturesEnabled) {
      final nextReport = deriveReportActionState(
        currentState.report,
        authReadiness: const FirebaseAuthReadiness.unknown(),
        reason: RailReportActionReason.noSession,
      );
      if (revision == controller._reportAvailabilityRevision &&
          nextReport != currentState.report) {
        emit(currentState.copyWith(report: nextReport));
      }
      return;
    }

    final resolvingReport = currentState.report.copyWith(
      status: RailReportSubmissionStatus.idle,
      authReadiness: const FirebaseAuthReadiness.resolving(),
      visibility: RailReportVisibility.hidden,
      submitEnabled: false,
      actionReason: RailReportActionReason.noSession,
      hasReportedCurrentSession: false,
    );
    if (revision == controller._reportAvailabilityRevision &&
        resolvingReport != currentState.report) {
      emit(currentState.copyWith(report: resolvingReport));
    }

    final currentAttemptId = attemptId ?? controller._attemptIdFactory.next();
    final authReadiness = await controller._deviceIdentityRepository
        .readAuthReadiness(attemptId: currentAttemptId);
    if (revision != controller._reportAvailabilityRevision) {
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

    final availability = await controller._useCase.resolveReportAvailability(
      selection: selection,
      nextService: readState().snapshot.nextService,
      now: resolvedNow,
      attemptId: currentAttemptId,
    );
    if (revision != controller._reportAvailabilityRevision) {
      return;
    }
    final nextReport = deriveReportActionState(
      readState().report,
      authReadiness: authReadiness,
      reason: controller.communityDebugBypassEnabled
          ? RailReportActionReason.eligible
          : availability.reason,
      forceEnabled: controller.communityDebugBypassEnabled,
    );
    if (revision == controller._reportAvailabilityRevision &&
        nextReport != readState().report) {
      emit(readState().copyWith(report: nextReport));
    }
  }

  static Future<void> reportCubitGuard(
    RailBoardController controller,
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
    await controller._errorReporter.reportNonFatal(
      error,
      stackTrace,
      reason: 'rail_board_$event',
      context: context,
    );
  }

  static RailBoardReportState deriveReportActionState(
    RailBoardReportState base, {
    required FirebaseAuthReadiness authReadiness,
    required RailReportActionReason reason,
    bool forceEnabled = false,
  }) {
    return base.copyWith(
      authReadiness: authReadiness,
      visibility: authReadiness.isReady
          ? RailReportVisibility.visible
          : RailReportVisibility.hidden,
      submitEnabled:
          authReadiness.isReady &&
          (forceEnabled ||
              reason == RailReportActionReason.eligible ||
              reason == RailReportActionReason.verificationLimitedEligible),
      actionReason: reason,
      hasReportedCurrentSession:
          reason == RailReportActionReason.alreadySubmitted,
    );
  }

  static String blockedReportMessage(RailReportActionReason reason) {
    return switch (reason) {
      RailReportActionReason.stationCapacityReached =>
        'Arrival reporting is full for this station on this train right now.',
      _ => 'Reporting is not available for this train yet.',
    };
  }
}
