import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreSessionModel {
  const FirestoreSessionModel({
    required this.sessionId,
    required this.templateId,
    required this.routeId,
    required this.directionId,
    required this.trainNo,
    required this.serviceDate,
    required this.stops,
  });

  final String sessionId;
  final String templateId;
  final String routeId;
  final String directionId;
  final int trainNo;
  final String serviceDate;
  final List<FirestoreSessionStopModel> stops;

  factory FirestoreSessionModel.fromMap(Map<String, dynamic> map) {
    return FirestoreSessionModel(
      sessionId: map['sessionId'] as String? ?? '',
      templateId: map['templateId'] as String? ?? '',
      routeId: map['routeId'] as String? ?? '',
      directionId: map['directionId'] as String? ?? '',
      trainNo: (map['trainNo'] as num?)?.toInt() ?? 0,
      serviceDate: map['serviceDate'] as String? ?? '',
      stops: (map['stops'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(FirestoreSessionStopModel.fromMap)
          .toList(growable: false),
    );
  }
}

class FirestoreSessionStopModel {
  const FirestoreSessionStopModel({
    required this.stationId,
    required this.stationName,
    required this.sequence,
    required this.scheduledAt,
  });

  final String stationId;
  final String stationName;
  final int sequence;
  final Timestamp scheduledAt;

  factory FirestoreSessionStopModel.fromMap(Map<String, dynamic> map) {
    return FirestoreSessionStopModel(
      stationId: map['stationId'] as String? ?? '',
      stationName: map['stationName'] as String? ?? '',
      sequence: (map['sequence'] as num?)?.toInt() ?? 0,
      scheduledAt: map['scheduledAt'] as Timestamp? ?? Timestamp.now(),
    );
  }
}

class FirestoreArrivalReportModel {
  const FirestoreArrivalReportModel({
    required this.reportId,
    required this.sessionId,
    required this.routeId,
    required this.stationId,
    required this.reporterUid,
    required this.observedArrivalAt,
    required this.submittedAt,
    this.displayName,
  });

  final String reportId;
  final String sessionId;
  final String routeId;
  final String stationId;
  final String reporterUid;
  final Timestamp observedArrivalAt;
  final Timestamp submittedAt;
  final String? displayName;

  Map<String, dynamic> toMap() {
    return {
      'reportId': reportId,
      'sessionId': sessionId,
      'routeId': routeId,
      'stationId': stationId,
      'reporterUid': reporterUid,
      'observedArrivalAt': observedArrivalAt,
      'submittedAt': submittedAt,
      'displayName': displayName,
    };
  }

  factory FirestoreArrivalReportModel.fromMap(Map<String, dynamic> map) {
    return FirestoreArrivalReportModel(
      reportId: map['reportId'] as String? ?? '',
      sessionId: map['sessionId'] as String? ?? '',
      routeId: map['routeId'] as String? ?? '',
      stationId: map['stationId'] as String? ?? '',
      reporterUid: map['reporterUid'] as String? ?? '',
      observedArrivalAt:
          map['observedArrivalAt'] as Timestamp? ?? Timestamp.now(),
      submittedAt: map['submittedAt'] as Timestamp? ?? Timestamp.now(),
      displayName: map['displayName'] as String?,
    );
  }
}

class FirestorePredictedStopModel {
  const FirestorePredictedStopModel({
    required this.sessionId,
    required this.stationId,
    required this.predictedAt,
    required this.referenceStationId,
    required this.confidence,
    required this.freshnessSeconds,
  });

  final String sessionId;
  final String stationId;
  final Timestamp predictedAt;
  final String referenceStationId;
  final num confidence;
  final int freshnessSeconds;

  factory FirestorePredictedStopModel.fromMap(Map<String, dynamic> map) {
    return FirestorePredictedStopModel(
      sessionId: map['sessionId'] as String? ?? '',
      stationId: map['stationId'] as String? ?? '',
      predictedAt: map['predictedAt'] as Timestamp? ?? Timestamp.now(),
      referenceStationId: map['referenceStationId'] as String? ?? '',
      confidence: map['confidence'] as num? ?? 0,
      freshnessSeconds: (map['freshnessSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}
