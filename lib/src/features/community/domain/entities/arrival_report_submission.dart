import 'arrival_report.dart';
import 'train_session.dart';

class ArrivalReportSubmission {
  const ArrivalReportSubmission({
    required this.report,
    required this.session,
    required this.stationStop,
  });

  final ArrivalReport report;
  final TrainSession session;
  final SessionStop stationStop;
}
