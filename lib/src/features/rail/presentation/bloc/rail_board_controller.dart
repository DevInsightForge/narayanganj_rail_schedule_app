import '../../../community/domain/repositories/arrival_report_ledger_repository.dart';
import '../../../community/domain/repositories/arrival_report_repository.dart';
import '../../../community/domain/repositories/community_overlay_repository.dart';
import '../../../community/domain/repositories/device_identity_repository.dart';
import '../../../community/domain/entities/firebase_auth_readiness.dart';
import '../../../community/domain/repositories/session_repository.dart';
import '../../../../core/errors/error_report_context.dart';
import '../../../../core/errors/error_reporter.dart';
import '../../../../core/tracing/attempt_id_factory.dart';
import '../../application/models/rail_community_insight_result.dart';
import '../../application/models/rail_reporting.dart';
import '../../data/repositories/schedule_data_repository.dart';
import '../../domain/entities/rail_selection.dart';
import '../../domain/repositories/selection_repository.dart';
import '../../domain/services/rail_board_service.dart';
import 'rail_board_state.dart';
import '../../application/services/rail_board_use_case.dart';

part 'rail_board_controller_loading.dart';
part 'rail_board_controller_reporting.dart';
part 'rail_board_controller_community.dart';

typedef RailBoardStateReader = RailBoardState Function();
typedef RailBoardStateEmitter = void Function(RailBoardState state);

class RailBoardController {
  RailBoardController({
    required RailBoardService boardService,
    required ScheduleDataRepository scheduleDataRepository,
    required SelectionRepository selectionRepository,
    required SessionRepository sessionRepository,
    required ArrivalReportRepository arrivalReportRepository,
    required ArrivalReportLedgerRepository arrivalReportLedgerRepository,
    required CommunityOverlayRepository communityOverlayRepository,
    required DeviceIdentityRepository deviceIdentityRepository,
    ErrorReporter? errorReporter,
    AttemptIdFactory? attemptIdFactory,
    this.communityFeaturesEnabled = true,
    DateTime Function()? nowProvider,
  }) : _boardService = boardService,
       _scheduleDataRepository = scheduleDataRepository,
       _selectionRepository = selectionRepository,
       _deviceIdentityRepository = deviceIdentityRepository,
       _nowProvider = nowProvider ?? DateTime.now,
       _errorReporter = errorReporter ?? const NoopErrorReporter(),
       _attemptIdFactory = attemptIdFactory ?? AttemptIdFactory(),
       _useCase = RailBoardUseCase(
         sessionRepository: sessionRepository,
         arrivalReportRepository: arrivalReportRepository,
         arrivalReportLedgerRepository: arrivalReportLedgerRepository,
         communityOverlayRepository: communityOverlayRepository,
         deviceIdentityRepository: deviceIdentityRepository,
         routeId: _routeId,
         errorReporter: errorReporter,
       ),
       _initialScheduleVersion = boardService.schedule.version,
       _activeSource = ScheduleDataSource.bundled,
       _lastUpdatedAt = null;

  static const _fallbackErrorMessage =
      'Unable to load schedule data. Please try again.';
  static const _routeId = 'narayanganj_line';

  final ScheduleDataRepository _scheduleDataRepository;
  final SelectionRepository _selectionRepository;
  final DeviceIdentityRepository _deviceIdentityRepository;
  final DateTime Function() _nowProvider;
  final ErrorReporter _errorReporter;
  final AttemptIdFactory _attemptIdFactory;
  final bool communityFeaturesEnabled;
  final RailBoardUseCase _useCase;
  final String _initialScheduleVersion;
  int _reportAvailabilityRevision = 0;

  RailBoardService _boardService;
  ScheduleDataSource _activeSource;
  DateTime? _lastUpdatedAt;

  RailBoardService get boardService => _boardService;

  Future<void> start(
    RailBoardStateReader readState,
    RailBoardStateEmitter emit,
  ) async {
    await RailBoardControllerLoading.loadBoard(
      this,
      readState,
      emit,
      showLoading: true,
    );
  }

  Future<void> retry(
    RailBoardStateReader readState,
    RailBoardStateEmitter emit,
  ) async {
    await RailBoardControllerLoading.loadBoard(
      this,
      readState,
      emit,
      showLoading: true,
      forceCommunityRefresh: true,
    );
  }

  Future<void> changeDirection(
    RailBoardStateReader readState,
    RailBoardStateEmitter emit,
    String direction,
  ) async {
    final selection = _boardService.changeDirection(direction);
    await RailBoardControllerLoading.persistAndEmit(
      this,
      readState,
      emit,
      selection: selection,
    );
  }

  Future<void> changeBoarding(
    RailBoardStateReader readState,
    RailBoardStateEmitter emit,
    String stationId,
  ) async {
    final selection = _boardService.changeBoardingStation(
      readState().selection,
      stationId,
    );
    await RailBoardControllerLoading.persistAndEmit(
      this,
      readState,
      emit,
      selection: selection,
    );
  }

  Future<void> changeDestination(
    RailBoardStateReader readState,
    RailBoardStateEmitter emit,
    String stationId,
  ) async {
    final selection = _boardService.changeDestinationStation(
      readState().selection,
      stationId,
    );
    await RailBoardControllerLoading.persistAndEmit(
      this,
      readState,
      emit,
      selection: selection,
    );
  }

  Future<void> tick(
    RailBoardStateReader readState,
    RailBoardStateEmitter emit,
  ) async {
    final currentState = readState();
    if (currentState.status != RailBoardStatus.ready) {
      return;
    }
    emit(
      RailBoardControllerLoading.buildState(
        this,
        currentState.selection,
        currentState,
      ),
    );
    await RailBoardControllerReporting.refreshReportAvailability(
      this,
      readState,
      emit,
      selection: currentState.selection,
      now: _nowProvider(),
      attemptId: _attemptIdFactory.next(),
    );
  }

  Future<void> submitArrivalReport(
    RailBoardStateReader readState,
    RailBoardStateEmitter emit,
  ) async {
    await RailBoardControllerReporting.submitArrivalReport(
      this,
      readState,
      emit,
    );
  }
}
