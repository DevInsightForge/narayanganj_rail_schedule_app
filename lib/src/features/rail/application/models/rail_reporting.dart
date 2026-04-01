enum RailReportActionReason {
  noSession,
  beforeWindow,
  afterWindow,
  alreadySubmitted,
  temporarilyUnavailable,
  eligible,
  verificationLimitedEligible,
}

enum RailReportSubmissionOutcome { success, error }

enum RailReportSubmissionFailureReason {
  authNotReady,
  invalidPayload,
  permissionDenied,
}

enum RailReportVisibility { hidden, visible }

class RailReportAvailabilityResult {
  const RailReportAvailabilityResult({required this.reason});

  final RailReportActionReason reason;
}

class RailReportSubmissionResult {
  const RailReportSubmissionResult({
    required this.outcome,
    required this.reason,
    required this.feedbackMessage,
    this.failureReason,
  });

  final RailReportSubmissionOutcome outcome;
  final RailReportActionReason reason;
  final String feedbackMessage;
  final RailReportSubmissionFailureReason? failureReason;
}
