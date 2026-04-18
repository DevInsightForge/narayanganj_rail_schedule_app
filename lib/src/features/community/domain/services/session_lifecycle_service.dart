import '../entities/session_status_snapshot.dart';
import '../entities/train_session.dart';

class SessionLifecycleService {
  const SessionLifecycleService({
    this.preDepartureMinutes = 5,
    this.postDepartureMinutes = 15,
  });

  final int preDepartureMinutes;
  final int postDepartureMinutes;

  SessionLifecycleState getState({
    required TrainSession session,
    required DateTime now,
  }) {
    final eligibilityStart = session.departureAt.subtract(
      Duration(minutes: preDepartureMinutes),
    );
    final eligibilityEnd = session.arrivalAt.add(
      Duration(minutes: postDepartureMinutes),
    );

    if (now.isBefore(eligibilityStart)) {
      return SessionLifecycleState.upcoming;
    }
    if (now.isAfter(eligibilityEnd)) {
      return SessionLifecycleState.expired;
    }
    return SessionLifecycleState.active;
  }

  SessionLifecycleState getStateForScheduledAt({
    required DateTime scheduledAt,
    required DateTime now,
  }) {
    final eligibilityStart = scheduledAt.subtract(
      Duration(minutes: preDepartureMinutes),
    );
    final eligibilityEnd = scheduledAt.add(
      Duration(minutes: postDepartureMinutes),
    );

    if (now.isBefore(eligibilityStart)) {
      return SessionLifecycleState.upcoming;
    }
    if (now.isAfter(eligibilityEnd)) {
      return SessionLifecycleState.expired;
    }
    return SessionLifecycleState.active;
  }

  bool isReportEligible({
    required TrainSession session,
    required DateTime now,
  }) {
    final state = getState(session: session, now: now);
    return state == SessionLifecycleState.active;
  }

  bool isReportEligibleForScheduledAt({
    required DateTime scheduledAt,
    required DateTime now,
  }) {
    final state = getStateForScheduledAt(scheduledAt: scheduledAt, now: now);
    return state == SessionLifecycleState.active;
  }
}
