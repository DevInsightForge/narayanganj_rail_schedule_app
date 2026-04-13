import '../../../community/domain/entities/delay_status.dart';
import '../bloc/rail_board_state.dart';

class RailBoardTexts {
  static const appName = 'Narayanganj Commuter';

  // Loading states
  static const loadingBoardTitle = 'Loading your commuter board';
  static const loadingBoardMessage =
      'Please wait while we load your saved route and latest timetable.';

  // Error / unavailable states
  static const boardUnavailableTitle = 'Board is currently unavailable';
  static const boardUnavailableMessage =
      'Please check your internet connection and try again.';
  static const retryAction = 'Try again';

  static const noTrainsMatchRouteTitle = 'No trains match your selected route';
  static const noTrainsMatchRouteMessage =
      'Try selecting a different direction or boarding station to see the next available departures.';

  static const noMoreDeparturesTitle = 'No more departures available';
  static const noMoreDeparturesMessage =
      'Try choosing another direction or boarding station to explore more train options.';

  static const stopByStopUnavailableTitle =
      'Stop-by-stop view is not available yet';
  static const stopByStopUnavailableMessage =
      'Please select a specific train to see its complete stop list and live estimates.';

  // Success / status labels
  static const bestNextTrainEyebrow = 'Best next train';
  static const liveRiderUpdatesEyebrow = 'Live rider updates';
  static const moreOptionsEyebrow = 'More options';
  static const routeStopsEyebrow = 'Route stops';
  static const scheduledStopsTitle = 'Scheduled stops and live estimates';

  // Core labels
  static const tripLabel = 'Trip';
  static const trainLabel = 'Train';
  static const serviceLabel = 'Service';
  static const departsLabel = 'Departs';
  static const rideLabel = 'Ride';
  static const rideTimeDetail = 'Ride time';
  static const arrivesLabel = 'Arrives';
  static const confidenceLabel = 'How sure are we';
  static const lastUpdatedLabel = 'Last updated';
  static const updatedLabel = 'Updated';
  static const delayStatusLabel = 'Delay status';

  // Community / rider updates
  static const communityUpdateShared = 'Your update has been shared';
  static const sendingUpdate = 'Sending your update...';
  static const shareArrivalUpdate = 'Share your arrival update';
  static const updatesUnavailable = 'Rider updates are currently unavailable';
  static const updateSent = 'Update sent successfully';

  static const liveRiderUpdatesLoading = 'Checking for live rider updates...';
  static const liveRiderUpdatesReady = 'Live rider updates are now available';
  static const liveRiderUpdatesStale = 'Live rider updates may be a bit older';
  static const liveRiderUpdatesEmpty = 'No rider updates have been shared yet';
  static const liveRiderUpdatesError =
      'Live rider updates are currently unavailable';
  static const liveRiderUpdatesIdle =
      'Live rider updates from fellow commuters will appear here';

  static const noMatchingTrainActive =
      'No matching train is active at the moment.';
  static const noRiderUpdatesAvailable =
      'No rider updates are available for this train yet.';

  static const liveUpdateLoadedFromSavedData =
      'Live update loaded from previously saved data.';
  static const liveUpdateRefreshed = 'Live update has been refreshed.';
  static const liveUpdatesTemporarilyUnavailable =
      'Live rider updates are temporarily unavailable. The official timetable is still available for you.';

  // Route & stops
  static const routeDirectionLabel = 'Route direction';
  static const boardFromLabel = 'Board from';
  static const goToLabel = 'Go to';
  static const boardHere = 'Board here';
  static const arriveHere = 'Arrive here';
  static const alongRoute = 'Along the route';
  static const liveEstimateLabel = 'Live estimate';
  static const plannedLabel = 'Planned';

  static const nextDepartureLabel = 'Next departure';
  static const noDepartureLabel = 'No departure';

  static String routeStopsSubtitle(int trainNo) {
    return 'Follow the complete stop sequence for train $trainNo from your boarding station to your destination.';
  }

  // Timetable / empty states
  static const timetableReadyMessage =
      'Your timetable view is ready. Please choose a direction to see the next departure and other options.';
  static const timetableChooseRouteMessage =
      'Choose your route to see the next departure and later train options.';

  static String bestNextTrainSubtitle({
    required String from,
    required String destination,
    required String etaLabel,
  }) {
    return 'Board at $from and reach $destination in approximately $etaLabel.';
  }

  static String nextDepartureNarrowMessage(String waitLabel) {
    return 'The next departure leaves in $waitLabel.';
  }

  static const noTrainAvailableMessage = 'No train is available right now';

  static String departureHeroDetail(int trainNo, String waitLabel) {
    return 'Train $trainNo — departs in $waitLabel';
  }

  static String departureHeroEtaDetail(int trainNo, String etaLabel) {
    return 'Train $trainNo — total journey time approximately $etaLabel';
  }

  // Later departures
  static const laterDeparturesTitle = 'Later departures';

  static String laterDeparturesSubtitle(int count) {
    return count == 1
        ? 'There is 1 later departure available in case you miss the next train.'
        : 'There are $count later departures available in case you miss the next train.';
  }

  // About / legal / footer
  static const aboutIntro = 'About, privacy and terms';
  static const aboutButton = 'About';
  static const aboutSheetEyebrow = 'About this app';
  static const aboutSectionTitle = 'About';

  static const versionLabel = 'Version';
  static const bundledLabel = 'Bundled data';
  static const scheduleSourceLabel = 'Schedule source';
  static const createdByLabel = 'Created by';
  static const publishedByLabel = 'Published by';

  static const privacyLabel = 'Privacy';
  static const termsLabel = 'Terms';
  static const privacyPolicyValue = 'Privacy policy';
  static const termsOfServiceValue = 'Terms of service';

  static const openAction = 'Open';
  static const learnMoreAction = 'Learn more';

  static const footerReminder =
      'Please always confirm your final travel plans with official Bangladesh Railway notices.';
  static const noticeTitle = 'Important travel reminder';
  static const noticeMessage =
      'All timetable times shown here are approximate. Please check the latest official notice from Bangladesh Railway before you travel.';

  static const footerTagline =
      'A timetable-first commuter board with helpful optional rider updates.';
  static const footerAboutParagraphOne =
      'Narayanganj Commuter is designed to help you quickly check the Dhaka–Narayanganj commuter train schedule. The official timetable remains our primary and most reliable view.';
  static const footerAboutParagraphTwo =
      'Optional rider updates from fellow commuters provide additional real-time context about possible delays, but they do not replace the official published timetable.';

  static const footerAppName = appName;

  // Dynamic helpers
  static String communityHeadline(RailCommunityInsightStatus status) {
    return switch (status) {
      RailCommunityInsightStatus.loading => liveRiderUpdatesLoading,
      RailCommunityInsightStatus.ready => liveRiderUpdatesReady,
      RailCommunityInsightStatus.stale => liveRiderUpdatesStale,
      RailCommunityInsightStatus.empty => liveRiderUpdatesEmpty,
      RailCommunityInsightStatus.error => liveRiderUpdatesError,
      RailCommunityInsightStatus.idle => liveRiderUpdatesIdle,
    };
  }

  static String communityButtonLabel({
    required bool hasReportedCurrentSession,
    required RailReportSubmissionStatus status,
    required bool submitEnabled,
  }) {
    if (hasReportedCurrentSession) {
      return communityUpdateShared;
    }

    return switch (status) {
      RailReportSubmissionStatus.submitting => sendingUpdate,
      RailReportSubmissionStatus.error =>
        submitEnabled ? shareArrivalUpdate : updatesUnavailable,
      RailReportSubmissionStatus.success => updateSent,
      RailReportSubmissionStatus.idle =>
        submitEnabled ? shareArrivalUpdate : updatesUnavailable,
    };
  }

  static String freshnessLabel(int seconds) {
    if (seconds < 60) {
      return '$seconds seconds ago';
    }
    final minutes = seconds ~/ 60;
    return minutes == 1 ? '1 minute ago' : '$minutes minutes ago';
  }

  static String delayValue(DelayStatus delayStatus, int delayMinutes) {
    return switch (delayStatus) {
      DelayStatus.early => '${delayMinutes.abs()} minutes early',
      DelayStatus.onTime => 'On time',
      DelayStatus.late => '$delayMinutes minutes late',
    };
  }
}
