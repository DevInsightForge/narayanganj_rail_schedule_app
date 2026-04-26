import '../../../domain/entities/community_overlay_result.dart';
import '../../../domain/repositories/community_overlay_cache_repository.dart';
import '../../../domain/repositories/community_overlay_repository.dart';
import '../../../domain/services/service_day_key.dart';

class CachedCommunityOverlayRepository implements CommunityOverlayRepository {
  CachedCommunityOverlayRepository({
    required CommunityOverlayRepository primary,
    required CommunityOverlayCacheRepository cache,
    Duration? cacheTtl,
    DateTime Function()? nowProvider,
  }) : _primary = primary,
       _cache = cache,
       _cacheTtl = cacheTtl ?? const Duration(seconds: 90),
       _nowProvider = nowProvider ?? DateTime.now;

  final CommunityOverlayRepository _primary;
  final CommunityOverlayCacheRepository _cache;
  final Duration _cacheTtl;
  final DateTime Function() _nowProvider;
  final Map<String, Future<CommunityOverlayResult>> _inFlight =
      <String, Future<CommunityOverlayResult>>{};
  final Map<String, DateTime> _lastFailureAt = <String, DateTime>{};
  final Duration _failureBackoff = const Duration(minutes: 2);

  @override
  Future<CommunityOverlayResult> fetchSessionOverlay({
    required String sessionId,
    required DateTime serviceDate,
    bool forceRefresh = false,
  }) async {
    final now = _nowProvider();
    final cached = await _cache.read(
      sessionId: sessionId,
      serviceDate: serviceDate,
    );
    final cacheKey = _key(sessionId, serviceDate);
    final lastFailureAt = _lastFailureAt[cacheKey];
    if (!forceRefresh &&
        cached != null &&
        lastFailureAt != null &&
        now.difference(lastFailureAt) <= _failureBackoff) {
      return cached.copyWith(fromCache: true);
    }
    if (!forceRefresh) {
      if (cached != null && now.difference(cached.fetchedAt) <= _cacheTtl) {
        return cached.copyWith(fromCache: true);
      }
    }

    final existing = _inFlight[cacheKey];
    if (existing != null) {
      return existing;
    }

    final future = _fetchAndCache(
      sessionId: sessionId,
      serviceDate: serviceDate,
      cached: cached,
      forceRefresh: true,
    );
    _inFlight[cacheKey] = future;
    try {
      return await future;
    } catch (_) {
      _lastFailureAt[cacheKey] = _nowProvider();
      if (cached != null) {
        return cached.copyWith(fromCache: true);
      }
      rethrow;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  Future<CommunityOverlayResult> _fetchAndCache({
    required String sessionId,
    required DateTime serviceDate,
    required CommunityOverlayResult? cached,
    required bool forceRefresh,
  }) async {
    final remote = await _primary.fetchSessionOverlay(
      sessionId: sessionId,
      serviceDate: serviceDate,
      forceRefresh: forceRefresh,
    );
    if (_isEmpty(remote)) {
      if (cached != null) {
        return cached.copyWith(fromCache: true);
      }
      return remote.copyWith(fromCache: false);
    }
    final normalized = remote.copyWith(fromCache: false);
    await _cache.write(
      sessionId: sessionId,
      serviceDate: serviceDate,
      overlay: normalized,
    );
    return normalized;
  }

  bool _isEmpty(CommunityOverlayResult overlay) {
    return overlay.sessionStatusSnapshot == null &&
        overlay.predictedStopTimes.isEmpty;
  }

  String _key(String sessionId, DateTime serviceDate) {
    return '$sessionId::${serviceDayKey(serviceDate)}';
  }
}
