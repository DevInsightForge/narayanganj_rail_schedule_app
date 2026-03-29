import '../../../domain/entities/community_overlay_result.dart';
import '../../../domain/repositories/community_overlay_repository.dart';

class FakeCommunityOverlayRepository implements CommunityOverlayRepository {
  FakeCommunityOverlayRepository({
    Map<String, CommunityOverlayResult> seed = const {},
  }) : _overlays = Map<String, CommunityOverlayResult>.from(seed);

  final Map<String, CommunityOverlayResult> _overlays;
  final Map<String, int> fetchCounts = <String, int>{};
  bool failFetch = false;

  @override
  Future<CommunityOverlayResult> fetchSessionOverlay({
    required String sessionId,
    bool forceRefresh = false,
  }) async {
    if (failFetch) {
      throw StateError('overlay_fetch_failed');
    }
    fetchCounts.update(sessionId, (count) => count + 1, ifAbsent: () => 1);
    return _overlays[sessionId] ??
        CommunityOverlayResult(
          fetchedAt: DateTime(1970),
          fromCache: false,
        );
  }
}
