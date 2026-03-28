import 'package:equatable/equatable.dart';

import 'arrival_report.dart';
import 'delay_status.dart';
import 'report_confidence.dart';

enum SessionLifecycleState { upcoming, active, expired }

class StationObservationConsensus extends Equatable {
  const StationObservationConsensus({
    required this.sessionId,
    required this.stationId,
    required this.observedArrivalAt,
    required this.primaryReports,
    required this.conflictingReports,
    required this.confidence,
  });

  final String sessionId;
  final String stationId;
  final DateTime? observedArrivalAt;
  final List<ArrivalReport> primaryReports;
  final List<ArrivalReport> conflictingReports;
  final ReportConfidence confidence;

  @override
  List<Object?> get props => [
    sessionId,
    stationId,
    observedArrivalAt,
    primaryReports,
    conflictingReports,
    confidence,
  ];
}

class SessionStatusSnapshot extends Equatable {
  const SessionStatusSnapshot({
    required this.sessionId,
    required this.state,
    required this.delayMinutes,
    required this.delayStatus,
    required this.confidence,
    required this.freshnessSeconds,
    required this.lastObservedAt,
  });

  final String sessionId;
  final SessionLifecycleState state;
  final int delayMinutes;
  final DelayStatus delayStatus;
  final ReportConfidence confidence;
  final int freshnessSeconds;
  final DateTime? lastObservedAt;

  @override
  List<Object?> get props => [
    sessionId,
    state,
    delayMinutes,
    delayStatus,
    confidence,
    freshnessSeconds,
    lastObservedAt,
  ];
}
