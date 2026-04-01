import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreStationAggregateBucketModel {
  const FirestoreStationAggregateBucketModel({
    required this.stationId,
    required this.stationName,
    required this.sequence,
    required this.scheduledAt,
    required this.firstObservedAt,
    required this.lastObservedAt,
    required this.firstSubmittedAt,
    required this.lastSubmittedAt,
    required this.latestReportId,
    required this.latestDeviceId,
    required this.submissionCount,
    required this.delayMinutes,
  });

  final String stationId;
  final String stationName;
  final int sequence;
  final Timestamp scheduledAt;
  final Timestamp firstObservedAt;
  final Timestamp lastObservedAt;
  final Timestamp firstSubmittedAt;
  final Timestamp lastSubmittedAt;
  final String latestReportId;
  final String latestDeviceId;
  final int submissionCount;
  final int delayMinutes;

  factory FirestoreStationAggregateBucketModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return FirestoreStationAggregateBucketModel(
      stationId: map['stationId'] as String? ?? '',
      stationName: map['stationName'] as String? ?? '',
      sequence: (map['sequence'] as num?)?.toInt() ?? 0,
      scheduledAt: map['scheduledAt'] as Timestamp? ?? Timestamp.now(),
      firstObservedAt: map['firstObservedAt'] as Timestamp? ?? Timestamp.now(),
      lastObservedAt: map['lastObservedAt'] as Timestamp? ?? Timestamp.now(),
      firstSubmittedAt:
          map['firstSubmittedAt'] as Timestamp? ?? Timestamp.now(),
      lastSubmittedAt: map['lastSubmittedAt'] as Timestamp? ?? Timestamp.now(),
      latestReportId: map['latestReportId'] as String? ?? '',
      latestDeviceId: map['latestDeviceId'] as String? ?? '',
      submissionCount: (map['submissionCount'] as num?)?.toInt() ?? 0,
      delayMinutes: (map['delayMinutes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'stationId': stationId,
      'stationName': stationName,
      'sequence': sequence,
      'scheduledAt': scheduledAt,
      'firstObservedAt': firstObservedAt,
      'lastObservedAt': lastObservedAt,
      'firstSubmittedAt': firstSubmittedAt,
      'lastSubmittedAt': lastSubmittedAt,
      'latestReportId': latestReportId,
      'latestDeviceId': latestDeviceId,
      'submissionCount': submissionCount,
      'delayMinutes': delayMinutes,
    };
  }
}

class FirestoreSessionAggregateModel {
  const FirestoreSessionAggregateModel({
    required this.sessionId,
    required this.routeId,
    required this.directionId,
    required this.trainNo,
    required this.serviceDate,
    required this.updatedAt,
    required this.lastObservedAt,
    required this.delayMinutes,
    required this.delayStatus,
    required this.confidence,
    required this.freshnessSeconds,
    required this.reportCount,
    required this.stationCount,
    required this.stationBuckets,
  });

  final String sessionId;
  final String routeId;
  final String directionId;
  final int trainNo;
  final String serviceDate;
  final Timestamp updatedAt;
  final Timestamp? lastObservedAt;
  final int delayMinutes;
  final String delayStatus;
  final Map<String, dynamic> confidence;
  final int freshnessSeconds;
  final int reportCount;
  final int stationCount;
  final Map<String, FirestoreStationAggregateBucketModel> stationBuckets;

  factory FirestoreSessionAggregateModel.fromMap(Map<String, dynamic> map) {
    return FirestoreSessionAggregateModel(
      sessionId: map['sessionId'] as String? ?? '',
      routeId: map['routeId'] as String? ?? '',
      directionId: map['directionId'] as String? ?? '',
      trainNo: (map['trainNo'] as num?)?.toInt() ?? 0,
      serviceDate: map['serviceDate'] as String? ?? '',
      updatedAt: map['updatedAt'] as Timestamp? ?? Timestamp.now(),
      lastObservedAt: map['lastObservedAt'] as Timestamp?,
      delayMinutes: (map['delayMinutes'] as num?)?.toInt() ?? 0,
      delayStatus: map['delayStatus'] as String? ?? 'onTime',
      confidence: Map<String, dynamic>.from(
        map['confidence'] as Map? ?? const <String, dynamic>{},
      ),
      freshnessSeconds: (map['freshnessSeconds'] as num?)?.toInt() ?? 0,
      reportCount: (map['reportCount'] as num?)?.toInt() ?? 0,
      stationCount: (map['stationCount'] as num?)?.toInt() ?? 0,
      stationBuckets: _readBuckets(map['stationBuckets']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'routeId': routeId,
      'directionId': directionId,
      'trainNo': trainNo,
      'serviceDate': serviceDate,
      'updatedAt': updatedAt,
      'lastObservedAt': lastObservedAt,
      'delayMinutes': delayMinutes,
      'delayStatus': delayStatus,
      'confidence': confidence,
      'freshnessSeconds': freshnessSeconds,
      'reportCount': reportCount,
      'stationCount': stationCount,
      'stationBuckets': stationBuckets.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
    };
  }

  static Map<String, FirestoreStationAggregateBucketModel> _readBuckets(
    Object? value,
  ) {
    if (value is! Map) {
      return const <String, FirestoreStationAggregateBucketModel>{};
    }
    final entries = <String, FirestoreStationAggregateBucketModel>{};
    value.forEach((key, dynamic bucketValue) {
      if (key is! String || bucketValue is! Map) {
        return;
      }
      entries[key] = FirestoreStationAggregateBucketModel.fromMap(
        Map<String, dynamic>.from(bucketValue),
      );
    });
    return entries;
  }
}

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
