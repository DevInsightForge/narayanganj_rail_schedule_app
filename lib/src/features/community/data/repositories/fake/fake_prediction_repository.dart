import '../../../domain/entities/predicted_stop_time.dart';
import '../../../domain/repositories/prediction_repository.dart';

class FakePredictionRepository implements PredictionRepository {
  FakePredictionRepository({
    Map<String, List<PredictedStopTime>> seed = const {},
  }) : _predictionsBySession = seed.map(
         (key, value) => MapEntry(key, List<PredictedStopTime>.from(value)),
       );

  final Map<String, List<PredictedStopTime>> _predictionsBySession;

  @override
  Future<List<PredictedStopTime>> fetchPredictions({
    required String sessionId,
  }) async {
    final values = _predictionsBySession[sessionId];
    if (values == null) {
      return const [];
    }
    return List<PredictedStopTime>.from(values);
  }
}
