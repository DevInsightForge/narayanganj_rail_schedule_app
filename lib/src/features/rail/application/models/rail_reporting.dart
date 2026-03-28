enum RailReportActionReason {
  noSession,
  beforeWindow,
  afterWindow,
  alreadySubmitted,
  temporarilyUnavailable,
  eligible,
  verificationLimitedEligible,
}

enum RailReportSubmissionOutcome { success, rateLimited, error }

class RailReportAvailabilityResult {
  const RailReportAvailabilityResult({
    required this.reason,
    this.boardingAt,
    this.retryAfterSeconds,
  });

  final RailReportActionReason reason;
  final DateTime? boardingAt;
  final int? retryAfterSeconds;
}

class RailReportSubmissionResult {
  const RailReportSubmissionResult({
    required this.outcome,
    required this.reason,
    required this.feedbackMessage,
    this.retryAfterSeconds,
  });

  final RailReportSubmissionOutcome outcome;
  final RailReportActionReason reason;
  final String feedbackMessage;
  final int? retryAfterSeconds;
}
