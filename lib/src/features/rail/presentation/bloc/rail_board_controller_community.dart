part of 'rail_board_controller.dart';

class RailBoardControllerCommunity {
  static void ageCommunitySnapshot(
    RailBoardStateReader readState,
    RailBoardStateEmitter emit, {
    required int elapsedSeconds,
  }) {
    if (elapsedSeconds <= 0) {
      return;
    }
    final currentState = readState();
    final snapshot = currentState.community.sessionStatusSnapshot;
    if (snapshot == null) {
      return;
    }
    final agedSnapshot = snapshot.copyWith(
      freshnessSeconds: snapshot.freshnessSeconds + elapsedSeconds,
    );
    final freshnessState = agedSnapshot.freshnessState;
    final mappedStatus = mapInsightKind(
      freshnessState == CommunityOverlayFreshness.fresh
          ? RailCommunityInsightKind.ready
          : freshnessState == CommunityOverlayFreshness.staleButUsable
          ? RailCommunityInsightKind.stale
          : RailCommunityInsightKind.expired,
    );
    emit(
      currentState.copyWith(
        community: currentState.community.copyWith(
          insightStatus: mappedStatus,
          lastResolvedInsightStatus: mappedStatus,
          sessionStatusSnapshot: freshnessState == CommunityOverlayFreshness.expired
              ? null
              : agedSnapshot,
          predictedStopTimes: freshnessState == CommunityOverlayFreshness.expired
              ? const <PredictedStopTime>[]
              : currentState.community.predictedStopTimes,
          message: freshnessState == CommunityOverlayFreshness.expired
              ? 'Live rider updates are a bit old right now. Showing timetable-only guidance until new updates arrive.'
              : currentState.community.message,
          clearSessionStatus: freshnessState == CommunityOverlayFreshness.expired,
          clearMessage: false,
        ),
      ),
    );
  }

  static void applyCommunityInsightResult(
    RailBoardStateReader readState,
    RailBoardStateEmitter emit,
    RailCommunityInsightResult result,
  ) {
    final currentState = readState();
    final mappedStatus = mapInsightKind(result.kind);
    emit(
      currentState.copyWith(
        community: currentState.community.copyWith(
          insightStatus: mappedStatus,
          lastResolvedInsightStatus: mappedStatus,
          sessionStatusSnapshot: result.sessionStatusSnapshot,
          clearSessionStatus: result.sessionStatusSnapshot == null,
          predictedStopTimes: result.predictedStopTimes,
          message: result.message,
          clearMessage: result.message == null,
        ),
      ),
    );
  }

  static Future<void> refreshCommunityInsights(
    RailBoardController controller,
    RailBoardStateReader readState,
    RailBoardStateEmitter emit, {
    required RailSelection selection,
    bool forceRefresh = false,
    String? attemptId,
  }) async {
    emit(
      readState().copyWith(
        community: readState().community.copyWith(
          insightStatus: RailCommunityInsightStatus.loading,
        ),
      ),
    );

    final result = await controller._useCase.loadCommunityInsights(
      direction: selection.direction,
      nextService: readState().snapshot.nextService,
      now: controller._nowProvider(),
      forceRefresh: forceRefresh,
      attemptId: attemptId ?? controller._attemptIdFactory.next(),
    );
    applyCommunityInsightResult(readState, emit, result);
  }

  static RailCommunityInsightStatus mapInsightKind(
    RailCommunityInsightKind kind,
  ) {
    return switch (kind) {
      RailCommunityInsightKind.idle => RailCommunityInsightStatus.idle,
      RailCommunityInsightKind.loading => RailCommunityInsightStatus.loading,
      RailCommunityInsightKind.ready => RailCommunityInsightStatus.ready,
      RailCommunityInsightKind.stale => RailCommunityInsightStatus.stale,
      RailCommunityInsightKind.expired => RailCommunityInsightStatus.expired,
      RailCommunityInsightKind.empty => RailCommunityInsightStatus.empty,
      RailCommunityInsightKind.error => RailCommunityInsightStatus.error,
    };
  }
}
