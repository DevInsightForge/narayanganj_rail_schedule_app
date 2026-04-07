import '../entities/community_overlay_result.dart';

abstract class CommunityOverlayRepository {
  Future<CommunityOverlayResult> fetchSessionOverlay({
    required String sessionId,
    required DateTime serviceDate,
    bool forceRefresh = false,
  });
}
