part of 'rail_board_bloc.dart';

enum RailBoardStatus { loading, ready, failure }

enum RailReportSubmissionStatus {
  idle,
  submitting,
  success,
  rateLimited,
  error,
  offlineQueue,
}

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
      dataSourceLabel: '',
      lastUpdatedAt: null,
      scheduleVersion: '',
    ),
    this.errorMessage,
    this.reportSubmissionStatus = RailReportSubmissionStatus.idle,
    this.reportFeedbackMessage,
    this.reportRetryAfterSeconds,
  });

  final RailBoardStatus status;
  final RailSelection selection;
  final List<RailSelectableOption> directionOptions;
  final List<RailSelectableOption> boardingStations;
  final List<RailSelectableOption> destinationStations;
  final RailBoardSnapshot snapshot;
  final String? errorMessage;
  final RailReportSubmissionStatus reportSubmissionStatus;
  final String? reportFeedbackMessage;
  final int? reportRetryAfterSeconds;

  bool get isLoading => status == RailBoardStatus.loading;
  bool get hasFailed => status == RailBoardStatus.failure;

  RailBoardState copyWith({
    RailBoardStatus? status,
    RailSelection? selection,
    List<RailSelectableOption>? directionOptions,
    List<RailSelectableOption>? boardingStations,
    List<RailSelectableOption>? destinationStations,
    RailBoardSnapshot? snapshot,
    String? errorMessage,
    bool clearError = false,
    RailReportSubmissionStatus? reportSubmissionStatus,
    String? reportFeedbackMessage,
    int? reportRetryAfterSeconds,
    bool clearReportFeedback = false,
    bool clearReportRetryAfter = false,
  }) {
    return RailBoardState(
      status: status ?? this.status,
      selection: selection ?? this.selection,
      directionOptions: directionOptions ?? this.directionOptions,
      boardingStations: boardingStations ?? this.boardingStations,
      destinationStations: destinationStations ?? this.destinationStations,
      snapshot: snapshot ?? this.snapshot,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      reportSubmissionStatus:
          reportSubmissionStatus ?? this.reportSubmissionStatus,
      reportFeedbackMessage: clearReportFeedback
          ? null
          : reportFeedbackMessage ?? this.reportFeedbackMessage,
      reportRetryAfterSeconds: clearReportRetryAfter
          ? null
          : reportRetryAfterSeconds ?? this.reportRetryAfterSeconds,
    );
  }

  @override
  List<Object?> get props => [
    status,
    selection,
    directionOptions,
    boardingStations,
    destinationStations,
    snapshot,
    errorMessage,
    reportSubmissionStatus,
    reportFeedbackMessage,
    reportRetryAfterSeconds,
  ];
}
