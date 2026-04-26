import 'rail_community_insight_result.dart';

enum RailReportActionReason {
  noSession,
  beforeWindow,
  afterWindow,
  alreadySubmitted,
  stationCapacityReached,
  temporarilyUnavailable,
  eligible,
  verificationLimitedEligible,
}

enum RailReportSubmissionOutcome { success, error }

enum RailReportSubmissionFailureReason {
  authNotReady,
  invalidPayload,
  permissionDenied,
  stationCapacityReached,
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
    this.communityInsightResult,
  });

  final RailReportSubmissionOutcome outcome;
  final RailReportActionReason reason;
  final String feedbackMessage;
  final RailReportSubmissionFailureReason? failureReason;
  final RailCommunityInsightResult? communityInsightResult;
}
