import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/entities/arrival_report.dart';
import '../../../domain/repositories/arrival_report_repository.dart';
import '../../mappers/firestore_community_mapper.dart';
import '../../models/firestore_models.dart';

class FirebaseArrivalReportRepository implements ArrivalReportRepository {
  FirebaseArrivalReportRepository({
    required FirebaseFirestore firestore,
    required String routeId,
    this.fetchLimit = 10,
    FirestoreCommunityMapper mapper = const FirestoreCommunityMapper(),
  }) : _firestore = firestore,
       _routeId = routeId,
       _mapper = mapper;

  final FirebaseFirestore _firestore;
  final String _routeId;
  final int fetchLimit;
  final FirestoreCommunityMapper _mapper;

  @override
  Future<List<ArrivalReport>> fetchStopReports({
    required String sessionId,
    required String stationId,
  }) async {
    final query = await _firestore
        .collection('station_reports')
        .where('sessionId', isEqualTo: sessionId)
        .where('stationId', isEqualTo: stationId)
        .orderBy('submittedAt', descending: true)
        .limit(fetchLimit)
        .get();

    return query.docs
        .map((doc) => FirestoreArrivalReportModel.fromMap(doc.data()))
        .map(_mapper.toArrivalReport)
        .toList(growable: false);
  }

  @override
  Future<void> submitArrivalReport(ArrivalReport report) async {
    final model = _mapper.toFirestoreArrivalReport(
      report: report,
      routeId: _routeId,
    );
    await _firestore
        .collection('station_reports')
        .doc(report.reportId)
        .set(model.toMap(), SetOptions(merge: false));
  }
}
