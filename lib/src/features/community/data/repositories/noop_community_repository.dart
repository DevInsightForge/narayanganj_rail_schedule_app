import '../../domain/entities/community_overlay.dart';
import '../../domain/repositories/community_repository.dart';

class NoOpCommunityRepository implements CommunityRepository {
  const NoOpCommunityRepository();

  @override
  Future<CommunityOverlay?> fetchOverlay({
    required String tripId,
    String? serviceDate,
  }) async {
    return null;
  }

  @override
  Future<ArrivalReportResult> submitArrivalReport({
    required String tripId,
    required String stationId,
    int? delayMinutes,
    String? serviceDate,
  }) async {
    return const ArrivalReportResult.error('Community features are disabled');
  }
}
