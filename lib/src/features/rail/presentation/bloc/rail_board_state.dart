part of 'rail_board_bloc.dart';

enum RailBoardStatus { loading, ready }

class RailBoardState extends Equatable {
  const RailBoardState({
    this.status = RailBoardStatus.loading,
    this.selection = const RailSelection(
      direction: '',
      boardingStationId: '',
      destinationStationId: '',
    ),
    this.directionOptions = const [],
    this.boardingStations = const [],
    this.destinationStations = const [],
    this.snapshot = const RailBoardSnapshot(
      direction: '',
      currentTime: '',
      selectedStationName: '',
      destinationStationName: '',
      nextService: null,
      upcomingServices: [],
    ),
  });

  final RailBoardStatus status;
  final RailSelection selection;
  final List<RailSelectableOption> directionOptions;
  final List<RailSelectableOption> boardingStations;
  final List<RailSelectableOption> destinationStations;
  final RailBoardSnapshot snapshot;

  @override
  List<Object> get props => [
    status,
    selection,
    directionOptions,
    boardingStations,
    destinationStations,
    snapshot,
  ];
}
