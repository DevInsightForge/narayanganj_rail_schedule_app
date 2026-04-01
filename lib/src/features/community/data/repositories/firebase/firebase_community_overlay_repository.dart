import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/errors/error_report_context.dart';
import '../../../../../core/logging/debug_logger.dart';
import '../../../domain/entities/community_overlay_result.dart';
import '../../../domain/entities/data_origin.dart';
import '../../../domain/entities/delay_status.dart';
import '../../../domain/entities/predicted_stop_time.dart';
import '../../../domain/entities/report_confidence.dart';
import '../../../domain/entities/session_status_snapshot.dart';
import '../../../domain/repositories/community_overlay_repository.dart';

class FirebaseCommunityOverlayRepository implements CommunityOverlayRepository {
  FirebaseCommunityOverlayRepository({
    required FirebaseFirestore firestore,
    Future<Map<String, dynamic>?> Function(String sessionId)? loader,
    DateTime Function()? nowProvider,
    DebugLogger? logger,
  }) : _firestore = firestore,
       _loader = loader,
       _nowProvider = nowProvider ?? DateTime.now,
       _logger =
           logger ?? const DebugLogger('FirebaseCommunityOverlayRepository');

  final FirebaseFirestore _firestore;
  final Future<Map<String, dynamic>?> Function(String sessionId)? _loader;
  final DateTime Function() _nowProvider;
  final DebugLogger _logger;

  @override
  Future<CommunityOverlayResult> fetchSessionOverlay({
    required String sessionId,
    bool forceRefresh = false,
  }) async {
    final data = await (_loader?.call(sessionId) ?? _load(sessionId));
    final fetchedAt = _nowProvider();
    if (data == null || data.isEmpty) {
      return CommunityOverlayResult(fetchedAt: fetchedAt, fromCache: false);
    }
    return CommunityOverlayResult(
      sessionStatusSnapshot: _readSnapshot(sessionId, data),
      predictedStopTimes: _readPredictions(sessionId, data),
      fetchedAt: fetchedAt,
      fromCache: false,
    );
  }

  Future<Map<String, dynamic>?> _load(String sessionId) async {
    try {
      final document = await _firestore
          .collection('session_status_snapshots')
          .doc(sessionId)
          .get();
      return document.data();
    } catch (error) {
      _logger.log(
        'overlay_load_fail',
        context: ErrorReportContext(
          feature: 'community_overlay',
          event: 'overlay_load',
          sessionId: sessionId,
        ).toMap(),
      );
      rethrow;
    }
  }

  SessionStatusSnapshot? _readSnapshot(
    String sessionId,
    Map<String, dynamic> map,
  ) {
    final rawState = '${map['state'] ?? map['lifecycleState'] ?? ''}'.trim();
    final rawDelayStatus = '${map['delayStatus'] ?? ''}'.trim();
    final confidenceMap = _readConfidenceMap(map['confidence']);
    if (rawState.isEmpty || rawDelayStatus.isEmpty || confidenceMap == null) {
      return null;
    }
    return SessionStatusSnapshot(
      sessionId: '${map['sessionId'] ?? sessionId}',
      state: _parseLifecycleState(rawState),
      delayMinutes: (map['delayMinutes'] as num?)?.toInt() ?? 0,
      delayStatus: _parseDelayStatus(rawDelayStatus),
      confidence: _readConfidence(confidenceMap),
      freshnessSeconds: (map['freshnessSeconds'] as num?)?.toInt() ?? 0,
      lastObservedAt: _readDateTime(map['lastObservedAt']),
    );
  }

  List<PredictedStopTime> _readPredictions(
    String sessionId,
    Map<String, dynamic> map,
  ) {
    final raw =
        map['predictedStops'] ?? map['predictions'] ?? map['predicted_stops'];
    if (raw is! List) {
      return const <PredictedStopTime>[];
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(
          (prediction) => PredictedStopTime(
            sessionId: '${prediction['sessionId'] ?? sessionId}',
            stationId: '${prediction['stationId'] ?? ''}',
            predictedAt:
                _readDateTime(prediction['predictedAt']) ?? _nowProvider(),
            referenceStationId: '${prediction['referenceStationId'] ?? ''}',
            origin: _parseDataOrigin('${prediction['origin'] ?? 'community'}'),
            confidence: _readConfidence(
              _readConfidenceMap(prediction['confidence']) ??
                  const <String, dynamic>{},
            ),
          ),
        )
        .toList(growable: false);
  }

  Map<String, dynamic>? _readConfidenceMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    return null;
  }

  ReportConfidence _readConfidence(Map<String, dynamic> map) {
    return ReportConfidence(
      score: (map['score'] as num?)?.toDouble() ?? 0,
      sampleSize: (map['sampleSize'] as num?)?.toInt() ?? 0,
      freshnessSeconds: (map['freshnessSeconds'] as num?)?.toInt() ?? 0,
      agreementScore: (map['agreementScore'] as num?)?.toDouble() ?? 0,
    );
  }

  DateTime? _readDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }

  SessionLifecycleState _parseLifecycleState(String value) {
    return switch (value) {
      'upcoming' => SessionLifecycleState.upcoming,
      'expired' => SessionLifecycleState.expired,
      _ => SessionLifecycleState.active,
    };
  }

  DelayStatus _parseDelayStatus(String value) {
    return switch (value) {
      'early' => DelayStatus.early,
      'late' => DelayStatus.late,
      _ => DelayStatus.onTime,
    };
  }

  DataOrigin _parseDataOrigin(String value) {
    return switch (value) {
      'official' => DataOrigin.official,
      'inferred' => DataOrigin.inferred,
      _ => DataOrigin.community,
    };
  }
}
