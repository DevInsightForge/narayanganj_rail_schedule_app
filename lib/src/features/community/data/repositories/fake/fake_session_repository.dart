import '../../../domain/entities/train_session.dart';
import '../../../domain/repositories/session_repository.dart';

class FakeSessionRepository implements SessionRepository {
  FakeSessionRepository({List<TrainSession> seed = const []})
    : _sessions = List<TrainSession>.from(seed);

  final List<TrainSession> _sessions;

  @override
  Future<List<TrainSession>> fetchSessions({
    required String routeId,
    required DateTime serviceDate,
  }) async {
    final targetDay = DateTime(
      serviceDate.year,
      serviceDate.month,
      serviceDate.day,
    );
    return _sessions
        .where((session) {
          final day = DateTime(
            session.serviceDate.year,
            session.serviceDate.month,
            session.serviceDate.day,
          );
          return session.routeId == routeId && day == targetDay;
        })
        .toList(growable: false);
  }

  @override
  Future<TrainSession?> fetchNextEligibleSession({
    required String routeId,
    required String fromStationId,
    required String toStationId,
    required DateTime now,
  }) async {
    final candidates = _sessions.where((session) {
      if (session.routeId != routeId) {
        return false;
      }
      final fromIndex = session.stops.indexWhere(
        (stop) => stop.stationId == fromStationId,
      );
      final toIndex = session.stops.indexWhere(
        (stop) => stop.stationId == toStationId,
      );
      if (fromIndex < 0 || toIndex < 0 || fromIndex >= toIndex) {
        return false;
      }
      return session.departureAt.isAfter(now) || session.arrivalAt.isAfter(now);
    }).toList()..sort((a, b) => a.departureAt.compareTo(b.departureAt));

    return candidates.isEmpty ? null : candidates.first;
  }
}
