import '../entities/data_origin.dart';
import '../entities/predicted_stop_time.dart';
import '../entities/report_confidence.dart';
import '../entities/train_session.dart';

class DownstreamPredictionService {
  const DownstreamPredictionService({this.maxCarryForwardDelayMinutes = 45});

  final int maxCarryForwardDelayMinutes;

  List<PredictedStopTime> predictFromObservation({
    required TrainSession session,
    required String observedStationId,
    required DateTime observedArrivalAt,
    required ReportConfidence confidence,
  }) {
    final observedIndex = session.stops.indexWhere(
      (stop) => stop.stationId == observedStationId,
    );
    if (observedIndex < 0) {
      return const [];
    }
    final observedStop = session.stops[observedIndex];
    final rawDelay = observedArrivalAt
        .difference(observedStop.scheduledAt)
        .inMinutes;
    final boundedDelay = rawDelay.clamp(
      -maxCarryForwardDelayMinutes,
      maxCarryForwardDelayMinutes,
    );

    return session.stops
        .where((stop) => stop.sequence >= observedStop.sequence)
        .map(
          (stop) => PredictedStopTime(
            sessionId: session.sessionId,
            stationId: stop.stationId,
            predictedAt: stop.scheduledAt.add(Duration(minutes: boundedDelay)),
            referenceStationId: observedStationId,
            origin: DataOrigin.inferred,
            confidence: confidence,
          ),
        )
        .toList(growable: false);
  }
}
