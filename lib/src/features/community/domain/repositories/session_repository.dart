import '../entities/train_session.dart';

abstract class SessionRepository {
  Future<List<TrainSession>> fetchSessions({
    required String routeId,
    required DateTime serviceDate,
  });

  Future<TrainSession?> fetchNextEligibleSession({
    required String routeId,
    required String fromStationId,
    required String toStationId,
    required DateTime now,
  });
}
