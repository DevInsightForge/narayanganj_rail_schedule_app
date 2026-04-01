import '../../../domain/entities/community_overlay_result.dart';
import '../../../domain/repositories/community_overlay_cache_repository.dart';
import '../../../domain/repositories/community_overlay_repository.dart';

class CachedCommunityOverlayRepository implements CommunityOverlayRepository {
  CachedCommunityOverlayRepository({
    required CommunityOverlayRepository primary,
    required CommunityOverlayCacheRepository cache,
    Duration? cacheTtl,
    DateTime Function()? nowProvider,
  }) : _primary = primary,
       _cache = cache,
       _cacheTtl = cacheTtl ?? const Duration(minutes: 5),
       _nowProvider = nowProvider ?? DateTime.now;

  final CommunityOverlayRepository _primary;
  final CommunityOverlayCacheRepository _cache;
  final Duration _cacheTtl;
  final DateTime Function() _nowProvider;
  final Map<String, Future<CommunityOverlayResult>> _inFlight =
      <String, Future<CommunityOverlayResult>>{};

  @override
  Future<CommunityOverlayResult> fetchSessionOverlay({
    required String sessionId,
    bool forceRefresh = false,
  }) async {
    final now = _nowProvider();
    final cached = await _cache.read(sessionId: sessionId);
    if (!forceRefresh) {
      if (cached != null && now.difference(cached.fetchedAt) <= _cacheTtl) {
        return cached.copyWith(fromCache: true);
      }
    }

    final existing = _inFlight[sessionId];
    if (existing != null) {
      return existing;
    }

    final future = _fetchAndCache(
      sessionId: sessionId,
      cached: cached,
      forceRefresh: true,
    );
    _inFlight[sessionId] = future;
    try {
      return await future;
    } catch (_) {
      if (cached != null) {
        return cached.copyWith(fromCache: true);
      }
      rethrow;
    } finally {
      _inFlight.remove(sessionId);
    }
  }

  Future<CommunityOverlayResult> _fetchAndCache({
    required String sessionId,
    required CommunityOverlayResult? cached,
    required bool forceRefresh,
  }) async {
    final remote = await _primary.fetchSessionOverlay(
      sessionId: sessionId,
      forceRefresh: forceRefresh,
    );
    if (_isEmpty(remote)) {
      if (cached != null) {
        return cached.copyWith(fromCache: true);
      }
      return remote.copyWith(fromCache: false);
    }
    final normalized = remote.copyWith(fromCache: false);
    await _cache.write(sessionId: sessionId, overlay: normalized);
    return normalized;
  }

  bool _isEmpty(CommunityOverlayResult overlay) {
    return overlay.sessionStatusSnapshot == null &&
        overlay.predictedStopTimes.isEmpty;
  }
}
