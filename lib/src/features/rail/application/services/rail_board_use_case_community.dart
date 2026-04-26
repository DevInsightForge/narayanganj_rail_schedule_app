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
          message: 'No matching train is active right now.',
        );
      }

      final overlay = await _communityOverlayRepository.fetchSessionOverlay(
        sessionId: session.sessionId,
        serviceDate: session.serviceDate,
        forceRefresh: forceRefresh,
      );
      final insight = _buildCommunityInsightFromOverlay(
        session: session,
        overlay: overlay,
        now: now,
      );
      if (insight.kind == RailCommunityInsightKind.empty) {
        return const RailCommunityInsightResult(
          kind: RailCommunityInsightKind.empty,
          message: 'No rider updates are available for this train yet.',
        );
      }
      return insight;
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
            'Live rider updates are temporarily unavailable. The timetable is still available.',
      );
    }
  }

  RailCommunityInsightResult _buildCommunityInsightFromOverlay({
    required TrainSession session,
    required CommunityOverlayResult overlay,
    required DateTime now,
  }) {
    final snapshot = _applyOverlayAge(overlay, now);
    if (snapshot == null && overlay.predictedStopTimes.isEmpty) {
      return const RailCommunityInsightResult(kind: RailCommunityInsightKind.empty);
    }
    if (snapshot == null) {
      return RailCommunityInsightResult(
        kind: RailCommunityInsightKind.ready,
        predictedStopTimes: overlay.predictedStopTimes,
      );
    }

    final freshness = snapshot.freshnessState;
    final kind = switch (freshness) {
      CommunityOverlayFreshness.fresh => RailCommunityInsightKind.ready,
      CommunityOverlayFreshness.staleButUsable =>
        RailCommunityInsightKind.stale,
      CommunityOverlayFreshness.expired => RailCommunityInsightKind.expired,
    };
    if (kind == RailCommunityInsightKind.expired) {
      return const RailCommunityInsightResult(
        kind: RailCommunityInsightKind.expired,
        message:
            'Live rider updates are a bit old right now. Showing timetable-only guidance until new updates arrive.',
      );
    }
    return RailCommunityInsightResult(
      kind: kind,
      sessionStatusSnapshot: snapshot,
      predictedStopTimes: _buildPredictedStopTimes(session: session, snapshot: snapshot),
    );
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
