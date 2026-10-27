import 'package:equatable/equatable.dart';

class PredictedStopTime extends Equatable {
  const PredictedStopTime({
    required this.stationId,
    required this.predictedAt,
    this.isPassed = false,
  });

  final String stationId;
  final DateTime predictedAt;
  final bool isPassed;

  @override
  List<Object> get props => [stationId, predictedAt, isPassed];
}
