import '../entities/community_overlay_result.dart';

abstract class CommunityOverlayCacheRepository {
  Future<CommunityOverlayResult?> read({
    required String sessionId,
    required DateTime serviceDate,
  });

  Future<void> write({
    required String sessionId,
    required DateTime serviceDate,
    required CommunityOverlayResult overlay,
  });
}
