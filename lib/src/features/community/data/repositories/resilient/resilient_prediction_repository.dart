import '../../../domain/entities/predicted_stop_time.dart';
import '../../../domain/repositories/prediction_repository.dart';

class ResilientPredictionRepository implements PredictionRepository {
  ResilientPredictionRepository({
    required PredictionRepository primary,
    required PredictionRepository fallback,
  }) : _primary = primary,
       _fallback = fallback;

  final PredictionRepository _primary;
  final PredictionRepository _fallback;

  @override
  Future<List<PredictedStopTime>> fetchPredictions({
    required String sessionId,
  }) async {
    try {
      final remote = await _primary.fetchPredictions(sessionId: sessionId);
      if (remote.isNotEmpty) {
        return remote;
      }
    } catch (_) {}
    return _fallback.fetchPredictions(sessionId: sessionId);
  }
}
