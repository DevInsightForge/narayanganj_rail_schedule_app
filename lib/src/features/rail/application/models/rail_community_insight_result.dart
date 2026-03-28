import '../../../community/domain/entities/predicted_stop_time.dart';
import '../../../community/domain/entities/session_status_snapshot.dart';

enum RailCommunityInsightKind { idle, loading, ready, stale, empty, error }

class RailCommunityInsightResult {
  const RailCommunityInsightResult({
    required this.kind,
    this.sessionStatusSnapshot,
    this.predictedStopTimes = const [],
    this.message,
  });

  final RailCommunityInsightKind kind;
  final SessionStatusSnapshot? sessionStatusSnapshot;
  final List<PredictedStopTime> predictedStopTimes;
  final String? message;
}
