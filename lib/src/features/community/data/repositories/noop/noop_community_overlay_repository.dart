import '../../../domain/entities/community_overlay_result.dart';
import '../../../domain/repositories/community_overlay_repository.dart';

class NoOpCommunityOverlayRepository implements CommunityOverlayRepository {
  const NoOpCommunityOverlayRepository();

  @override
  Future<CommunityOverlayResult> fetchSessionOverlay({
    required String sessionId,
    required DateTime serviceDate,
    bool forceRefresh = false,
  }) async {
    return CommunityOverlayResult(
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(0),
      fromCache: false,
    );
  }
}
