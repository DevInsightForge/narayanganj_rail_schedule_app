import '../../../domain/entities/train_session.dart';
import '../../../domain/repositories/session_repository.dart';

class ResilientSessionRepository implements SessionRepository {
  ResilientSessionRepository({
    required SessionRepository primary,
    required SessionRepository fallback,
  }) : _primary = primary,
       _fallback = fallback;

  final SessionRepository _primary;
  final SessionRepository _fallback;

  @override
  Future<List<TrainSession>> fetchSessions({
    required String routeId,
    required DateTime serviceDate,
  }) async {
    try {
      final remote = await _primary.fetchSessions(
        routeId: routeId,
        serviceDate: serviceDate,
      );
      final local = await _fallback.fetchSessions(
        routeId: routeId,
        serviceDate: serviceDate,
      );
      return _merge(remote, local);
    } catch (_) {
      return _fallback.fetchSessions(
        routeId: routeId,
        serviceDate: serviceDate,
      );
    }
  }

  @override
  Future<TrainSession?> fetchNextEligibleSession({
    required String routeId,
    required String fromStationId,
    required String toStationId,
    required DateTime now,
  }) async {
    try {
      final primary = await _primary.fetchNextEligibleSession(
        routeId: routeId,
        fromStationId: fromStationId,
        toStationId: toStationId,
        now: now,
      );
      if (primary != null) {
        return primary;
      }
    } catch (_) {}
    return _fallback.fetchNextEligibleSession(
      routeId: routeId,
      fromStationId: fromStationId,
      toStationId: toStationId,
      now: now,
    );
  }

  List<TrainSession> _merge(
    List<TrainSession> remote,
    List<TrainSession> local,
  ) {
    final byId = <String, TrainSession>{
      for (final session in local) session.sessionId: session,
    };
    for (final session in remote) {
      byId[session.sessionId] = session;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.departureAt.compareTo(b.departureAt));
    return merged;
  }
}
