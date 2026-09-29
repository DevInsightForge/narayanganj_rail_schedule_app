import '../entities/community_overlay.dart';

enum ArrivalReportResultStatus {
  accepted,
  cooldown,
  stationCapacityReached,
  error,
}

class ArrivalReportResult {
  const ArrivalReportResult.accepted()
    : status = ArrivalReportResultStatus.accepted,
      retryAfterSeconds = null,
      errorMessage = null;

  const ArrivalReportResult.cooldown({required this.retryAfterSeconds})
    : status = ArrivalReportResultStatus.cooldown,
      errorMessage = null;

  const ArrivalReportResult.stationCapacityReached()
    : status = ArrivalReportResultStatus.stationCapacityReached,
      retryAfterSeconds = null,
      errorMessage = null;

  const ArrivalReportResult.error(this.errorMessage)
    : status = ArrivalReportResultStatus.error,
      retryAfterSeconds = null;

  final ArrivalReportResultStatus status;
  final int? retryAfterSeconds;
  final String? errorMessage;
}

abstract class CommunityRepository {
  Future<CommunityOverlay?> fetchOverlay({
    required String tripId,
    required String stationId,
  });

  Future<ArrivalReportResult> submitArrivalReport({
    required String tripId,
    required String stationId,
  });
}
