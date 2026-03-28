import '../entities/arrival_report.dart';
import '../entities/delay_status.dart';
import '../entities/session_status_snapshot.dart';
import '../entities/train_session.dart';
import 'delay_classifier_service.dart';
import 'report_confidence_service.dart';

class SessionStatusAggregationService {
  const SessionStatusAggregationService({
    required DelayClassifierService delayClassifierService,
    required ReportConfidenceService confidenceService,
  }) : _delayClassifierService = delayClassifierService,
       _confidenceService = confidenceService;

  final DelayClassifierService _delayClassifierService;
  final ReportConfidenceService _confidenceService;

  StationObservationConsensus buildStationConsensus({
    required TrainSession session,
    required String stationId,
    required List<ArrivalReport> reports,
    required DateTime now,
  }) {
    final filtered = reports
        .where(
          (report) =>
              report.sessionId == session.sessionId &&
              report.stationId == stationId,
        )
        .toList();
    if (filtered.isEmpty) {
      return StationObservationConsensus(
        sessionId: session.sessionId,
        stationId: stationId,
        observedArrivalAt: null,
        primaryReports: const [],
        conflictingReports: const [],
        confidence: _confidenceService.evaluate(reports: const [], now: now),
      );
    }

    filtered.sort((a, b) => a.observedArrivalAt.compareTo(b.observedArrivalAt));
    final median = filtered[filtered.length ~/ 2].observedArrivalAt;
    final primaryReports = <ArrivalReport>[];
    final conflictingReports = <ArrivalReport>[];
    for (final report in filtered) {
      final delta = report.observedArrivalAt.difference(median).inMinutes.abs();
      if (delta <= _confidenceService.agreementToleranceMinutes) {
        primaryReports.add(report);
      } else {
        conflictingReports.add(report);
      }
    }

    return StationObservationConsensus(
      sessionId: session.sessionId,
      stationId: stationId,
      observedArrivalAt: median,
      primaryReports: primaryReports,
      conflictingReports: conflictingReports,
      confidence: _confidenceService.evaluate(
        reports: primaryReports,
        now: now,
      ),
    );
  }

  SessionStatusSnapshot buildSessionStatus({
    required TrainSession session,
    required SessionLifecycleState state,
    required String stationId,
    required List<ArrivalReport> reports,
    required DateTime now,
  }) {
    final consensus = buildStationConsensus(
      session: session,
      stationId: stationId,
      reports: reports,
      now: now,
    );
    final scheduledStop = session.stops.firstWhere(
      (stop) => stop.stationId == stationId,
      orElse: () => session.stops.first,
    );
    final observedAt = consensus.observedArrivalAt;
    final delayMinutes = observedAt == null
        ? 0
        : _delayClassifierService.delayMinutes(
            scheduledAt: scheduledStop.scheduledAt,
            observedAt: observedAt,
          );
    final delayStatus = observedAt == null
        ? DelayStatus.onTime
        : _delayClassifierService.classify(
            scheduledAt: scheduledStop.scheduledAt,
            observedAt: observedAt,
          );
    final freshnessSeconds = observedAt == null
        ? 0
        : now.difference(observedAt).inSeconds.clamp(0, 31536000);

    return SessionStatusSnapshot(
      sessionId: session.sessionId,
      state: state,
      delayMinutes: delayMinutes,
      delayStatus: delayStatus,
      confidence: consensus.confidence,
      freshnessSeconds: freshnessSeconds,
      lastObservedAt: observedAt,
    );
  }
}
