part of 'rail_board_bloc.dart';

sealed class RailBoardEvent extends Equatable {
  const RailBoardEvent();

  @override
  List<Object> get props => [];
}

final class RailBoardStarted extends RailBoardEvent {
  const RailBoardStarted();
}

final class RailBoardRetryRequested extends RailBoardEvent {
  const RailBoardRetryRequested();
}

final class RailBoardDirectionChanged extends RailBoardEvent {
  const RailBoardDirectionChanged(this.direction);

  final String direction;

  @override
  List<Object> get props => [direction];
}

final class RailBoardBoardingChanged extends RailBoardEvent {
  const RailBoardBoardingChanged(this.stationId);

  final String stationId;

  @override
  List<Object> get props => [stationId];
}

final class RailBoardDestinationChanged extends RailBoardEvent {
  const RailBoardDestinationChanged(this.stationId);

  final String stationId;

  @override
  List<Object> get props => [stationId];
}

final class RailBoardTicked extends RailBoardEvent {
  const RailBoardTicked();
}

final class RailBoardArrivalReportRequested extends RailBoardEvent {
  const RailBoardArrivalReportRequested();
}
