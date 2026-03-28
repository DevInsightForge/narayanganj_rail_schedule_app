import '../entities/rate_limit_policy.dart';

abstract class RateLimitPolicyRepository {
  Future<RateLimitPolicy> fetchPolicy(String key);

  Future<RateLimitDecision> checkAllowance({
    required String key,
    required DateTime now,
  });

  Future<void> recordEvent({required String key, required DateTime now});
}
