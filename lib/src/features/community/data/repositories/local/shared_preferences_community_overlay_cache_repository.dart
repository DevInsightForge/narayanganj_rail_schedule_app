import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/community_overlay_result.dart';
import '../../../domain/entities/data_origin.dart';
import '../../../domain/entities/delay_status.dart';
import '../../../domain/entities/predicted_stop_time.dart';
import '../../../domain/entities/report_confidence.dart';
import '../../../domain/entities/session_status_snapshot.dart';
import '../../../domain/repositories/community_overlay_cache_repository.dart';

class SharedPreferencesCommunityOverlayCacheRepository
    implements CommunityOverlayCacheRepository {
  static const _keyPrefix = 'nrs:community:overlay:';

  @override
  Future<CommunityOverlayResult?> read({required String sessionId}) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('$_keyPrefix$sessionId');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final fetchedAt = DateTime.tryParse(
      '${decoded['fetchedAt'] ?? ''}',
    )?.toLocal();
    if (fetchedAt == null) {
      return null;
    }
    final snapshotMap = decoded['sessionStatusSnapshot'];
    final predictionsList = decoded['predictedStopTimes'];
    return CommunityOverlayResult(
      sessionStatusSnapshot: snapshotMap is Map<String, dynamic>
          ? _readSnapshot(snapshotMap)
          : null,
      predictedStopTimes: predictionsList is List
          ? predictionsList
                .whereType<Map<String, dynamic>>()
                .map(_readPrediction)
                .toList(growable: false)
          : const <PredictedStopTime>[],
      fetchedAt: fetchedAt,
      fromCache: true,
    );
  }

  @override
  Future<void> write({
    required String sessionId,
    required CommunityOverlayResult overlay,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'fetchedAt': overlay.fetchedAt.toUtc().toIso8601String(),
      'sessionStatusSnapshot': overlay.sessionStatusSnapshot == null
          ? null
          : _writeSnapshot(overlay.sessionStatusSnapshot!),
      'predictedStopTimes': overlay.predictedStopTimes.map(_writePrediction).toList(
        growable: false,
      ),
    };
    await preferences.setString(
      '$_keyPrefix$sessionId',
      jsonEncode(payload),
    );
  }

  SessionStatusSnapshot _readSnapshot(Map<String, dynamic> map) {
    return SessionStatusSnapshot(
      sessionId: '${map['sessionId'] ?? ''}',
      state: SessionLifecycleState.values.byName('${map['state'] ?? 'active'}'),
      delayMinutes: (map['delayMinutes'] as num?)?.toInt() ?? 0,
      delayStatus: DelayStatus.values.byName(
        '${map['delayStatus'] ?? 'onTime'}',
      ),
      confidence: _readConfidence(map['confidence'] as Map<String, dynamic>?),
      freshnessSeconds: (map['freshnessSeconds'] as num?)?.toInt() ?? 0,
      lastObservedAt: DateTime.tryParse(
        '${map['lastObservedAt'] ?? ''}',
      )?.toLocal(),
    );
  }

  Map<String, dynamic> _writeSnapshot(SessionStatusSnapshot snapshot) {
    return <String, dynamic>{
      'sessionId': snapshot.sessionId,
      'state': snapshot.state.name,
      'delayMinutes': snapshot.delayMinutes,
      'delayStatus': snapshot.delayStatus.name,
      'confidence': _writeConfidence(snapshot.confidence),
      'freshnessSeconds': snapshot.freshnessSeconds,
      'lastObservedAt': snapshot.lastObservedAt?.toUtc().toIso8601String(),
    };
  }

  PredictedStopTime _readPrediction(Map<String, dynamic> map) {
    return PredictedStopTime(
      sessionId: '${map['sessionId'] ?? ''}',
      stationId: '${map['stationId'] ?? ''}',
      predictedAt: DateTime.tryParse(
            '${map['predictedAt'] ?? ''}',
          )?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      referenceStationId: '${map['referenceStationId'] ?? ''}',
      origin: DataOrigin.values.byName('${map['origin'] ?? 'community'}'),
      confidence: _readConfidence(map['confidence'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> _writePrediction(PredictedStopTime value) {
    return <String, dynamic>{
      'sessionId': value.sessionId,
      'stationId': value.stationId,
      'predictedAt': value.predictedAt.toUtc().toIso8601String(),
      'referenceStationId': value.referenceStationId,
      'origin': value.origin.name,
      'confidence': _writeConfidence(value.confidence),
    };
  }

  ReportConfidence _readConfidence(Map<String, dynamic>? map) {
    return ReportConfidence(
      score: (map?['score'] as num?)?.toDouble() ?? 0,
      sampleSize: (map?['sampleSize'] as num?)?.toInt() ?? 0,
      freshnessSeconds: (map?['freshnessSeconds'] as num?)?.toInt() ?? 0,
      agreementScore: (map?['agreementScore'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> _writeConfidence(ReportConfidence confidence) {
    return <String, dynamic>{
      'score': confidence.score,
      'sampleSize': confidence.sampleSize,
      'freshnessSeconds': confidence.freshnessSeconds,
      'agreementScore': confidence.agreementScore,
    };
  }
}
