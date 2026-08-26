part of 'rail_board_controller.dart';

class RailBoardControllerLoading {
  static Future<void> loadBoard(
    RailBoardController controller,
    RailBoardStateReader readState,
    RailBoardStateEmitter emit, {
    required bool showLoading,
    bool forceCommunityRefresh = false,
  }) async {
    final attemptId = controller._attemptIdFactory.next();
    if (showLoading) {
      emit(
        readState().copyWith(status: RailBoardStatus.loading, clearError: true),
      );
    }

    try {
      final storedSelection = await controller._selectionRepository.read();
      final selection = controller._boardService.createSelection(
        direction: storedSelection?.direction,
        boardingStationId: storedSelection?.boardingStationId,
        destinationStationId: storedSelection?.destinationStationId,
      );

      await RailBoardControllerLoading.persistAndEmit(
        controller,
        readState,
        emit,
        selection: selection,
        forceCommunityRefresh: forceCommunityRefresh,
      );
    } catch (error, stackTrace) {
      await RailBoardControllerReporting.reportCubitGuard(
        controller,
        error,
        stackTrace,
        event: 'load_board',
        attemptId: attemptId,
      );
      emit(
        readState().copyWith(
          status: RailBoardStatus.failure,
          errorMessage: RailBoardController._fallbackErrorMessage,
        ),
      );
    }
  }

  static Future<void> persistAndEmit(
    RailBoardController controller,
    RailBoardStateReader readState,
    RailBoardStateEmitter emit, {
    required RailSelection selection,
    bool forceCommunityRefresh = false,
  }) async {
    final attemptId = controller._attemptIdFactory.next();
    final previousState = readState();
    final previousDirection = previousState.selection.direction;
    final previousTrainNo = previousState.snapshot.nextService?.trainNo;
    try {
      await controller._selectionRepository.write(selection);
      emit(
        RailBoardControllerLoading.buildState(
          controller,
          selection,
          readState(),
        ),
      );
      await RailBoardControllerReporting.refreshReportAvailability(
        controller,
        readState,
        emit,
        selection: selection,
        attemptId: attemptId,
      );
      if (!controller.communityFeaturesEnabled) {
        return;
      }
      final currentState = readState();
      final nextDirection = currentState.selection.direction;
      final nextTrainNo = currentState.snapshot.nextService?.trainNo;
      final trainContextChanged =
          previousDirection != nextDirection || previousTrainNo != nextTrainNo;
      if (trainContextChanged || forceCommunityRefresh) {
        await RailBoardControllerCommunity.refreshCommunityInsights(
          controller,
          readState,
          emit,
          selection: selection,
          forceRefresh: forceCommunityRefresh,
          attemptId: attemptId,
        );
      }
    } catch (error, stackTrace) {
      await RailBoardControllerReporting.reportCubitGuard(
        controller,
        error,
        stackTrace,
        event: 'persist_and_emit',
        attemptId: attemptId,
      );
      emit(
        readState().copyWith(
          status: RailBoardStatus.failure,
          errorMessage: RailBoardController._fallbackErrorMessage,
        ),
      );
    }
  }

  static RailBoardState buildState(
    RailBoardController controller,
    RailSelection selection,
    RailBoardState state,
  ) {
    return RailBoardState(
      status: RailBoardStatus.ready,
      errorMessage: null,
      view: RailBoardViewState(
        selection: selection,
        directionOptions: controller._boardService.getDirectionOptions(),
        boardingStations: controller._boardService.getBoardingOptions(
          selection.direction,
        ),
        destinationStations: controller._boardService.getDestinationOptions(
          selection.direction,
          selection.boardingStationId,
        ),
        snapshot: controller._boardService
            .getSnapshot(selection: selection, now: controller._nowProvider())
            .copyWith(
              scheduleVersion: controller._boardService.schedule.version.isEmpty
                  ? controller._initialScheduleVersion
                  : controller._boardService.schedule.version,
            ),
      ),
      report: state.report,
      community: state.community.copyWith(
        featuresEnabled: controller.communityFeaturesEnabled,
      ),
    );
  }
}
