import '../../../domain/entities/rate_limit_policy.dart';
import '../../../domain/repositories/rate_limit_policy_repository.dart';

class FakeRateLimitPolicyRepository implements RateLimitPolicyRepository {
  FakeRateLimitPolicyRepository({Map<String, RateLimitPolicy> seed = const {}})
    : _policies = Map<String, RateLimitPolicy>.from(seed);

  final Map<String, RateLimitPolicy> _policies;
  final Map<String, List<DateTime>> _events = {};

  @override
  Future<RateLimitDecision> checkAllowance({
    required String key,
    required DateTime now,
  }) async {
    final policy = await fetchPolicy(key);
    final events = _events[key] ?? <DateTime>[];
    final cutoff = now.subtract(Duration(seconds: policy.windowSeconds));
    final recent = events.where((time) => !time.isBefore(cutoff)).toList();
    _events[key] = recent;
    if (recent.length < policy.maxEvents) {
      return const RateLimitDecision(allowed: true, retryAfterSeconds: 0);
    }
    final oldest = recent.first;
    final retryAfter = oldest
        .add(Duration(seconds: policy.windowSeconds))
        .difference(now)
        .inSeconds;
    return RateLimitDecision(
      allowed: false,
      retryAfterSeconds: retryAfter < 0 ? 0 : retryAfter,
    );
  }

  @override
  Future<RateLimitPolicy> fetchPolicy(String key) async {
    return _policies[key] ??
        const RateLimitPolicy(
          key: 'default',
          maxEvents: 3,
          windowSeconds: 120,
          coolDownSeconds: 30,
        );
  }

  @override
  Future<void> recordEvent({required String key, required DateTime now}) async {
    final events = _events[key] ?? <DateTime>[];
    events.add(now);
    events.sort();
    _events[key] = events;
  }
}
