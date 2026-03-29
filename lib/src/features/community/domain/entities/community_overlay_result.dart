import 'package:equatable/equatable.dart';

import 'predicted_stop_time.dart';
import 'session_status_snapshot.dart';

class CommunityOverlayResult extends Equatable {
  const CommunityOverlayResult({
    required this.fetchedAt,
    required this.fromCache,
    this.sessionStatusSnapshot,
    this.predictedStopTimes = const [],
  });

  final SessionStatusSnapshot? sessionStatusSnapshot;
  final List<PredictedStopTime> predictedStopTimes;
  final DateTime fetchedAt;
  final bool fromCache;

  CommunityOverlayResult copyWith({
    SessionStatusSnapshot? sessionStatusSnapshot,
    List<PredictedStopTime>? predictedStopTimes,
    DateTime? fetchedAt,
    bool? fromCache,
    bool clearSessionStatusSnapshot = false,
  }) {
    return CommunityOverlayResult(
      sessionStatusSnapshot: clearSessionStatusSnapshot
          ? null
          : sessionStatusSnapshot ?? this.sessionStatusSnapshot,
      predictedStopTimes: predictedStopTimes ?? this.predictedStopTimes,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      fromCache: fromCache ?? this.fromCache,
    );
  }

  @override
  List<Object?> get props => [
    sessionStatusSnapshot,
    predictedStopTimes,
    fetchedAt,
    fromCache,
  ];
}
