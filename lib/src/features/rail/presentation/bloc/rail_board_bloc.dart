import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/datasources/static_schedule_data_source.dart';
import '../../data/repositories/schedule_data_repository.dart';
import '../../domain/entities/rail_selection.dart';
import '../../domain/entities/rail_snapshot.dart';
import '../../domain/repositories/selection_repository.dart';
import '../../domain/services/rail_board_service.dart';

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
       _activeSource = ScheduleDataSource.bundled,
       _lastUpdatedAt = null,
       super(const RailBoardState()) {
    on<RailBoardStarted>(_onStarted);
    on<RailBoardRetryRequested>(_onRetryRequested);
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

  static const _fallbackErrorMessage =
      'Unable to load schedule data. Please try again.';

  RailBoardService _boardService;
  final ScheduleDataRepository _scheduleDataRepository;
  final SelectionRepository _selectionRepository;
  final String _bundledVersion = StaticScheduleDataSource.version;
  Timer? _timer;

  ScheduleDataSource _activeSource;
  DateTime? _lastUpdatedAt;

  Future<void> _onStarted(
    RailBoardStarted event,
    Emitter<RailBoardState> emit,
  ) async {
    await _loadBoard(emit: emit, showLoading: true);
  }

  Future<void> _onRetryRequested(
    RailBoardRetryRequested event,
    Emitter<RailBoardState> emit,
  ) async {
    await _loadBoard(emit: emit, showLoading: true);
  }

  Future<void> _loadBoard({
    required Emitter<RailBoardState> emit,
    required bool showLoading,
  }) async {
    if (showLoading) {
      emit(state.copyWith(status: RailBoardStatus.loading, clearError: true));
    }

    try {
      final storedSelection = await _selectionRepository.read();
      final storedSchedule = await _scheduleDataRepository.readStoredSchedule();

      if (storedSchedule != null) {
        _boardService = RailBoardService(schedule: storedSchedule.schedule);
        _activeSource = storedSchedule.source;
        _lastUpdatedAt = storedSchedule.loadedAt;
      } else {
        _activeSource = ScheduleDataSource.bundled;
        _lastUpdatedAt = null;
      }

      var selection = _boardService.createSelection(
        direction: storedSelection?.direction,
        boardingStationId: storedSelection?.boardingStationId,
        destinationStationId: storedSelection?.destinationStationId,
      );

      await _persistAndEmit(selection: selection, emit: emit);

      final remoteSchedule = await _scheduleDataRepository.fetchRemoteSchedule();
      if (remoteSchedule == null) {
        return;
      }

      _boardService = RailBoardService(schedule: remoteSchedule.schedule);
      _activeSource = remoteSchedule.source;
      _lastUpdatedAt = remoteSchedule.loadedAt;
      selection = _boardService.createSelection(
        direction: selection.direction,
        boardingStationId: selection.boardingStationId,
        destinationStationId: selection.destinationStationId,
      );
      await _persistAndEmit(selection: selection, emit: emit);
    } catch (_) {
      emit(
        state.copyWith(
          status: RailBoardStatus.failure,
          errorMessage: _fallbackErrorMessage,
        ),
      );
    }
  }

  Future<void> _persistAndEmit({
    required RailSelection selection,
    required Emitter<RailBoardState> emit,
  }) async {
    await _selectionRepository.write(selection);
    emit(_buildState(selection));
  }

  Future<void> _onDirectionChanged(
    RailBoardDirectionChanged event,
    Emitter<RailBoardState> emit,
  ) async {
    final selection = _boardService.changeDirection(event.direction);
    await _persistAndEmit(selection: selection, emit: emit);
  }

  Future<void> _onBoardingChanged(
    RailBoardBoardingChanged event,
    Emitter<RailBoardState> emit,
  ) async {
    final selection = _boardService.changeBoardingStation(
      state.selection,
      event.stationId,
    );
    await _persistAndEmit(selection: selection, emit: emit);
  }

  Future<void> _onDestinationChanged(
    RailBoardDestinationChanged event,
    Emitter<RailBoardState> emit,
  ) async {
    final selection = _boardService.changeDestinationStation(
      state.selection,
      event.stationId,
    );
    await _persistAndEmit(selection: selection, emit: emit);
  }

  void _onTicked(RailBoardTicked event, Emitter<RailBoardState> emit) {
    if (state.status == RailBoardStatus.ready) {
      emit(_buildState(state.selection));
    }
  }

  RailBoardState _buildState(RailSelection selection) {
    final sourceLabel = switch (_activeSource) {
      ScheduleDataSource.bundled => 'Bundled',
      ScheduleDataSource.cached => 'Cached',
      ScheduleDataSource.remote => 'Remote',
    };

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
      ).copyWith(
        dataSourceLabel: sourceLabel,
        lastUpdatedAt: _lastUpdatedAt,
        scheduleVersion: _boardService.schedule.version.isEmpty
            ? _bundledVersion
            : _boardService.schedule.version,
      ),
      errorMessage: null,
    );
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await super.close();
  }
}
