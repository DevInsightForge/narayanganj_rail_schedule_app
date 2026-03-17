import 'package:equatable/equatable.dart';

class RailSelection extends Equatable {
  const RailSelection({
    required this.direction,
    required this.boardingStationId,
    required this.destinationStationId,
  });

  final String direction;
  final String boardingStationId;
  final String destinationStationId;

  RailSelection copyWith({
    String? direction,
    String? boardingStationId,
    String? destinationStationId,
  }) {
    return RailSelection(
      direction: direction ?? this.direction,
      boardingStationId: boardingStationId ?? this.boardingStationId,
      destinationStationId: destinationStationId ?? this.destinationStationId,
    );
  }

  @override
  List<Object> get props => [
    direction,
    boardingStationId,
    destinationStationId,
  ];
}
