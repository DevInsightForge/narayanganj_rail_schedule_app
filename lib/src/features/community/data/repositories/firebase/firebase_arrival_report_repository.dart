import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../../core/logging/debug_logger.dart';
import '../../../domain/entities/arrival_report.dart';
import '../../../domain/entities/arrival_report_submission.dart';
import '../../../domain/entities/community_session_aggregate.dart';
import '../../../domain/repositories/arrival_report_repository.dart';
import '../../../domain/services/community_session_aggregate_reducer.dart';
import '../../mappers/firestore_community_mapper.dart';
import '../../models/firestore_models.dart';

class FirebaseArrivalReportRepository implements ArrivalReportRepository {
  FirebaseArrivalReportRepository({
    required FirebaseFirestore firestore,
    required String routeId,
    FirestoreCommunityMapper mapper = const FirestoreCommunityMapper(),
    CommunitySessionAggregateReducer reducer =
        const CommunitySessionAggregateReducer(),
    DebugLogger? logger,
  }) : _firestore = firestore,
       _routeId = routeId,
       _mapper = mapper,
       _reducer = reducer,
       _logger = logger ?? const DebugLogger('FirebaseArrivalReportRepository');

  final FirebaseFirestore _firestore;
  final String _routeId;
  final FirestoreCommunityMapper _mapper;
  final CommunitySessionAggregateReducer _reducer;
  final DebugLogger _logger;

  @override
  Future<List<ArrivalReport>> fetchStopReports({
    required String sessionId,
    required String stationId,
  }) async {
    final aggregate = await _readAggregate(sessionId);
    if (aggregate == null) {
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
    required String stationId,
  }) async {
    final aggregate = await _readAggregate(sessionId);
    return aggregate?.bucketForStation(stationId)?.submissionCount ?? 0;
  }

  @override
  Future<void> submitArrivalReport(ArrivalReportSubmission submission) async {
    if (submission.session.routeId != _routeId) {
      throw const ArrivalReportRepositoryException(
        ArrivalReportRepositoryErrorCode.unknown,
      );
    }

    try {
      final model = await _firestore.runTransaction((transaction) async {
        final docRef = _firestore
            .collection('session_status_snapshots')
            .doc(submission.session.sessionId);
        final snapshot = await transaction.get(docRef);
        final current = snapshot.exists && snapshot.data() != null
            ? _mapper.toCommunitySessionAggregate(
                FirestoreSessionAggregateModel.fromMap(snapshot.data()!),
              )
            : null;
        final next = _reducer.reduce(
          current: current,
          submission: submission,
          now: submission.report.submittedAt,
        );
        final firestoreModel = _mapper.toFirestoreSessionAggregate(next);
        transaction.set(
          docRef,
          firestoreModel.toMap(),
          SetOptions(merge: false),
        );
        return firestoreModel;
      });
      _logger.log(
        'submit_session_aggregate_success',
        context: <String, Object?>{
          'feature': 'arrival_report',
          'sessionId': submission.session.sessionId,
          'stationId': submission.stationStop.stationId,
          'uid': submission.report.deviceId,
          'reportCount': model.reportCount,
          'stationCount': model.stationCount,
        },
      );
    } on FirebaseException catch (error) {
      _logger.log(
        'submit_arrival_report_fail',
        context: <String, Object?>{
          'feature': 'arrival_report',
          'sessionId': submission.session.sessionId,
          'stationId': submission.stationStop.stationId,
          'uid': submission.report.deviceId,
          'errorCode': error.code,
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
          'errorCode': 'unknown',
        },
      );
      throw const ArrivalReportRepositoryException(
        ArrivalReportRepositoryErrorCode.unknown,
      );
    }
  }

  Future<CommunitySessionAggregate?> _readAggregate(String sessionId) async {
    final document = await _firestore
        .collection('session_status_snapshots')
        .doc(sessionId)
        .get();
    final data = document.data();
    if (data == null || data.isEmpty) {
      return null;
    }
    return _mapper.toCommunitySessionAggregate(
      FirestoreSessionAggregateModel.fromMap(data),
    );
  }
}
