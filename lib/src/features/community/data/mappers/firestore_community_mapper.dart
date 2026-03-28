import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/arrival_report.dart';
import '../../domain/entities/data_origin.dart';
import '../../domain/entities/predicted_stop_time.dart';
import '../../domain/entities/report_confidence.dart';
import '../../domain/entities/train_session.dart';
import '../models/firestore_models.dart';

class FirestoreCommunityMapper {
  const FirestoreCommunityMapper();

  TrainSession toSession(FirestoreSessionModel model) {
    final serviceDate = _parseServiceDate(model.serviceDate);
    return TrainSession(
      sessionId: model.sessionId,
      templateId: model.templateId,
      routeId: model.routeId,
      directionId: model.directionId,
      trainNo: model.trainNo,
      serviceDate: serviceDate,
      stops: model.stops
          .map(
            (stop) => SessionStop(
              stationId: stop.stationId,
              stationName: stop.stationName,
              sequence: stop.sequence,
              scheduledAt: stop.scheduledAt.toDate(),
            ),
          )
          .toList(growable: false),
    );
  }

  FirestoreArrivalReportModel toFirestoreArrivalReport({
    required ArrivalReport report,
    required String routeId,
  }) {
    return FirestoreArrivalReportModel(
      reportId: report.reportId,
      sessionId: report.sessionId,
      routeId: routeId,
      stationId: report.stationId,
      reporterUid: report.deviceId,
      observedArrivalAt: _toTimestamp(report.observedArrivalAt),
      submittedAt: _toTimestamp(report.submittedAt),
      displayName: report.displayName,
    );
  }

  ArrivalReport toArrivalReport(FirestoreArrivalReportModel model) {
    return ArrivalReport(
      reportId: model.reportId,
      sessionId: model.sessionId,
      stationId: model.stationId,
      deviceId: model.reporterUid,
      observedArrivalAt: model.observedArrivalAt.toDate(),
      submittedAt: model.submittedAt.toDate(),
      displayName: model.displayName,
    );
  }

  PredictedStopTime toPredictedStop(FirestorePredictedStopModel model) {
    final confidenceScore = model.confidence.toDouble().clamp(0.0, 1.0);
    return PredictedStopTime(
      sessionId: model.sessionId,
      stationId: model.stationId,
      predictedAt: model.predictedAt.toDate(),
      referenceStationId: model.referenceStationId,
      origin: DataOrigin.inferred,
      confidence: ReportConfidence(
        score: confidenceScore,
        sampleSize: 0,
        freshnessSeconds: model.freshnessSeconds,
        agreementScore: confidenceScore,
      ),
    );
  }

  DateTime _parseServiceDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  Timestamp _toTimestamp(DateTime value) {
    return Timestamp.fromDate(value);
  }
}
