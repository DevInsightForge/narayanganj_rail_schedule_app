part of 'rail_board_bloc.dart';

sealed class RailBoardEvent extends Equatable {
  const RailBoardEvent();

  @override
  List<Object> get props => [];
}

class RailBoardStarted extends RailBoardEvent {
  const RailBoardStarted();
}

class RailBoardDirectionChanged extends RailBoardEvent {
  const RailBoardDirectionChanged(this.direction);

  final String direction;

  @override
  List<Object> get props => [direction];
}

class RailBoardBoardingChanged extends RailBoardEvent {
  const RailBoardBoardingChanged(this.stationId);

  final String stationId;

  @override
  List<Object> get props => [stationId];
}

class RailBoardDestinationChanged extends RailBoardEvent {
  const RailBoardDestinationChanged(this.stationId);

  final String stationId;

  @override
  List<Object> get props => [stationId];
}

class RailBoardTicked extends RailBoardEvent {
  const RailBoardTicked();
}
