import 'package:equatable/equatable.dart';

class RailDirection extends Equatable {
  const RailDirection({
    required this.id,
    required this.directionKey,
    required this.prefix,
    required this.label,
    required this.isForward,
  });

  final String id;
  final String directionKey;
  final String prefix;
  final String label;
  final bool isForward;

  @override
  List<Object> get props => [id, directionKey, prefix, label, isForward];
}
