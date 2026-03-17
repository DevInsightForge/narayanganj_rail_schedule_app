import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/rail_selection.dart';
import '../../domain/entities/rail_snapshot.dart';
import '../../domain/repositories/selection_repository.dart';
import '../../domain/services/rail_board_service.dart';
import '../../data/repositories/schedule_data_repository.dart';

part 'rail_board_event.dart';
part 'rail_board_state.dart';

class RailBoardBloc extends Bloc<RailBoardEvent, RailBoardState> {
  RailBoardBloc({
    required RailBoardService boardService,
    required ScheduleDataRepository scheduleDataRepository,
    required SelectionRepository selectionRepository,
  }) : _boardService = boardService,
       _scheduleDataRepository = scheduleDataRepository,
       _selectionRepository = selectionRepository,
       super(const RailBoardState()) {
    on<RailBoardStarted>(_onStarted);
    on<RailBoardDirectionChanged>(_onDirectionChanged);
    on<RailBoardBoardingChanged>(_onBoardingChanged);
    on<RailBoardDestinationChanged>(_onDestinationChanged);
    on<RailBoardTicked>(_onTicked);

    add(const RailBoardStarted());
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => add(const RailBoardTicked()),
    );
  }

  RailBoardService _boardService;
  final ScheduleDataRepository _scheduleDataRepository;
  final SelectionRepository _selectionRepository;
  Timer? _timer;

  Future<void> _onStarted(
    RailBoardStarted event,
    Emitter<RailBoardState> emit,
  ) async {
    final storedSelection = await _selectionRepository.read();
    final storedSchedule = await _scheduleDataRepository.readStoredSchedule();

    if (storedSchedule != null) {
      _boardService = RailBoardService(schedule: storedSchedule);
    }

    var selection = _boardService.createSelection(
      direction: storedSelection?.direction,
      boardingStationId: storedSelection?.boardingStationId,
      destinationStationId: storedSelection?.destinationStationId,
    );
    await _selectionRepository.write(selection);
    emit(_buildState(selection));

    final remoteSchedule = await _scheduleDataRepository.fetchRemoteSchedule();

    if (remoteSchedule == null) {
      return;
    }

    _boardService = RailBoardService(schedule: remoteSchedule);
    selection = _boardService.createSelection(
      direction: selection.direction,
      boardingStationId: selection.boardingStationId,
      destinationStationId: selection.destinationStationId,
    );
    await _selectionRepository.write(selection);
    emit(_buildState(selection));
  }

  Future<void> _onDirectionChanged(
    RailBoardDirectionChanged event,
    Emitter<RailBoardState> emit,
  ) async {
    final selection = _boardService.changeDirection(event.direction);
    await _selectionRepository.write(selection);
    emit(_buildState(selection));
  }

  Future<void> _onBoardingChanged(
    RailBoardBoardingChanged event,
    Emitter<RailBoardState> emit,
  ) async {
    final selection = _boardService.changeBoardingStation(
      state.selection,
      event.stationId,
    );
    await _selectionRepository.write(selection);
    emit(_buildState(selection));
  }

  Future<void> _onDestinationChanged(
    RailBoardDestinationChanged event,
    Emitter<RailBoardState> emit,
  ) async {
    final selection = _boardService.changeDestinationStation(
      state.selection,
      event.stationId,
    );
    await _selectionRepository.write(selection);
    emit(_buildState(selection));
  }

  void _onTicked(RailBoardTicked event, Emitter<RailBoardState> emit) {
    emit(_buildState(state.selection));
  }

  RailBoardState _buildState(RailSelection selection) {
    return RailBoardState(
      status: RailBoardStatus.ready,
      selection: selection,
      directionOptions: _boardService.getDirectionOptions(),
      boardingStations: _boardService.getBoardingOptions(selection.direction),
      destinationStations: _boardService.getDestinationOptions(
        selection.direction,
        selection.boardingStationId,
      ),
      snapshot: _boardService.getSnapshot(
        selection: selection,
        now: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await super.close();
  }
}
