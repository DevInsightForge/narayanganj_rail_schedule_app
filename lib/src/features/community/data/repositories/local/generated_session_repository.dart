import '../../../domain/entities/schedule_template.dart';
import '../../../domain/entities/train_session.dart';
import '../../../domain/repositories/session_repository.dart';
import '../../../domain/services/train_session_factory.dart';

class GeneratedSessionRepository implements SessionRepository {
  GeneratedSessionRepository({
    required List<ScheduleTemplate> templates,
    TrainSessionFactory sessionFactory = const TrainSessionFactory(),
  }) : _templates = List<ScheduleTemplate>.unmodifiable(templates),
       _sessionFactory = sessionFactory;

  final List<ScheduleTemplate> _templates;
  final TrainSessionFactory _sessionFactory;

  @override
  Future<List<TrainSession>> fetchSessions({
    required String routeId,
    required DateTime serviceDate,
  }) async {
    final day = DateTime(serviceDate.year, serviceDate.month, serviceDate.day);
    final sessions =
        _templates
            .where((template) => template.routeId == routeId)
            .map(
              (template) =>
                  _sessionFactory.create(template: template, serviceDate: day),
            )
            .toList(growable: false)
          ..sort((a, b) => a.departureAt.compareTo(b.departureAt));
    return sessions;
  }

  @override
  Future<TrainSession?> fetchNextEligibleSession({
    required String routeId,
    required String fromStationId,
    required String toStationId,
    required DateTime now,
  }) async {
    final todaySessions = await fetchSessions(
      routeId: routeId,
      serviceDate: now,
    );
    final tomorrowSessions = await fetchSessions(
      routeId: routeId,
      serviceDate: now.add(const Duration(days: 1)),
    );
    final sessions = [...todaySessions, ...tomorrowSessions]
      ..sort((a, b) => a.departureAt.compareTo(b.departureAt));

    for (final session in sessions) {
      final fromIndex = session.stops.indexWhere(
        (stop) => stop.stationId == fromStationId,
      );
      final toIndex = session.stops.indexWhere(
        (stop) => stop.stationId == toStationId,
      );
      if (fromIndex < 0 || toIndex < 0 || fromIndex >= toIndex) {
        continue;
      }
      if (session.departureAt.isAfter(now) || session.arrivalAt.isAfter(now)) {
        return session;
      }
    }
    return null;
  }
}
