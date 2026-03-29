import '../../../community/domain/entities/community_overlay_result.dart';
import '../../../community/domain/entities/session_status_snapshot.dart';
import '../../../community/domain/repositories/community_overlay_repository.dart';
import '../../domain/entities/rail_snapshot.dart';
import '../models/rail_community_insight_result.dart';
import 'rail_session_resolver.dart';

class RailCommunityInsightCoordinator {
  const RailCommunityInsightCoordinator({
    required RailSessionResolver sessionResolver,
    required CommunityOverlayRepository communityOverlayRepository,
    this.staleInsightThresholdSeconds = 10 * 60,
  }) : _sessionResolver = sessionResolver,
       _communityOverlayRepository = communityOverlayRepository;

  final RailSessionResolver _sessionResolver;
  final CommunityOverlayRepository _communityOverlayRepository;
  final int staleInsightThresholdSeconds;

  Future<RailCommunityInsightResult> load({
    required String direction,
    required RailServiceSnapshot? nextService,
    required DateTime now,
    bool forceRefresh = false,
  }) async {
    try {
      final session = await _sessionResolver.findSessionForTrain(
        direction: direction,
        trainNo: nextService?.trainNo,
        now: now,
      );
      if (session == null) {
        return const RailCommunityInsightResult(
          kind: RailCommunityInsightKind.empty,
          message: 'No active train estimate is available right now.',
        );
      }

      final overlay = await _communityOverlayRepository.fetchSessionOverlay(
        sessionId: session.sessionId,
        forceRefresh: forceRefresh,
      );
      final snapshot = _applyOverlayAge(overlay, now);
      if (snapshot == null && overlay.predictedStopTimes.isEmpty) {
        return const RailCommunityInsightResult(
          kind: RailCommunityInsightKind.empty,
          message:
              'No community reports are available for this train session yet.',
        );
      }

      final isStale =
          snapshot != null &&
          snapshot.freshnessSeconds > staleInsightThresholdSeconds;

      return RailCommunityInsightResult(
        kind: isStale
            ? RailCommunityInsightKind.stale
            : RailCommunityInsightKind.ready,
        sessionStatusSnapshot: snapshot,
        predictedStopTimes: overlay.predictedStopTimes,
        message: overlay.fromCache
            ? 'Estimate loaded from local Spark-safe community cache.'
            : 'Estimate synchronized from remote community snapshots.',
      );
    } catch (_) {
      return const RailCommunityInsightResult(
        kind: RailCommunityInsightKind.error,
        message:
            'Community estimate is temporarily unavailable. Official schedule remains available.',
      );
    }
  }

  SessionStatusSnapshot? _applyOverlayAge(
    CommunityOverlayResult overlay,
    DateTime now,
  ) {
    final snapshot = overlay.sessionStatusSnapshot;
    if (snapshot == null) {
      return null;
    }
    final ageSeconds = now.difference(overlay.fetchedAt).inSeconds;
    final adjustedFreshness =
        snapshot.freshnessSeconds + (ageSeconds < 0 ? 0 : ageSeconds);
    return SessionStatusSnapshot(
      sessionId: snapshot.sessionId,
      state: snapshot.state,
      delayMinutes: snapshot.delayMinutes,
      delayStatus: snapshot.delayStatus,
      confidence: snapshot.confidence,
      freshnessSeconds: adjustedFreshness,
      lastObservedAt: snapshot.lastObservedAt,
    );
  }
}
