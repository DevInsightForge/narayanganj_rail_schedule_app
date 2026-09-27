import 'package:equatable/equatable.dart';

import 'delay_status.dart';
import 'freshness.dart';
import 'report_confidence.dart';

enum CommunityOverlayFreshness { fresh, staleButUsable, expired }

class CommunityOverlay extends Equatable {
  const CommunityOverlay({
    required this.tripId,
    required this.serviceDate,
    required this.delayMinutes,
    required this.delayStatus,
    required this.freshness,
    required this.confidence,
    this.lastReportedStation,
    this.lastReportedAt,
    this.freshnessSeconds = 0,
  });

  final String tripId;
  final String serviceDate;
  final int delayMinutes;
  final DelayStatus delayStatus;
  final Freshness freshness;
  final ReportConfidence confidence;
  final String? lastReportedStation;
  final int? lastReportedAt;
  final int freshnessSeconds;

  String get sessionId => tripId;

  DateTime? get lastObservedAt => lastReportedAt != null
      ? DateTime.fromMillisecondsSinceEpoch(lastReportedAt! * 1000)
      : null;

  CommunityOverlayFreshness get freshnessState {
    if (freshness == Freshness.stale || freshnessSeconds > 300) {
      return CommunityOverlayFreshness.expired;
    }
    if (freshnessSeconds <= 90) {
      return CommunityOverlayFreshness.fresh;
    }
    return CommunityOverlayFreshness.staleButUsable;
  }

  factory CommunityOverlay.fromJson(
    Map<String, dynamic> json, {
    int freshnessSeconds = 0,
  }) {
    final confRaw = json['confidence'];
    final confidence = ReportConfidence(
      score:
          (confRaw is Map ? confRaw['score'] as num? : null)?.toDouble() ?? 0.0,
      sampleCount:
          (confRaw is Map
                  ? (confRaw['sampleCount'] ?? confRaw['sampleSize']) as num?
                  : null)
              ?.toInt() ??
          0,
    );

    return CommunityOverlay(
      tripId: (json['tripId'] ?? json['sessionId'] ?? '').toString(),
      serviceDate: (json['serviceDate'] ?? '').toString(),
      delayMinutes:
          ((json['delayMinutes'] ?? json['delay_minutes']) as num?)?.toInt() ??
          0,
      delayStatus: DelayStatus.fromString(
        (json['delayStatus'] ?? json['status'] ?? '').toString(),
      ),
      freshness: Freshness.fromString((json['freshness'] ?? '').toString()),
      confidence: confidence,
      lastReportedStation: json['lastReportedStation']?.toString(),
      lastReportedAt: (json['lastReportedAt'] as num?)?.toInt(),
      freshnessSeconds: freshnessSeconds,
    );
  }

  CommunityOverlay copyWith({
    String? tripId,
    String? serviceDate,
    int? delayMinutes,
    DelayStatus? delayStatus,
    Freshness? freshness,
    ReportConfidence? confidence,
    String? lastReportedStation,
    int? lastReportedAt,
    int? freshnessSeconds,
  }) {
    return CommunityOverlay(
      tripId: tripId ?? this.tripId,
      serviceDate: serviceDate ?? this.serviceDate,
      delayMinutes: delayMinutes ?? this.delayMinutes,
      delayStatus: delayStatus ?? this.delayStatus,
      freshness: freshness ?? this.freshness,
      confidence: confidence ?? this.confidence,
      lastReportedStation: lastReportedStation ?? this.lastReportedStation,
      lastReportedAt: lastReportedAt ?? this.lastReportedAt,
      freshnessSeconds: freshnessSeconds ?? this.freshnessSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
    'tripId': tripId,
    'serviceDate': serviceDate,
    'delayMinutes': delayMinutes,
    'delayStatus': delayStatus.toApiString(),
    'freshness': freshness.name,
    'confidence': {
      'score': confidence.score,
      'sampleCount': confidence.sampleCount,
    },
    'lastReportedStation': lastReportedStation,
    'lastReportedAt': lastReportedAt,
    'freshnessSeconds': freshnessSeconds,
  };

  @override
  List<Object?> get props => [
    tripId,
    serviceDate,
    delayMinutes,
    delayStatus,
    freshness,
    confidence,
    lastReportedStation,
    lastReportedAt,
    freshnessSeconds,
  ];
}
