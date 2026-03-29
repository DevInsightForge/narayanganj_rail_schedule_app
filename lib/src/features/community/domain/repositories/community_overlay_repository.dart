import '../entities/community_overlay_result.dart';

abstract class CommunityOverlayRepository {
  Future<CommunityOverlayResult> fetchSessionOverlay({
    required String sessionId,
    bool forceRefresh = false,
  });
}
