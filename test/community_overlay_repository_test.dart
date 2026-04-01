import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/cached/cached_community_overlay_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/community_overlay_result.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/data_origin.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/delay_status.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/predicted_stop_time.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/report_confidence.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/session_status_snapshot.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/community_overlay_cache_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/community_overlay_repository.dart';

void main() {
  test('returns cached overlay without remote fetch inside cooldown', () async {
    final remote = _FakeOverlayRemoteRepository();
    final cache = _InMemoryOverlayCacheRepository();
    DateTime now = DateTime(2026, 3, 30, 9, 0);
    final repository = CachedCommunityOverlayRepository(
      primary: remote,
      cache: cache,
      nowProvider: () => now,
    );

    final first = await repository.fetchSessionOverlay(sessionId: 's1');
    final second = await repository.fetchSessionOverlay(sessionId: 's1');

    expect(remote.fetchCount, equals(1));
    expect(first.fromCache, isFalse);
    expect(second.fromCache, isTrue);
  });

  test('refreshes after cache expiry', () async {
    final remote = _FakeOverlayRemoteRepository();
    final cache = _InMemoryOverlayCacheRepository();
    DateTime now = DateTime(2026, 3, 30, 9, 0);
    final repository = CachedCommunityOverlayRepository(
      primary: remote,
      cache: cache,
      nowProvider: () => now,
    );

    await repository.fetchSessionOverlay(sessionId: 's1');
    now = now.add(const Duration(minutes: 6));
    await repository.fetchSessionOverlay(sessionId: 's1');

    expect(remote.fetchCount, equals(2));
  });

  test('forces refresh after explicit bypass', () async {
    final remote = _FakeOverlayRemoteRepository();
    final cache = _InMemoryOverlayCacheRepository();
    final repository = CachedCommunityOverlayRepository(
      primary: remote,
      cache: cache,
      nowProvider: () => DateTime(2026, 3, 30, 9, 0),
    );

    await repository.fetchSessionOverlay(sessionId: 's1');
    await repository.fetchSessionOverlay(sessionId: 's1', forceRefresh: true);

    expect(remote.fetchCount, equals(2));
  });

  test('falls back to the last cached overlay when refresh fails', () async {
    final remote = _FakeOverlayRemoteRepository();
    final cache = _InMemoryOverlayCacheRepository();
    DateTime now = DateTime(2026, 3, 30, 9, 0);
    final repository = CachedCommunityOverlayRepository(
      primary: remote,
      cache: cache,
      nowProvider: () => now,
    );

    await repository.fetchSessionOverlay(sessionId: 's1');
    remote.shouldThrow = true;
    now = now.add(const Duration(minutes: 6));

    final overlay = await repository.fetchSessionOverlay(sessionId: 's1');

    expect(remote.fetchCount, equals(2));
    expect(overlay.fromCache, isTrue);
    expect(overlay.sessionStatusSnapshot, isNotNull);
  });

  test('returns cached overlay when remote aggregate is missing', () async {
    final remote = _FakeOverlayRemoteRepository();
    final cache = _InMemoryOverlayCacheRepository();
    DateTime now = DateTime(2026, 3, 30, 9, 0);
    final repository = CachedCommunityOverlayRepository(
      primary: remote,
      cache: cache,
      nowProvider: () => now,
    );

    await repository.fetchSessionOverlay(sessionId: 's1');
    remote.nextResult = CommunityOverlayResult(
      fetchedAt: DateTime(2026, 3, 30, 9, 6),
      fromCache: false,
    );
    now = now.add(const Duration(minutes: 6));

    final overlay = await repository.fetchSessionOverlay(sessionId: 's1');

    expect(overlay.fromCache, isTrue);
    expect(overlay.sessionStatusSnapshot, isNotNull);
  });

  test('returns empty only when no cached overlay exists', () async {
    final remote = _FakeOverlayRemoteRepository(
      nextResult: CommunityOverlayResult(
        fetchedAt: DateTime(2026, 3, 30, 9, 0),
        fromCache: false,
      ),
    );
    final cache = _InMemoryOverlayCacheRepository();
    final repository = CachedCommunityOverlayRepository(
      primary: remote,
      cache: cache,
      nowProvider: () => DateTime(2026, 3, 30, 9, 0),
    );

    final overlay = await repository.fetchSessionOverlay(sessionId: 's1');

    expect(overlay.fromCache, isFalse);
    expect(overlay.sessionStatusSnapshot, isNull);
    expect(overlay.predictedStopTimes, isEmpty);
  });
}

class _FakeOverlayRemoteRepository implements CommunityOverlayRepository {
  _FakeOverlayRemoteRepository({this.nextResult});

  int fetchCount = 0;
  bool shouldThrow = false;
  CommunityOverlayResult? nextResult;

  @override
  Future<CommunityOverlayResult> fetchSessionOverlay({
    required String sessionId,
    bool forceRefresh = false,
  }) async {
    fetchCount += 1;
    if (shouldThrow) {
      throw StateError('offline');
    }
    final result = nextResult;
    if (result != null) {
      return result;
    }
    return CommunityOverlayResult(
      sessionStatusSnapshot: SessionStatusSnapshot(
        sessionId: sessionId,
        state: SessionLifecycleState.active,
        delayMinutes: 3,
        delayStatus: DelayStatus.late,
        confidence: const ReportConfidence(
          score: 0.9,
          sampleSize: 3,
          freshnessSeconds: 15,
          agreementScore: 0.9,
        ),
        freshnessSeconds: 15,
        lastObservedAt: DateTime(2026, 3, 30, 8, 59),
      ),
      predictedStopTimes: [
        PredictedStopTime(
          sessionId: 's1',
          stationId: 'narayanganj',
          predictedAt: DateTime(2026, 3, 30, 9, 40),
          referenceStationId: 'dhaka',
          origin: DataOrigin.community,
          confidence: const ReportConfidence(
            score: 0.8,
            sampleSize: 3,
            freshnessSeconds: 15,
            agreementScore: 0.8,
          ),
        ),
      ],
      fetchedAt: DateTime(2026, 3, 30, 9, 0),
      fromCache: false,
    );
  }
}

class _InMemoryOverlayCacheRepository
    implements CommunityOverlayCacheRepository {
  final Map<String, CommunityOverlayResult> _entries =
      <String, CommunityOverlayResult>{};

  @override
  Future<CommunityOverlayResult?> read({required String sessionId}) async {
    return _entries[sessionId];
  }

  @override
  Future<void> write({
    required String sessionId,
    required CommunityOverlayResult overlay,
  }) async {
    _entries[sessionId] = overlay;
  }
}
