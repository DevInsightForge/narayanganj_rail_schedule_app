part of 'rail_board_use_case.dart';

extension RailBoardUseCaseSessionLookup on RailBoardUseCase {
  Future<TrainSession?> _findSessionForTrain({
    required String direction,
    required int? trainNo,
    required DateTime now,
  }) async {
    if (trainNo == null) {
      return null;
    }

    final sessions = await _fetchRouteSessions(now);
    final candidates = sessions
        .where(
          (session) =>
              session.directionId == direction && session.trainNo == trainNo,
        )
        .toList(growable: false);
    if (candidates.isEmpty) {
      return null;
    }
    for (final session in candidates) {
      if (_sessionLifecycleService.getState(session: session, now: now) ==
          SessionLifecycleState.active) {
        return session;
      }
    }
    for (final session in candidates) {
      if (_sessionLifecycleService.getState(session: session, now: now) ==
          SessionLifecycleState.upcoming) {
        return session;
      }
    }
    return candidates.last;
  }

  SessionStop? _findStopForStation({
    required TrainSession session,
    required String stationId,
  }) {
    for (final stop in session.stops) {
      if (stop.stationId == stationId) {
        return stop;
      }
    }
    return null;
  }

  SessionLifecycleState _getBoardingWindowState({
    required DateTime boardingAt,
    required DateTime now,
  }) {
    return _sessionLifecycleService.getStateForScheduledAt(
      scheduledAt: boardingAt,
      now: now,
    );
  }

  Future<List<TrainSession>> _fetchRouteSessions(DateTime now) async {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final todaySessions = await _sessionRepository.fetchSessions(
      routeId: routeId,
      serviceDate: today,
    );
    final tomorrowSessions = await _sessionRepository.fetchSessions(
      routeId: routeId,
      serviceDate: tomorrow,
    );
    final sessions = [...todaySessions, ...tomorrowSessions]
      ..sort((a, b) => a.departureAt.compareTo(b.departureAt));
    return sessions;
  }
}
