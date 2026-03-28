import '../entities/delay_status.dart';

class DelayClassifierService {
  const DelayClassifierService({this.onTimeThresholdMinutes = 2});

  final int onTimeThresholdMinutes;

  int delayMinutes({
    required DateTime scheduledAt,
    required DateTime observedAt,
  }) {
    return observedAt.difference(scheduledAt).inMinutes;
  }

  DelayStatus classify({
    required DateTime scheduledAt,
    required DateTime observedAt,
  }) {
    final minutes = delayMinutes(
      scheduledAt: scheduledAt,
      observedAt: observedAt,
    );
    if (minutes < -onTimeThresholdMinutes) {
      return DelayStatus.early;
    }
    if (minutes > onTimeThresholdMinutes) {
      return DelayStatus.late;
    }
    return DelayStatus.onTime;
  }
}
