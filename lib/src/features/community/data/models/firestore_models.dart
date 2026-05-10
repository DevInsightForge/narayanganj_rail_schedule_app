import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreStationAggregateBucketModel {
  const FirestoreStationAggregateBucketModel({
    required this.stationId,
    required this.sequence,
    required this.scheduledAt,
    required this.firstObservedAt,
    required this.lastObservedAt,
    required this.lastSubmittedAt,
    required this.submissionCount,
    required this.delayMinutes,
  });

  final String stationId;
  final int sequence;
  final Timestamp scheduledAt;
  final Timestamp firstObservedAt;
  final Timestamp lastObservedAt;
  final Timestamp lastSubmittedAt;
  final int submissionCount;
  final int delayMinutes;

  static FirestoreStationAggregateBucketModel? tryFromMap(
    Map<String, dynamic> map,
  ) {
    final stationId = map['stationId'];
    final sequence = map['sequence'];
    final scheduledAt = map['scheduledAt'];
    final firstObservedAt = map['firstObservedAt'];
    final lastObservedAt = map['lastObservedAt'];
    final lastSubmittedAt = map['lastSubmittedAt'];
    final submissionCount = map['submissionCount'];
    final delayMinutes = map['delayMinutes'];
    if (stationId is! String ||
        sequence is! num ||
        scheduledAt is! Timestamp ||
        firstObservedAt is! Timestamp ||
        lastObservedAt is! Timestamp ||
        lastSubmittedAt is! Timestamp ||
        submissionCount is! num ||
        delayMinutes is! num) {
      return null;
    }
    return FirestoreStationAggregateBucketModel(
      stationId: stationId,
      sequence: sequence.toInt(),
      scheduledAt: scheduledAt,
      firstObservedAt: firstObservedAt,
      lastObservedAt: lastObservedAt,
      lastSubmittedAt: lastSubmittedAt,
      submissionCount: submissionCount.toInt(),
      delayMinutes: delayMinutes.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'stationId': stationId,
      'sequence': sequence,
      'scheduledAt': scheduledAt,
      'firstObservedAt': firstObservedAt,
      'lastObservedAt': lastObservedAt,
      'lastSubmittedAt': lastSubmittedAt,
      'submissionCount': submissionCount,
      'delayMinutes': delayMinutes,
    };
  }
}

class FirestoreSessionAggregateModel {
  const FirestoreSessionAggregateModel({
    required this.schemaVersion,
    required this.sessionId,
    required this.routeId,
    required this.directionId,
    required this.trainNo,
    required this.serviceDate,
    required this.updatedAt,
    required this.lastReportedStationId,
    required this.delayMinutes,
    required this.delayStatus,
    required this.confidence,
    required this.reportCount,
    required this.stationCount,
    required this.stationBuckets,
  });

  final int schemaVersion;
  final String sessionId;
  final String routeId;
  final String directionId;
  final int trainNo;
  final String serviceDate;
  final Timestamp updatedAt;
  final String lastReportedStationId;
  final int delayMinutes;
  final String delayStatus;
  final Map<String, dynamic> confidence;
  final int reportCount;
  final int stationCount;
  final Map<String, FirestoreStationAggregateBucketModel> stationBuckets;

  static const currentSchemaVersion = 2;

  static FirestoreSessionAggregateModel? tryFromMap(Map<String, dynamic> map) {
    final schemaVersion = map['schemaVersion'];
    final sessionId = map['sessionId'];
    final routeId = map['routeId'];
    final directionId = map['directionId'];
    final trainNo = map['trainNo'];
    final serviceDate = map['serviceDate'];
    final updatedAt = map['updatedAt'];
    final lastReportedStationId = map['lastReportedStationId'];
    final delayMinutes = map['delayMinutes'];
    final delayStatus = map['delayStatus'];
    final confidence = map['confidence'];
    final reportCount = map['reportCount'];
    final stationCount = map['stationCount'];
    if (schemaVersion != currentSchemaVersion ||
        sessionId is! String ||
        routeId is! String ||
        directionId is! String ||
        trainNo is! num ||
        serviceDate is! String ||
        updatedAt is! Timestamp ||
        lastReportedStationId is! String ||
        delayMinutes is! num ||
        delayStatus is! String ||
        confidence is! Map ||
        reportCount is! num ||
        stationCount is! num) {
      return null;
    }
    final stationBuckets = _readBuckets(map['stationBuckets']);
    if (stationBuckets == null) {
      return null;
    }
    if (stationBuckets.length != stationCount.toInt()) {
      return null;
    }
    final bucketReportCount = stationBuckets.values.fold<int>(
      0,
      (total, bucket) => total + bucket.submissionCount,
    );
    if (bucketReportCount != reportCount.toInt()) {
      return null;
    }
    return FirestoreSessionAggregateModel(
      schemaVersion: schemaVersion,
      sessionId: sessionId,
      routeId: routeId,
      directionId: directionId,
      trainNo: trainNo.toInt(),
      serviceDate: serviceDate,
      updatedAt: updatedAt,
      lastReportedStationId: lastReportedStationId,
      delayMinutes: delayMinutes.toInt(),
      delayStatus: delayStatus,
      confidence: Map<String, dynamic>.from(confidence),
      reportCount: reportCount.toInt(),
      stationCount: stationCount.toInt(),
      stationBuckets: stationBuckets,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schemaVersion': schemaVersion,
      'sessionId': sessionId,
      'routeId': routeId,
      'directionId': directionId,
      'trainNo': trainNo,
      'serviceDate': serviceDate,
      'updatedAt': updatedAt,
      'lastReportedStationId': lastReportedStationId,
      'delayMinutes': delayMinutes,
      'delayStatus': delayStatus,
      'confidence': confidence,
      'reportCount': reportCount,
      'stationCount': stationCount,
      'stationBuckets': stationBuckets.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
    };
  }

  static Map<String, FirestoreStationAggregateBucketModel>? _readBuckets(
    Object? value,
  ) {
    if (value is! Map) {
      return null;
    }
    final entries = <String, FirestoreStationAggregateBucketModel>{};
    var invalid = false;
    value.forEach((key, dynamic bucketValue) {
      if (key is! String || bucketValue is! Map) {
        invalid = true;
        return;
      }
      final parsed = FirestoreStationAggregateBucketModel.tryFromMap(
        Map<String, dynamic>.from(bucketValue),
      );
      if (parsed == null || parsed.stationId != key) {
        invalid = true;
        return;
      }
      entries[key] = parsed;
    });
    if (invalid) {
      return null;
    }
    return entries;
  }
}
