import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/logging/debug_logger.dart';
import '../../../domain/entities/arrival_report.dart';
import '../../../domain/entities/arrival_report_submission.dart';
import '../../../domain/entities/community_session_aggregate.dart';
import '../../../domain/repositories/arrival_report_repository.dart';
import '../../../domain/services/community_session_aggregate_reducer.dart';
import '../../mappers/firestore_community_mapper.dart';
import '../../models/firestore_models.dart';
import '../../../domain/services/service_day_key.dart';
import 'firestore_collection_names.dart';

class FirebaseArrivalReportRepository implements ArrivalReportRepository {
  FirebaseArrivalReportRepository({
    required FirebaseFirestore firestore,
    required String routeId,
    String collectionName = FirestoreCollectionNames.sessionStatusSnapshots,
    FirestoreCommunityMapper mapper = const FirestoreCommunityMapper(),
    CommunitySessionAggregateReducer reducer =
        const CommunitySessionAggregateReducer(),
    DebugLogger? logger,
  }) : _firestore = firestore,
       _routeId = routeId,
       _collectionName = collectionName,
       _mapper = mapper,
       _reducer = reducer,
       _logger = logger ?? const DebugLogger('FirebaseArrivalReportRepository');

  final FirebaseFirestore _firestore;
  final String _routeId;
  final String _collectionName;
  final FirestoreCommunityMapper _mapper;
  final CommunitySessionAggregateReducer _reducer;
  final DebugLogger _logger;

  @override
  Future<List<ArrivalReport>> fetchStopReports({
    required String sessionId,
    required DateTime serviceDate,
    required String stationId,
  }) async {
    final aggregate = await _readAggregate(sessionId);
    if (aggregate == null ||
        !isSameServiceDay(aggregate.serviceDate, serviceDate)) {
      return const <ArrivalReport>[];
    }
    final bucket = aggregate.bucketForStation(stationId);
    if (bucket == null) {
      return const <ArrivalReport>[];
    }

    return [
      ArrivalReport(
        reportId: bucket.latestReportId,
        sessionId: aggregate.sessionId,
        stationId: bucket.stationId,
        deviceId: bucket.latestDeviceId,
        observedArrivalAt: bucket.lastObservedAt,
        submittedAt: bucket.lastSubmittedAt,
      ),
    ];
  }

  @override
  Future<int> fetchStationSubmissionCount({
    required String sessionId,
    required DateTime serviceDate,
    required String stationId,
  }) async {
    final aggregate = await _readAggregate(sessionId);
    if (aggregate == null ||
        !isSameServiceDay(aggregate.serviceDate, serviceDate)) {
      return 0;
    }
    return aggregate.bucketForStation(stationId)?.submissionCount ?? 0;
  }

  @override
  Future<CommunitySessionAggregate> submitArrivalReport(
    ArrivalReportSubmission submission,
  ) async {
    if (submission.session.routeId != _routeId) {
      throw const ArrivalReportRepositoryException(
        ArrivalReportRepositoryErrorCode.unknown,
      );
    }

    CommunitySessionAggregate? nextAggregate;
    try {
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore
            .collection(_collectionName)
            .doc(submission.session.sessionId);
        final snapshot = await transaction.get(docRef);
        final current = snapshot.exists && snapshot.data() != null
            ? _readAggregateFromData(snapshot.data()!)
            : null;
        final next = _reducer.reduce(
          current: current,
          submission: submission,
          now: submission.report.submittedAt,
        );
        nextAggregate = next;
        final firestoreModel = _mapper.toFirestoreSessionAggregate(next);
        transaction.set(
          docRef,
          firestoreModel.toMap(),
          SetOptions(merge: false),
        );
      });
      final aggregate = nextAggregate;
      if (aggregate == null) {
        throw StateError('aggregate_transaction_missing_result');
      }
      _logger.log(
        'submit_session_aggregate_success',
        context: <String, Object?>{
          'feature': 'arrival_report',
          'sessionId': submission.session.sessionId,
          'stationId': submission.stationStop.stationId,
          'uid': submission.report.deviceId,
          'collectionName': _collectionName,
          'reportCount': aggregate.reportCount,
          'stationCount': aggregate.stationCount,
        },
      );
      return aggregate;
    } on FirebaseException catch (error) {
      _logger.log(
        'submit_arrival_report_fail',
        context: <String, Object?>{
          'feature': 'arrival_report',
          'sessionId': submission.session.sessionId,
          'stationId': submission.stationStop.stationId,
          'uid': submission.report.deviceId,
          'collectionName': _collectionName,
          'errorCode': error.code,
          'error': error,
        },
      );
      if (error.code == 'permission-denied') {
        throw const ArrivalReportRepositoryException(
          ArrivalReportRepositoryErrorCode.permissionDenied,
        );
      }
      throw const ArrivalReportRepositoryException(
        ArrivalReportRepositoryErrorCode.unknown,
      );
    } catch (error) {
      if (error is StateError &&
          error.message == 'station_submission_capacity_reached') {
        throw const ArrivalReportRepositoryException(
          ArrivalReportRepositoryErrorCode.stationCapacityReached,
        );
      }
      _logger.log(
        'submit_arrival_report_fail',
        context: <String, Object?>{
          'feature': 'arrival_report',
          'sessionId': submission.session.sessionId,
          'stationId': submission.stationStop.stationId,
          'uid': submission.report.deviceId,
          'collectionName': _collectionName,
          'errorCode': _isPermissionDenied(error)
              ? 'permission-denied'
              : 'unknown',
          'error': error,
        },
      );
      if (_isPermissionDenied(error)) {
        throw const ArrivalReportRepositoryException(
          ArrivalReportRepositoryErrorCode.permissionDenied,
        );
      }
      throw const ArrivalReportRepositoryException(
        ArrivalReportRepositoryErrorCode.unknown,
      );
    }
  }

  Future<CommunitySessionAggregate?> _readAggregate(String sessionId) async {
    final document = await _firestore
        .collection(_collectionName)
        .doc(sessionId)
        .get();
    final data = document.data();
    if (data == null || data.isEmpty) {
      return null;
    }
    return _readAggregateFromData(data);
  }

  CommunitySessionAggregate? _readAggregateFromData(Map<String, dynamic> data) {
    try {
      final model = FirestoreSessionAggregateModel.tryFromMap(data);
      if (model == null) {
        return null;
      }
      return _mapper.toCommunitySessionAggregate(model);
    } catch (_) {
      return null;
    }
  }

  bool _isPermissionDenied(Object error) {
    final value = error.toString().toLowerCase();
    return value.contains('permission-denied') ||
        value.contains('permission denied') ||
        value.contains('insufficient permissions');
  }
}
