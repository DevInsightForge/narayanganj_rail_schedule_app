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
    this.isReportingAvailable = false,
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
  final bool isReportingAvailable;

  static const freshWindowSeconds = 180;
  static const maxUsableWindowSeconds = 1200;

  CommunityOverlayFreshness get freshnessState {
    if (freshnessSeconds > maxUsableWindowSeconds) {
      return CommunityOverlayFreshness.expired;
    }
    if (freshness == Freshness.stale || freshnessSeconds > freshWindowSeconds) {
      return CommunityOverlayFreshness.staleButUsable;
    }
    return CommunityOverlayFreshness.fresh;
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
          (confRaw is Map ? confRaw['sampleCount'] as num? : null)?.toInt() ??
          0,
    );

    return CommunityOverlay(
      tripId: (json['tripId'] ?? '').toString(),
      serviceDate: (json['serviceDate'] ?? '').toString(),
      delayMinutes: (json['delayMinutes'] as num?)?.toInt() ?? 0,
      delayStatus: DelayStatus.fromString(
        (json['delayStatus'] ?? '').toString(),
      ),
      freshness: Freshness.fromString((json['freshness'] ?? '').toString()),
      confidence: confidence,
      lastReportedStation: json['lastReportedStation']?.toString(),
      lastReportedAt: (json['lastReportedAt'] as num?)?.toInt(),
      freshnessSeconds: freshnessSeconds,
      isReportingAvailable: json['isReportingAvailable'] as bool? ?? false,
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
    bool? isReportingAvailable,
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
      isReportingAvailable: isReportingAvailable ?? this.isReportingAvailable,
    );
  }

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
    isReportingAvailable,
  ];
}
