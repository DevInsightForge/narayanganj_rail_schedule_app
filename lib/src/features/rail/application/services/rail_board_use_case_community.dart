part of 'rail_board_use_case.dart';

extension RailBoardUseCaseCommunity on RailBoardUseCase {
  Future<RailCommunityInsightResult> loadCommunityInsights({
    required String direction,
    required RailServiceSnapshot? nextService,
    required DateTime now,
    bool forceRefresh = false,
    String? attemptId,
  }) async {
    try {
      final session = await _findSessionForTrain(
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
        predictedStopTimes: snapshot == null
            ? overlay.predictedStopTimes
            : _buildPredictedStopTimes(session: session, snapshot: snapshot),
        message: overlay.fromCache
            ? 'Estimate loaded from local community cache.'
            : 'Estimate synchronized from the latest community aggregate.',
      );
    } catch (error, stackTrace) {
      await _errorReporter.reportNonFatal(
        error,
        stackTrace,
        reason: 'overlay_refresh_failed',
        context: _context(
          feature: 'rail_board_use_case',
          event: 'overlay_refresh',
          attemptId: attemptId,
        ),
      );
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

  List<PredictedStopTime> _buildPredictedStopTimes({
    required TrainSession session,
    required SessionStatusSnapshot snapshot,
  }) {
    if (session.stops.isEmpty) {
      return const <PredictedStopTime>[];
    }
    return session.stops
        .map(
          (stop) => PredictedStopTime(
            sessionId: session.sessionId,
            stationId: stop.stationId,
            predictedAt: stop.scheduledAt.add(
              Duration(minutes: snapshot.delayMinutes),
            ),
            referenceStationId: session.stops.first.stationId,
            origin: DataOrigin.inferred,
            confidence: snapshot.confidence,
          ),
        )
        .toList(growable: false);
  }
}
