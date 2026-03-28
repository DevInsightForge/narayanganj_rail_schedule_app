import '../entities/predicted_stop_time.dart';

abstract class PredictionRepository {
  Future<List<PredictedStopTime>> fetchPredictions({required String sessionId});
}
