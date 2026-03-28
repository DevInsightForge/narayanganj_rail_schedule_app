import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/entities/predicted_stop_time.dart';
import '../../../domain/repositories/prediction_repository.dart';
import '../../mappers/firestore_community_mapper.dart';
import '../../models/firestore_models.dart';

class FirebasePredictionRepository implements PredictionRepository {
  FirebasePredictionRepository({
    required FirebaseFirestore firestore,
    FirestoreCommunityMapper mapper = const FirestoreCommunityMapper(),
  }) : _firestore = firestore,
       _mapper = mapper;

  final FirebaseFirestore _firestore;
  final FirestoreCommunityMapper _mapper;

  @override
  Future<List<PredictedStopTime>> fetchPredictions({
    required String sessionId,
  }) async {
    final query = await _firestore
        .collection('session_status_snapshots')
        .doc(sessionId)
        .collection('predicted_stops')
        .orderBy('predictedAt')
        .get();

    return query.docs
        .map((doc) => FirestorePredictedStopModel.fromMap(doc.data()))
        .map(_mapper.toPredictedStop)
        .toList(growable: false);
  }
}
