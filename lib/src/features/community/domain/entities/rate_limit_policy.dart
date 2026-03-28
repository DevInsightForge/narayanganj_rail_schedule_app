import 'package:equatable/equatable.dart';

class RateLimitPolicy extends Equatable {
  const RateLimitPolicy({
    required this.key,
    required this.maxEvents,
    required this.windowSeconds,
    required this.coolDownSeconds,
  });

  final String key;
  final int maxEvents;
  final int windowSeconds;
  final int coolDownSeconds;

  @override
  List<Object> get props => [key, maxEvents, windowSeconds, coolDownSeconds];
}

class RateLimitDecision extends Equatable {
  const RateLimitDecision({
    required this.allowed,
    required this.retryAfterSeconds,
  });

  final bool allowed;
  final int retryAfterSeconds;

  @override
  List<Object> get props => [allowed, retryAfterSeconds];
}
