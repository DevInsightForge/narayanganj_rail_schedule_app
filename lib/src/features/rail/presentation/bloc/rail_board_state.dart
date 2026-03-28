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

enum RailCommunityInsightStatus { idle, loading, ready, stale, empty, error }

class RailBoardViewState extends Equatable {
  const RailBoardViewState({
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
  });

  final RailSelection selection;
  final List<RailSelectableOption> directionOptions;
  final List<RailSelectableOption> boardingStations;
  final List<RailSelectableOption> destinationStations;
  final RailBoardSnapshot snapshot;

  RailBoardViewState copyWith({
    RailSelection? selection,
    List<RailSelectableOption>? directionOptions,
    List<RailSelectableOption>? boardingStations,
    List<RailSelectableOption>? destinationStations,
    RailBoardSnapshot? snapshot,
  }) {
    return RailBoardViewState(
      selection: selection ?? this.selection,
      directionOptions: directionOptions ?? this.directionOptions,
      boardingStations: boardingStations ?? this.boardingStations,
      destinationStations: destinationStations ?? this.destinationStations,
      snapshot: snapshot ?? this.snapshot,
    );
  }

  @override
  List<Object?> get props => [
    selection,
    directionOptions,
    boardingStations,
    destinationStations,
    snapshot,
  ];
}

class RailBoardReportState extends Equatable {
  const RailBoardReportState({
    this.status = RailReportSubmissionStatus.idle,
    this.feedbackMessage,
    this.retryAfterSeconds,
  });

  final RailReportSubmissionStatus status;
  final String? feedbackMessage;
  final int? retryAfterSeconds;

  RailBoardReportState copyWith({
    RailReportSubmissionStatus? status,
    String? feedbackMessage,
    int? retryAfterSeconds,
    bool clearFeedback = false,
    bool clearRetryAfter = false,
  }) {
    return RailBoardReportState(
      status: status ?? this.status,
      feedbackMessage: clearFeedback
          ? null
          : feedbackMessage ?? this.feedbackMessage,
      retryAfterSeconds: clearRetryAfter
          ? null
          : retryAfterSeconds ?? this.retryAfterSeconds,
    );
  }

  @override
  List<Object?> get props => [status, feedbackMessage, retryAfterSeconds];
}

class RailBoardCommunityState extends Equatable {
  const RailBoardCommunityState({
    this.featuresEnabled = true,
    this.insightStatus = RailCommunityInsightStatus.idle,
    this.sessionStatusSnapshot,
    this.predictedStopTimes = const [],
    this.message,
  });

  final bool featuresEnabled;
  final RailCommunityInsightStatus insightStatus;
  final SessionStatusSnapshot? sessionStatusSnapshot;
  final List<PredictedStopTime> predictedStopTimes;
  final String? message;

  RailBoardCommunityState copyWith({
    bool? featuresEnabled,
    RailCommunityInsightStatus? insightStatus,
    SessionStatusSnapshot? sessionStatusSnapshot,
    List<PredictedStopTime>? predictedStopTimes,
    String? message,
    bool clearSessionStatus = false,
    bool clearMessage = false,
  }) {
    return RailBoardCommunityState(
      featuresEnabled: featuresEnabled ?? this.featuresEnabled,
      insightStatus: insightStatus ?? this.insightStatus,
      sessionStatusSnapshot: clearSessionStatus
          ? null
          : sessionStatusSnapshot ?? this.sessionStatusSnapshot,
      predictedStopTimes: predictedStopTimes ?? this.predictedStopTimes,
      message: clearMessage ? null : message ?? this.message,
    );
  }

  @override
  List<Object?> get props => [
    featuresEnabled,
    insightStatus,
    sessionStatusSnapshot,
    predictedStopTimes,
    message,
  ];
}

class RailBoardState extends Equatable {
  const RailBoardState({
    this.status = RailBoardStatus.loading,
    this.errorMessage,
    this.view = const RailBoardViewState(),
    this.report = const RailBoardReportState(),
    this.community = const RailBoardCommunityState(),
  });

  final RailBoardStatus status;
  final String? errorMessage;
  final RailBoardViewState view;
  final RailBoardReportState report;
  final RailBoardCommunityState community;

  bool get isLoading => status == RailBoardStatus.loading;
  bool get hasFailed => status == RailBoardStatus.failure;
  RailSelection get selection => view.selection;
  List<RailSelectableOption> get directionOptions => view.directionOptions;
  List<RailSelectableOption> get boardingStations => view.boardingStations;
  List<RailSelectableOption> get destinationStations =>
      view.destinationStations;
  RailBoardSnapshot get snapshot => view.snapshot;
  RailReportSubmissionStatus get reportSubmissionStatus => report.status;
  String? get reportFeedbackMessage => report.feedbackMessage;
  int? get reportRetryAfterSeconds => report.retryAfterSeconds;
  RailCommunityInsightStatus get communityInsightStatus =>
      community.insightStatus;
  SessionStatusSnapshot? get sessionStatusSnapshot =>
      community.sessionStatusSnapshot;
  List<PredictedStopTime> get predictedStopTimes =>
      community.predictedStopTimes;
  String? get communityMessage => community.message;
  bool get communityFeaturesEnabled => community.featuresEnabled;

  RailBoardState copyWith({
    RailBoardStatus? status,
    String? errorMessage,
    bool clearError = false,
    RailBoardViewState? view,
    RailBoardReportState? report,
    RailBoardCommunityState? community,
  }) {
    return RailBoardState(
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      view: view ?? this.view,
      report: report ?? this.report,
      community: community ?? this.community,
    );
  }

  @override
  List<Object?> get props => [status, errorMessage, view, report, community];
}
