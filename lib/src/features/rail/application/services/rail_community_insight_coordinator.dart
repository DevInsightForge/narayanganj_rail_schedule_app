import '../../../community/domain/entities/arrival_report.dart';
import '../../../community/domain/entities/predicted_stop_time.dart';
import '../../../community/domain/repositories/arrival_report_repository.dart';
import '../../../community/domain/repositories/device_identity_repository.dart';
import '../../../community/domain/repositories/prediction_repository.dart';
import '../../../community/domain/services/delay_classifier_service.dart';
import '../../../community/domain/services/downstream_prediction_service.dart';
import '../../../community/domain/services/report_confidence_service.dart';
import '../../../community/domain/services/session_lifecycle_service.dart';
import '../../../community/domain/services/session_status_aggregation_service.dart';
import '../../domain/entities/rail_snapshot.dart';
import '../models/rail_community_insight_result.dart';
import 'rail_session_resolver.dart';

class RailCommunityInsightCoordinator {
  const RailCommunityInsightCoordinator({
    required RailSessionResolver sessionResolver,
    required ArrivalReportRepository arrivalReportRepository,
    required PredictionRepository predictionRepository,
    required DeviceIdentityRepository deviceIdentityRepository,
    SessionLifecycleService? sessionLifecycleService,
    ReportConfidenceService? reportConfidenceService,
    DownstreamPredictionService? downstreamPredictionService,
    SessionStatusAggregationService? sessionStatusAggregationService,
    this.staleInsightThresholdSeconds = 10 * 60,
  }) : _sessionResolver = sessionResolver,
       _arrivalReportRepository = arrivalReportRepository,
       _predictionRepository = predictionRepository,
       _deviceIdentityRepository = deviceIdentityRepository,
       _sessionLifecycleService =
           sessionLifecycleService ?? const SessionLifecycleService(),
       _reportConfidenceService =
           reportConfidenceService ?? const ReportConfidenceService(),
       _downstreamPredictionService =
           downstreamPredictionService ?? const DownstreamPredictionService(),
       _sessionStatusAggregationService =
           sessionStatusAggregationService ??
           const SessionStatusAggregationService(
             delayClassifierService: DelayClassifierService(),
             confidenceService: ReportConfidenceService(),
           );

  final RailSessionResolver _sessionResolver;
  final ArrivalReportRepository _arrivalReportRepository;
  final PredictionRepository _predictionRepository;
  final DeviceIdentityRepository _deviceIdentityRepository;
  final SessionLifecycleService _sessionLifecycleService;
  final ReportConfidenceService _reportConfidenceService;
  final DownstreamPredictionService _downstreamPredictionService;
  final SessionStatusAggregationService _sessionStatusAggregationService;
  final int staleInsightThresholdSeconds;

  Future<RailCommunityInsightResult> load({
    required String direction,
    required RailServiceSnapshot? nextService,
    required DateTime now,
  }) async {
    try {
      await _deviceIdentityRepository.readOrCreateIdentity();
      final session = await _sessionResolver.findSessionForTrain(
        direction: direction,
        trainNo: nextService?.trainNo,
        now: now,
      );
      if (session == null) {
        return const RailCommunityInsightResult(
          kind: RailCommunityInsightKind.empty,
          message: 'No active train estimate is available right now.',
        );
      }

      final reportsByStation = <String, List<ArrivalReport>>{};
      for (final stop in session.stops) {
        reportsByStation[stop.stationId] = await _arrivalReportRepository
            .fetchStopReports(
              sessionId: session.sessionId,
              stationId: stop.stationId,
            );
      }

      final observedStops =
          session.stops
              .where(
                (stop) =>
                    (reportsByStation[stop.stationId] ?? const []).isNotEmpty,
              )
              .toList(growable: false)
            ..sort((a, b) => b.sequence.compareTo(a.sequence));
      if (observedStops.isEmpty) {
        return const RailCommunityInsightResult(
          kind: RailCommunityInsightKind.empty,
          message:
              'No community reports are available for this train session yet.',
        );
      }

      final referenceStop = observedStops.first;
      final referenceReports =
          reportsByStation[referenceStop.stationId] ?? const [];
      final consensus = _sessionStatusAggregationService.buildStationConsensus(
        session: session,
        stationId: referenceStop.stationId,
        reports: referenceReports,
        now: now,
      );
      final sessionState = _sessionLifecycleService.getState(
        session: session,
        now: now,
      );
      final status = _sessionStatusAggregationService.buildSessionStatus(
        session: session,
        state: sessionState,
        stationId: referenceStop.stationId,
        reports: referenceReports,
        now: now,
      );
      final localPredictions = consensus.observedArrivalAt == null
          ? const <PredictedStopTime>[]
          : _downstreamPredictionService.predictFromObservation(
              session: session,
              observedStationId: referenceStop.stationId,
              observedArrivalAt: consensus.observedArrivalAt!,
              confidence: _reportConfidenceService.evaluate(
                reports: referenceReports,
                now: now,
              ),
            );
      final remotePredictions = await _predictionRepository.fetchPredictions(
        sessionId: session.sessionId,
      );
      final isStale = status.freshnessSeconds > staleInsightThresholdSeconds;

      return RailCommunityInsightResult(
        kind: isStale
            ? RailCommunityInsightKind.stale
            : RailCommunityInsightKind.ready,
        sessionStatusSnapshot: status,
        predictedStopTimes: remotePredictions.isNotEmpty
            ? remotePredictions
            : localPredictions,
        message: remotePredictions.isNotEmpty
            ? 'Estimate synchronized from remote community snapshots.'
            : 'Estimate based on ${referenceReports.length} report(s) from ${referenceStop.stationName}.',
      );
    } catch (_) {
      return const RailCommunityInsightResult(
        kind: RailCommunityInsightKind.error,
        message:
            'Community estimate is temporarily unavailable. Official schedule remains available.',
      );
    }
  }
}
