import 'package:equatable/equatable.dart';

import 'arrival_report.dart';
import 'delay_status.dart';
import 'report_confidence.dart';

enum SessionLifecycleState { upcoming, active, expired }

enum CommunityOverlayFreshness { fresh, staleButUsable, expired }

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

  SessionStatusSnapshot copyWith({
    String? sessionId,
    SessionLifecycleState? state,
    int? delayMinutes,
    DelayStatus? delayStatus,
    ReportConfidence? confidence,
    int? freshnessSeconds,
    DateTime? lastObservedAt,
  }) {
    return SessionStatusSnapshot(
      sessionId: sessionId ?? this.sessionId,
      state: state ?? this.state,
      delayMinutes: delayMinutes ?? this.delayMinutes,
      delayStatus: delayStatus ?? this.delayStatus,
      confidence: confidence ?? this.confidence,
      freshnessSeconds: freshnessSeconds ?? this.freshnessSeconds,
      lastObservedAt: lastObservedAt ?? this.lastObservedAt,
    );
  }

  CommunityOverlayFreshness get freshnessState {
    if (freshnessSeconds <= 90) {
      return CommunityOverlayFreshness.fresh;
    }
    if (freshnessSeconds <= 300) {
      return CommunityOverlayFreshness.staleButUsable;
    }
    return CommunityOverlayFreshness.expired;
  }

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
