import '../entities/community_overlay_result.dart';

abstract class CommunityOverlayCacheRepository {
  Future<CommunityOverlayResult?> read({required String sessionId});

  Future<void> write({
    required String sessionId,
    required CommunityOverlayResult overlay,
  });
}
