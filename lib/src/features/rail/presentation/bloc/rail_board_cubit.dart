export 'rail_board_state.dart';

import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../../core/errors/error_reporter.dart';
import '../../../community/domain/repositories/arrival_report_ledger_repository.dart';
import '../../../community/domain/repositories/arrival_report_repository.dart';
import '../../../community/domain/repositories/community_overlay_repository.dart';
import '../../../community/domain/repositories/device_identity_repository.dart';
import '../../../community/domain/repositories/session_repository.dart';
import '../../data/repositories/schedule_data_repository.dart';
import '../../domain/repositories/selection_repository.dart';
import '../../domain/services/rail_board_service.dart';
import 'rail_board_controller.dart';
import 'rail_board_state.dart';

class RailBoardCubit extends Cubit<RailBoardState> {
  RailBoardCubit({
    required RailBoardService boardService,
    required ScheduleDataRepository scheduleDataRepository,
    required SelectionRepository selectionRepository,
    required SessionRepository sessionRepository,
    required ArrivalReportRepository arrivalReportRepository,
    required ArrivalReportLedgerRepository arrivalReportLedgerRepository,
    required CommunityOverlayRepository communityOverlayRepository,
    required DeviceIdentityRepository deviceIdentityRepository,
    ErrorReporter? errorReporter,
    this.communityFeaturesEnabled = true,
    this.enableTicker = true,
    DateTime Function()? nowProvider,
  }) : _controller = RailBoardController(
         boardService: boardService,
         scheduleDataRepository: scheduleDataRepository,
         selectionRepository: selectionRepository,
         sessionRepository: sessionRepository,
         arrivalReportRepository: arrivalReportRepository,
         arrivalReportLedgerRepository: arrivalReportLedgerRepository,
         communityOverlayRepository: communityOverlayRepository,
         deviceIdentityRepository: deviceIdentityRepository,
         errorReporter: errorReporter,
         communityFeaturesEnabled: communityFeaturesEnabled,
         nowProvider: nowProvider,
       ),
       super(const RailBoardState()) {
    unawaited(start());
    if (enableTicker) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        unawaited(tick());
      });
    }
  }

  final RailBoardController _controller;
  final bool communityFeaturesEnabled;
  final bool enableTicker;
  Timer? _timer;

  RailBoardService get boardService => _controller.boardService;

  Future<void> start() async {
    await _controller.start(() => state, _emitIfOpen);
  }

  Future<void> retry() async {
    await _controller.retry(() => state, _emitIfOpen);
  }

  Future<void> changeDirection(String direction) async {
    await _controller.changeDirection(() => state, _emitIfOpen, direction);
  }

  Future<void> changeBoarding(String stationId) async {
    await _controller.changeBoarding(() => state, _emitIfOpen, stationId);
  }

  Future<void> changeDestination(String stationId) async {
    await _controller.changeDestination(() => state, _emitIfOpen, stationId);
  }

  Future<void> tick() async {
    await _controller.tick(() => state, _emitIfOpen);
  }

  Future<void> submitArrivalReport() async {
    await _controller.submitArrivalReport(() => state, _emitIfOpen);
  }

  void _emitIfOpen(RailBoardState nextState) {
    if (isClosed) {
      return;
    }
    emit(nextState);
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await super.close();
  }
}
