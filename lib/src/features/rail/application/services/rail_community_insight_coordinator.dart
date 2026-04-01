import 'package:flutter/foundation.dart';

import '../../../community/domain/entities/community_overlay_result.dart';
import '../../../community/domain/entities/session_status_snapshot.dart';
import '../../../community/domain/repositories/community_overlay_repository.dart';
import '../../../../core/errors/error_report_context.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/logging/debug_logger.dart';
import '../../domain/entities/rail_snapshot.dart';
import '../models/rail_community_insight_result.dart';
import 'rail_session_resolver.dart';

class RailCommunityInsightCoordinator {
  RailCommunityInsightCoordinator({
    required RailSessionResolver sessionResolver,
    required CommunityOverlayRepository communityOverlayRepository,
    ErrorReporter? errorReporter,
    DebugLogger? logger,
    this.staleInsightThresholdSeconds = 10 * 60,
  }) : _sessionResolver = sessionResolver,
       _communityOverlayRepository = communityOverlayRepository,
       _errorReporter = errorReporter ?? const NoopErrorReporter(),
       _logger = logger ?? const DebugLogger('RailCommunityInsightCoordinator');

  final RailSessionResolver _sessionResolver;
  final CommunityOverlayRepository _communityOverlayRepository;
  final ErrorReporter _errorReporter;
  final DebugLogger _logger;
  final int staleInsightThresholdSeconds;

  Future<RailCommunityInsightResult> load({
    required String direction,
    required RailServiceSnapshot? nextService,
    required DateTime now,
    bool forceRefresh = false,
    String? attemptId,
  }) async {
    _log(
      'overlay_refresh_start',
      attemptId: attemptId,
      context: _context(attemptId: attemptId),
    );
    try {
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

      final overlay = await _communityOverlayRepository.fetchSessionOverlay(
        sessionId: session.sessionId,
        forceRefresh: forceRefresh,
      );
      final snapshot = _applyOverlayAge(overlay, now);
      if (snapshot == null && overlay.predictedStopTimes.isEmpty) {
        return const RailCommunityInsightResult(
          kind: RailCommunityInsightKind.empty,
          message:
              'No community reports are available for this train session yet.',
        );
      }

      final isStale =
          snapshot != null &&
          snapshot.freshnessSeconds > staleInsightThresholdSeconds;

      _log(
        'overlay_refresh_success',
        attemptId: attemptId,
        context: _context(attemptId: attemptId, sessionId: session.sessionId),
      );
      return RailCommunityInsightResult(
        kind: isStale
            ? RailCommunityInsightKind.stale
            : RailCommunityInsightKind.ready,
        sessionStatusSnapshot: snapshot,
        predictedStopTimes: overlay.predictedStopTimes,
        message: overlay.fromCache
            ? 'Estimate loaded from local Spark-safe community cache.'
            : 'Estimate synchronized from remote community snapshots.',
      );
    } catch (error, stackTrace) {
      await _errorReporter.reportNonFatal(
        error,
        stackTrace,
        reason: 'overlay_refresh_failed',
        context: _context(attemptId: attemptId),
      );
      _log(
        'overlay_refresh_fail',
        attemptId: attemptId,
        context: _context(attemptId: attemptId),
      );
      return const RailCommunityInsightResult(
        kind: RailCommunityInsightKind.error,
        message:
            'Community estimate is temporarily unavailable. Official schedule remains available.',
      );
    }
  }

  SessionStatusSnapshot? _applyOverlayAge(
    CommunityOverlayResult overlay,
    DateTime now,
  ) {
    final snapshot = overlay.sessionStatusSnapshot;
    if (snapshot == null) {
      return null;
    }
    final ageSeconds = now.difference(overlay.fetchedAt).inSeconds;
    final adjustedFreshness =
        snapshot.freshnessSeconds + (ageSeconds < 0 ? 0 : ageSeconds);
    return SessionStatusSnapshot(
      sessionId: snapshot.sessionId,
      state: snapshot.state,
      delayMinutes: snapshot.delayMinutes,
      delayStatus: snapshot.delayStatus,
      confidence: snapshot.confidence,
      freshnessSeconds: adjustedFreshness,
      lastObservedAt: snapshot.lastObservedAt,
    );
  }

  void _log(String message, {String? attemptId, ErrorReportContext? context}) {
    if (!kDebugMode) {
      return;
    }
    _logger.log(
      message,
      context: context?.toMap() ?? <String, Object?>{'attemptId': attemptId},
    );
  }

  ErrorReportContext _context({String? attemptId, String? sessionId}) {
    return ErrorReportContext(
      feature: 'rail_community_insight_coordinator',
      event: 'overlay_refresh',
      attemptId: attemptId,
      sessionId: sessionId,
    );
  }
}
