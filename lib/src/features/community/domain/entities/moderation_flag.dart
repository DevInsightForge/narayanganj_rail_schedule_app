import 'package:equatable/equatable.dart';

class ModerationFlag extends Equatable {
  const ModerationFlag({
    required this.code,
    required this.severity,
    required this.createdAt,
  });

  final String code;
  final int severity;
  final DateTime createdAt;

  @override
  List<Object> get props => [code, severity, createdAt];
}
