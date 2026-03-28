import '../../../community/domain/entities/session_status_snapshot.dart';
import '../../../community/domain/entities/train_session.dart';
import '../../../community/domain/repositories/session_repository.dart';
import '../../../community/domain/services/session_lifecycle_service.dart';

class RailSessionResolver {
  const RailSessionResolver({
    required SessionRepository sessionRepository,
    required SessionLifecycleService sessionLifecycleService,
    required this.routeId,
  }) : _sessionRepository = sessionRepository,
       _sessionLifecycleService = sessionLifecycleService;

  final SessionRepository _sessionRepository;
  final SessionLifecycleService _sessionLifecycleService;
  final String routeId;

  Future<TrainSession?> findSessionForTrain({
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

  SessionStop? findStopForStation({
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

  SessionLifecycleState getBoardingWindowState({
    required DateTime boardingAt,
    required DateTime now,
  }) {
    final eligibilityStart = boardingAt.subtract(
      Duration(minutes: _sessionLifecycleService.preDepartureMinutes),
    );
    final eligibilityEnd = boardingAt.add(
      Duration(minutes: _sessionLifecycleService.postDepartureMinutes),
    );
    if (now.isBefore(eligibilityStart)) {
      return SessionLifecycleState.upcoming;
    }
    if (now.isAfter(eligibilityEnd)) {
      return SessionLifecycleState.expired;
    }
    return SessionLifecycleState.active;
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
