part of 'rail_board_controller.dart';

class RailBoardControllerCommunity {
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
    final mappedStatus = mapInsightKind(result.kind);
    final currentState = readState();
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

  static RailCommunityInsightStatus mapInsightKind(RailCommunityInsightKind kind) {
    return switch (kind) {
      RailCommunityInsightKind.idle => RailCommunityInsightStatus.idle,
      RailCommunityInsightKind.loading => RailCommunityInsightStatus.loading,
      RailCommunityInsightKind.ready => RailCommunityInsightStatus.ready,
      RailCommunityInsightKind.stale => RailCommunityInsightStatus.stale,
      RailCommunityInsightKind.empty => RailCommunityInsightStatus.empty,
      RailCommunityInsightKind.error => RailCommunityInsightStatus.error,
    };
  }
}
