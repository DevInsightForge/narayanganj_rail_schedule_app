import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../domain/entities/train_session.dart';
import '../../../domain/repositories/session_repository.dart';
import '../../mappers/firestore_community_mapper.dart';
import '../../models/firestore_models.dart';

class FirebaseSessionRepository implements SessionRepository {
  FirebaseSessionRepository({
    required FirebaseFirestore firestore,
    FirestoreCommunityMapper mapper = const FirestoreCommunityMapper(),
  }) : _firestore = firestore,
       _mapper = mapper;

  final FirebaseFirestore _firestore;
  final FirestoreCommunityMapper _mapper;

  @override
  Future<List<TrainSession>> fetchSessions({
    required String routeId,
    required DateTime serviceDate,
  }) async {
    final serviceDateKey = _serviceDateKey(serviceDate);
    final query = await _firestore
        .collection('train_sessions')
        .where('routeId', isEqualTo: routeId)
        .where('serviceDate', isEqualTo: serviceDateKey)
        .get();

    return query.docs
        .map((doc) => FirestoreSessionModel.fromMap(doc.data()))
        .map(_mapper.toSession)
        .toList(growable: false);
  }

  @override
  Future<TrainSession?> fetchNextEligibleSession({
    required String routeId,
    required String fromStationId,
    required String toStationId,
    required DateTime now,
  }) async {
    final todaySessions = await fetchSessions(
      routeId: routeId,
      serviceDate: now,
    );
    final tomorrowSessions = await fetchSessions(
      routeId: routeId,
      serviceDate: now.add(const Duration(days: 1)),
    );
    final sessions = [...todaySessions, ...tomorrowSessions]
      ..sort((a, b) => a.departureAt.compareTo(b.departureAt));

    for (final session in sessions) {
      final fromIndex = session.stops.indexWhere(
        (stop) => stop.stationId == fromStationId,
      );
      final toIndex = session.stops.indexWhere(
        (stop) => stop.stationId == toStationId,
      );
      if (fromIndex >= 0 &&
          toIndex >= 0 &&
          fromIndex < toIndex &&
          (session.departureAt.isAfter(now) ||
              session.arrivalAt.isAfter(now))) {
        return session;
      }
    }
    return null;
  }

  String _serviceDateKey(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
