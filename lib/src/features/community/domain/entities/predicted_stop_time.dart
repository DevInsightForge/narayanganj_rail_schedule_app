import 'package:equatable/equatable.dart';

import 'data_origin.dart';
import 'report_confidence.dart';

class PredictedStopTime extends Equatable {
  const PredictedStopTime({
    required this.sessionId,
    required this.stationId,
    required this.predictedAt,
    required this.referenceStationId,
    required this.origin,
    required this.confidence,
    this.isPassed = false,
  });

  final String sessionId;
  final String stationId;
  final DateTime predictedAt;
  final String referenceStationId;
  final DataOrigin origin;
  final ReportConfidence confidence;
  final bool isPassed;

  @override
  List<Object> get props => [
    sessionId,
    stationId,
    predictedAt,
    referenceStationId,
    origin,
    confidence,
    isPassed,
  ];
}
