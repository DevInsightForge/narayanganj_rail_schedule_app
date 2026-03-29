import 'package:flutter_test/flutter_test.dart';
import 'package:narayanganj_rail_schedule/src/features/community/data/repositories/resilient/resilient_prediction_repository.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/data_origin.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/predicted_stop_time.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/entities/report_confidence.dart';
import 'package:narayanganj_rail_schedule/src/features/community/domain/repositories/prediction_repository.dart';

void main() {
  test('resilient prediction repository falls back on failure', () async {
    final fallbackPrediction = PredictedStopTime(
      sessionId: 's1',
      stationId: 'a',
      predictedAt: DateTime(2026, 3, 28, 4, 40),
      referenceStationId: 'a',
      origin: DataOrigin.inferred,
      confidence: const ReportConfidence(
        score: 0.5,
        sampleSize: 1,
        freshnessSeconds: 10,
        agreementScore: 0.5,
      ),
    );
    final repository = ResilientPredictionRepository(
      primary: _ThrowingPredictionRepository(),
      fallback: _InMemoryPredictionRepository([fallbackPrediction]),
    );

    final predictions = await repository.fetchPredictions(sessionId: 's1');

    expect(predictions.length, equals(1));
  });
}

class _ThrowingPredictionRepository implements PredictionRepository {
  @override
  Future<List<PredictedStopTime>> fetchPredictions({
    required String sessionId,
  }) async => throw StateError('fail');
}

class _InMemoryPredictionRepository implements PredictionRepository {
  _InMemoryPredictionRepository(this._predictions);

  final List<PredictedStopTime> _predictions;

  @override
  Future<List<PredictedStopTime>> fetchPredictions({
    required String sessionId,
  }) async => _predictions;
}
